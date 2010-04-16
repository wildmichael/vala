# - Internal utility macros and functions used to build Vala
#

# build the vala library
function(_vala_build_libvala)
  if(VALA_DO_PRECOMPILE)
    # gee
    include("${CMAKE_SOURCE_DIR}/gee/files.cmake")
    vala_precompile(gee${VALA_BOOTSTRAP_SUFFIX}_precompile VALAGEE_C_SOURCES
      ${VALAGEE_VALA_SOURCES}
      LIBRARY gee
      PACKAGES gobject-2.0
      GENERATE_VAPI gee.vapi
      GENERATE_HEADER "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/include/valagee.h"
      BASE_DIR "${CMAKE_SOURCE_DIR}/gee"
      OUTPUT_DIR "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/gee"
      )

    # ccode
    include("${CMAKE_SOURCE_DIR}/ccode/files.cmake")
    vala_precompile(ccode${VALA_BOOTSTRAP_SUFFIX}_precompile VALACCODE_C_SOURCES
      ${VALACCODE_VALA_SOURCES}
      LIBRARY ccode
      PACKAGES gee${VALA_BOOTSTRAP_SUFFIX}_precompile
      CUSTOM_VAPIS "${CMAKE_SOURCE_DIR}/vapi/config.vapi"
      GENERATE_VAPI ccode.vapi
      GENERATE_HEADER "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/include/valaccode.h"
      BASE_DIR "${CMAKE_SOURCE_DIR}/ccode"
      OUTPUT_DIR "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/ccode"
      )

    # valacore
    include("${CMAKE_SOURCE_DIR}/vala/files.cmake")
    vala_precompile(vala${VALA_BOOTSTRAP_SUFFIX}_precompile VALACORE_C_SOURCES
      ${VALACORE_VALA_SOURCES}
      LIBRARY vala
      PACKAGES ccode${VALA_BOOTSTRAP_SUFFIX}_precompile
      GENERATE_VAPI vala.vapi
      GENERATE_HEADER "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/include/vala.h"
      BASE_DIR "${CMAKE_SOURCE_DIR}/vala"
      OUTPUT_DIR "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/vala"
      )

    # codegen
    include("${CMAKE_SOURCE_DIR}/codegen/files.cmake")
    vala_precompile(codegen${VALA_BOOTSTRAP_SUFFIX}_precompile VALACODEGEN_C_SOURCES
      ${VALACODEGEN_VALA_SOURCES}
      LIBRARY codegen
      PACKAGES vala${VALA_BOOTSTRAP_SUFFIX}_precompile
      GENERATE_VAPI codegen.vapi
      GENERATE_HEADER
      "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/include/valacodegen.h"
      BASE_DIR "${CMAKE_SOURCE_DIR}/codegen"
      OUTPUT_DIR "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/codegen"
      )
  else()
    include("${CMAKE_SOURCE_DIR}/gee/generated/files.cmake")
    include("${CMAKE_SOURCE_DIR}/ccode/generated/files.cmake")
    include("${CMAKE_SOURCE_DIR}/vala/generated/files.cmake")
    include("${CMAKE_SOURCE_DIR}/codegen/generated/files.cmake")
  endif()

  # finally, compile and link libvala
  add_library(vala${VALA_BOOTSTRAP_SUFFIX} SHARED
    ${VALAGEE_C_SOURCES}
    ${VALACCODE_C_SOURCES}
    ${VALACORE_C_SOURCES}
    ${VALACODEGEN_C_SOURCES}
    )

  target_link_libraries(vala${VALA_BOOTSTRAP_SUFFIX} ${GLIB2_LIBRARIES})

  if(VALA_DO_PRECOMPILE)
    # ensure that things are built in the correct order
    vala_add_dependencies(vala${VALA_BOOTSTRAP_SUFFIX}
      codegen${VALA_BOOTSTRAP_SUFFIX}_precompile
      )
  else()
    set(vapi_deps
      "${CMAKE_SOURCE_DIR}/vapi/generated/gee.vapi"
      "${CMAKE_SOURCE_DIR}/vapi/generated/ccode.vapi"
      "${CMAKE_SOURCE_DIR}/vapi/generated/vala.vapi"
      "${CMAKE_SOURCE_DIR}/vapi/generated/codegen.vapi"
      "${CMAKE_SOURCE_DIR}/vapi/config.vapi"
      )
    set_target_properties(vala${VALA_BOOTSTRAP_SUFFIX} PROPERTIES
      VAPI_FILES "${vapi_deps}"
      VALA_PACKAGE_DEPENDENCIES ""
      )
  endif()
endfunction()

# build the compiler
function(_vala_build_compiler)
  if(VALA_DO_PRECOMPILE)
    vala_add_executable(valac${VALA_BOOTSTRAP_SUFFIX}
      "${CMAKE_SOURCE_DIR}/compiler/valacompiler.vala"
      PACKAGES vala${VALA_BOOTSTRAP_SUFFIX}
      BASE_DIR "${CMAKE_SOURCE_DIR}/compiler"
      OUTPUT_DIR "${CMAKE_BINARY_DIR}${VALA_BOOTSTRAP_DIR}/compiler"
      )
  else()
    include("${CMAKE_SOURCE_DIR}/compiler/generated/files.cmake")
    add_executable(valac${VALA_BOOTSTRAP_SUFFIX} ${VALAC_C_SOURCES})
    target_link_libraries(valac${VALA_BOOTSTRAP_SUFFIX} ${VALA_LIBRARIES})
  endif()
endfunction()

# write a files.cmake to outfile which lists packaged
# C files. the basename is taken from the filenames in
# the list varname and is prefixed by basedir.
function(_vala_write_c_files varname basedir outfile)
  if(VALA_ENABLE_MAINTAINER_MODE)
    set(srcs)
    foreach(s ${${varname}})
      if(NOT s MATCHES "\\.h")
        get_filename_component(s "${s}" NAME)
        list(APPEND srcs "${basedir}/${s}")
      endif()
    endforeach()
    string(REPLACE ";" "\n  " srcs "${srcs}")
    file(WRITE "${outfile}" "set(${varname}\n  ${srcs}\n  )\n")
  endif()
endfunction()

# copy generated c sources (srcs) and files.cmake to dir and .vapi files to
# vapi/generated/. set up a target to copy generated files into the source
# tree.
if(VALA_ENABLE_MAINTAINER_MODE)
  add_custom_target(self-contained)
endif()
function(_vala_create_self_contained name dir srcs files_cmake vapis)
  if(VALA_ENABLE_MAINTAINER_MODE)
    add_custom_target(self-contained-${name}
      DEPENDS ${srcs} ${files_cmake}
      COMMENT "Copying generated sources to ${dir}"
      )
    add_dependencies(self-contained self-contained-${name})
    foreach(c ${srcs})
      get_filename_component(cc "${c}" NAME)
      add_custom_command(TARGET self-contained-${name} PRE_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${c}" "${dir}/${cc}"
        DEPENDS "${c}"
        VERBATIM
        )
    endforeach()
    if(files_cmake)
      add_custom_command(TARGET self-contained-${name} PRE_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${files_cmake}" "${dir}/files.cmake"
        DEPENDS "${files_cmake}"
        VERBATIM
        )
    endif()
    if(vapis)
      foreach(v ${vapis})
        get_filename_component(vv "${v}" NAME)
        add_custom_command(TARGET self-contained-${name} PRE_BUILD
          COMMAND "${CMAKE_COMMAND}" -E copy_if_different
          "${v}" "${CMAKE_SOURCE_DIR}/vapi/generated/${vv}"
          DEPENDS "${v}"
          VERBATIM
          )
      endforeach()
    endif()
  endif(VALA_ENABLE_MAINTAINER_MODE)
endfunction()

# Create the tests source
#
#  vala_create_tests(<outfile> <src1> [<src2> ... <srcN>])
#
# Will create the file <outfile> from test sources <src1>...<srcN>. The
# variable VALA_TEST_PACKAGES will contain a list of packages that is required
# by the test. VALA_TEST_PATHS will contain a list of "test paths".
#
# The whole thing is a big hack and definitely needs cleaning up
#
function(vala_create_tests outfile)
  set(VALA_TEST_SWITCH_SOURCE)
  set(VALA_TEST_BODY_SOURCE)
  set(VALA_TEST_PACKAGES)
  set(VALA_TEST_PATHS)
  foreach(test ${ARGN})
    if(test MATCHES "(.*)\\.vala$")
      set(testpath "${CMAKE_MATCH_1}")
      list(APPEND VALA_TEST_PATHS ${testpath})
      # namespace name
      string(REPLACE "/" "." ns "${testpath}")
      string(REPLACE "-" "_" ns "${ns}")
      # append case statement
      set(VALA_TEST_SWITCH_SOURCE
        "${VALA_TEST_SWITCH_SOURCE}\t\tcase \"/${testpath}\": ${ns}.main (); break;\n")
      # append source
      file(READ "${test}" lines)
      set(VALA_TEST_BODY_SOURCE
        "${VALA_TEST_BODY_SOURCE}\nnamespace ${ns} {\n\n${lines}\n}\n")
    elseif(test MATCHES "(.*)\\.test$")
      set(testbase "${CMAKE_MATCH_1}")
      file(READ ${test} lines)
      # escape ; character (hope that :_:_: doesn't show up ever...)
      string(REPLACE ";" ":_:_:" lines "${lines}")
      string(REPLACE "\n" ";" lines "${lines}")
      # state variables
      set(part 0)
      set(inheader TRUE)
      set(i 0)
      foreach(l IN LISTS lines)
        math(EXPR i "${i} + 1")
        # put ; back in
        string(REPLACE ":_:_:" ";" l "${l}")
        if(part EQUAL 0)
          if(l MATCHES "^Packages: *(.*)$")
            separate_arguments(pkgs UNIX_COMMAND "${CMAKE_MATCH_1}")
            list(APPEND VALA_TEST_PACKAGES ${pkgs})
          elseif(l STREQUAL "")
            set(part 1)
          else()
            message(SEND_ERROR
              "${test}:${i}: Expected empty line or 'Packages:'\n"
              "${test}:${i}: Got '${l}' instead" )
          endif()
        else(part EQUAL 0)
          if(inheader)
            if(l MATCHES "^Program: *(.*)$")
              set(name "${CMAKE_MATCH_1}")
              set(testpath "${testbase}/${name}")
              string(REPLACE "/" "." ns "${testpath}")
              string(REPLACE "-" "_" ns "${ns}")
              set(VALA_TEST_SWITCH_SOURCE
                "${VALA_TEST_SWITCH_SOURCE}\t\tcase \"/${testpath}\": ${ns}.main (); break;\n")
              set(VALA_TEST_BODY_SOURCE
                "${VALA_TEST_BODY_SOURCE}\nnamespace ${ns} {\n\n")
            elseif(l STREQUAL "")
              set(inheader FALSE)
            else()
              message(SEND_ERROR
                "${test}:${i}: Expected empty line or 'Program:'")
            endif()
          else(inheader)
            # ! inheader
            if(l MATCHES "^Program: *(.*)$")
              # print end
              set(VALA_TEST_BODY_SOURCE "${VALA_TEST_BODY_SOURCE}\n}\n")
              # parse new header
              set(inheader TRUE)
              math(EXPR part "${part} + 1")
              set(name "${CMAKE_MATCH_1}")
              set(testpath "${testbase}/${name}")
              string(REPLACE "/" "." ns "${testpath}")
              string(REPLACE "-" "_" ns "${ns}")
              set(VALA_TEST_SWITCH_SOURCE
                "${VALA_TEST_SWITCH_SOURCE}\t\tcase \"/${testpath}\": ${ns}.main (); break;\n")
              set(VALA_TEST_BODY_SOURCE
                "${VALA_TEST_BODY_SOURCE}\nnamespace ${ns} {\n\n")
            else()
              set(VALA_TEST_BODY_SOURCE "${VALA_TEST_BODY_SOURCE}${l}\n")
            endif()
          endif(inheader)
        endif(part EQUAL 0)
      endforeach(l)
      set(VALA_TEST_BODY_SOURCE "${VALA_TEST_BODY_SOURCE}\n}\n")
      list(APPEND VALA_TEST_PATHS ${testpath})
    else()
      message(SEND_ERROR "Unknown test '${test}'")
    endif(test MATCHES "(.*)\\.vala$")
  endforeach(test)
  configure_file("${CMAKE_SOURCE_DIR}/cmake/ValaTestsMainTemplate.vala.in"
    "${outfile}" @ONLY)
  set(VALA_TEST_PACKAGES "${VALA_TEST_PACKAGES}" PARENT_SCOPE)
  set(VALA_TEST_PATHS "${VALA_TEST_PATHS}" PARENT_SCOPE)
endfunction()

# determine the vala version (sets VALA_VERSION)
function(set_vala_version)
  set(VALA_VERSION)
  if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.git")
    find_program(GIT_EXECUTABLE git)
    mark_as_advanced(GIT_EXECUTABLE)
    if(GIT_EXECUTABLE)
      # find last tagged version (git must use the <tag>-<ncommits>-g<id> output format)
      execute_process(
        COMMAND "${GIT_EXECUTABLE}" describe --abbrev=4 --dirty
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        RESULT_VARIABLE status
        OUTPUT_VARIABLE VALA_VERSION
        ERROR_QUIET
        )
      if(status OR NOT VALA_VERSION MATCHES "^[^- \t]+-[0-9]+-g[a-z0-9]+")
        message(FATAL_ERROR "Failed to retrieve version information using git.\n"
          "Got VALA_VERSION = ${VALA_VERSION}")
      endif()
      string(STRIP "${VALA_VERSION}" VALA_VERSION)
      # replace first - by a .
      string(REGEX REPLACE "^([^-]+)-(.*)" "\\1.\\2" VALA_VERSION "${VALA_VERSION}")
      # replace useless -g by - in the abbreviated commit-id
      string(REGEX REPLACE "^([^-]+)-g" "\\1-" VALA_VERSION "${VALA_VERSION}")
    endif()
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/.version")
    file(READ "${CMAKE_SOURCE_DIR}/.version" VALA_VERSION)
    string(STRIP "${VALA_VERSION}" VALA_VERSION)
    if(NOT VALA_VERSION MATCHES "^[0-9]+.[0-9]+.[0-9]+-[a-z0-9]+")
      message(FATAL_ERROR "FAiled to read version information from .version")
    endif()
  else()
    message(FATAL_ERROR "Cannot determine version information")
  endif()
  set(VALA_VERSION "${VALA_VERSION}" PARENT_SCOPE)
endfunction()
