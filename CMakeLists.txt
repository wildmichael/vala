project(Vala C)

# include useful tools
######################

set(VALA_CMAKE_DIR "${CMAKE_SOURCE_DIR}/cmake")
include("${CMAKE_SOURCE_DIR}/cmake/UseVala.cmake")
include("${CMAKE_SOURCE_DIR}/cmake/ValaInternal.cmake")

# version numbers/dates
#######################

set(VALA_MINIMUM_REQUIRED_VALAC_VERSION 0.7.0)
set(VALA_MIMIMUM_REQUIRED_GLIB_VERSION 2.14.0)
set(VALA_MINIMUM_CMAKE_VERSION 2.8)
set(VALA_CHANGELOG_START_DATE 2009-02-25)

cmake_minimum_required(VERSION ${VALA_MINIMUM_CMAKE_VERSION} FATAL_ERROR)

set_vala_version()

# custom configuration type for coverage tests
##############################################

# Xcode generator is buggy (linker flags are not inherited from compile flags
# and custom configurations don't work with shared libraries)
if(CMAKE_COMPILER_IS_GNUCC AND NOT CMAKE_GENERATOR STREQUAL Xcode)
  set(CMAKE_C_FLAGS_COVERAGE "-O0 -g --coverage" CACHE
    STRING "Flags used by the compiler during coverage test builds")
  set(VALA_COMPILE_FLAGS_COVERAGE "-g" CACHE
    STRING "Flags used by the Vala compiler during test builds")
  mark_as_advanced(CMAKE_C_FLAGS_COVERAGE CMAKE_EXE_LINKER_FLAGS_COVERAGE
    CMAKE_SHARED_LINKER_FLAGS_COVERAGE CMAKE_MODULE_LINKER_FLAGS_COVERAGE
    VALA_COMPILE_FLAGS_COVERAGE)
  if(CMAKE_CONFIGURATION_TYPES)
    list(APPEND CMAKE_CONFIGURATION_TYPES Coverage)
    list(REMOVE_DUPLICATES CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_CONFIGURATION_TYPES "${CMAKE_CONFIGURATION_TYPES}" CACHE STRING
      "Semicolon separated list of supported configuration types [Debug|Release|MinSizeRel|RelWithDebInfo|Coverage]"
      FORCE)
  endif()
endif()

# detect some features we need to set sensible defaults for below options
#########################################################################

# detect whether we MUST use an external vala compiler
if(EXISTS "${CMAKE_SOURCE_DIR}/vala/generated/files.cmake")
  set(VALA_MUST_BOOTSTRAP FALSE)
else()
  set(VALA_MUST_BOOTSTRAP TRUE)
endif()

# check for valac itself (required for bootstrapping)
find_program(VALA_SYSTEM_COMPILER valac
  DOC "valac compiler used for bootstraping")
mark_as_advanced(VALA_SYSTEM_COMPILER)
if(VALA_SYSTEM_COMPILER)
  execute_process(COMMAND "${VALA_SYSTEM_COMPILER}" "--version"
    OUTPUT_VARIABLE VALA_SYSTEM_VERSION)
  string(REPLACE "Vala" "" VALA_SYSTEM_VERSION ${VALA_SYSTEM_VERSION})
  string(STRIP "${VALA_SYSTEM_VERSION}" VALA_SYSTEM_VERSION)
else()
  set(VALA_SYSTEM_VERSION 0)
endif()

if(VALA_MUST_BOOTSTRAP)
  if(NOT VALA_SYSTEM_COMPILER OR
      ${VALA_SYSTEM_VERSION} VERSION_LESS ${VALA_MINIMUM_REQUIRED_VALAC_VERSION})
    message(FATAL_ERROR
      "You must have vala >= ${VALA_MINIMUM_REQUIRED_VALAC_VERSION} installed "
      "to bootstrap vala. Download the appropriate package "
      "from your distribution or get the source tarball "
      "which includes the C sources at "
      "http://download.gnome.org/sources/vala/"
      )
  endif()
endif()

# options and installation paths
################################

if(NOT VALA_MUST_BOOTSTRAP)
  option(VALA_USE_SYSTEM_COMPILER
    "Bootstrap using the installed vala compiler instead from C-sources" OFF)
else()
  set(VALA_USE_SYSTEM_COMPILER ON)
endif()
option(VALA_ENABLE_RECOMPILE "Recompile vala with the bootstrapped compiler" OFF)
option(VALA_ENABLE_VAPIGEN "Enable VAPI generator" OFF)
option(VALA_ENABLE_TESTING "Enable unit tests" OFF)
option(VALA_ENABLE_MAINTAINER_MODE "Enable special maintenance targets" OFF)

set(VALA_BIN_DIR bin CACHE STRING "Installation directory for executables")
set(VALA_LIB_DIR lib CACHE STRING "Installation directory for libraries")
set(VALA_INC_DIR include CACHE STRING
  "Installation directory for development headers")
set(VALA_DATA_DIR share CACHE STRING
  "Installation directory for data files")
set(VALA_MAN_DIR share/man CACHE STRING
  "Installation directory for man pages")

# most users will not want to see any of above options
mark_as_advanced(VALA_USE_SYSTEM_COMPILER VALA_ENABLE_RECOMPILE
  VALA_ENABLE_VAPIGEN VALA_ENABLE_TESTING VALA_ENABLE_MAINTAINER_MODE
  VALA_BIN_DIR VALA_LIB_DIR VALA_INC_DIR VALA_DATA_DIR VALA_MAN_DIR)

# make the installation paths absolute if they are relative to
# CMAKE_INSTALL_PREFIX
foreach(d BIN LIB INC DATA MAN)
  if(NOT IS_ABSOLUTE "${VALA_${d}_DIR}")
    set(VALA_${d}_DIR "${CMAKE_INSTALL_PREFIX}/${VALA_${d}_DIR}")
  endif()
endforeach()

# find required packages
########################

if(VALA_ENABLE_VAPIGEN)
  if(VALA_MUST_BOOTSTRAP)
    # don't have C sources, must have flex and bison
    find_package(FLEX REQUIRED)
    find_package(BISON REQUIRED)
    set(VALA_USE_FLEX_AND_BISON TRUE)
  else()
    # they are optional, we have C sources
    find_package(FLEX)
    find_package(BISON)
    if(FLEX_FOUND AND BISON_FOUND)
      # if we have both of them, offer the choice
      option(VALA_USE_FLEX_AND_BISON
        "Compile lexer and parser using Flex and Bison instead from C-sources"
        OFF)
      mark_as_advanced(VALA_USE_FLEX_AND_BISON)
    endif()
  endif()
endif()

find_program(XSLTPROC_EXECUTABLE xsltproc)
if(NOT VALA_MUST_BOOTSTRAP AND XSLTPROC_EXECUTABLE)
  option(VALA_USE_XSLTPROC "Rebuild documentation with xsltproc" OFF)
elseif(VALA_MUST_BOOTSTRAP AND XSLTPROC_EXECUTABLE)
  set(VALA_USE_XSLTPROC TRUE)
endif()
mark_as_advanced(XSLTPROC_EXECUTABLE VALA_USE_XSLTPROC)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
find_package(ValaGLib2 ${VALA_MIMIMUM_REQUIRED_GLIB_VERSION} REQUIRED)

if(VALA_ENABLE_TESTING)
  find_package(ValaDBus REQUIRED)
  find_package(ValaGIO REQUIRED)
endif()

if(VALA_ENABLE_VAPIGEN)
  # find gmodule and gthread
  find_package(ValaGModule2 REQUIRED)
  find_package(ValaGThread2 REQUIRED)
endif()

# build vala
############

# configure config.h
configure_file(config.h.in "${CMAKE_BINARY_DIR}/config.h" @ONLY)

# configure version.h
configure_file(version.h.in "${CMAKE_BINARY_DIR}/version.h")

# set up include paths
include_directories(
  "${CMAKE_SOURCE_DIR}/gobject-introspection"
  "${CMAKE_BINARY_DIR}"
  ${GLIB2_INCLUDE_DIRS}
  )

# make sure that the right vapis get picked up
set(VALA_VAPI_DIRS "${CMAKE_SOURCE_DIR}/vapi")

# set up compiler executable to use
if(VALA_USE_SYSTEM_COMPILER)
  set(VALA_DO_PRECOMPILE TRUE)
  set(VALA_COMPILER "${VALA_SYSTEM_COMPILER}")
else()
  set(VALA_DO_PRECOMPILE FALSE)
endif()

# set up libraries to link against
set(VALA_LIBRARIES
  vala${VALA_BOOTSTRAP_SUFFIX}
  ${GLIB2_LIBRARIES}
  )

# set up install_name directory
if(APPLE)
  set(CMAKE_INSTALL_NAME_DIR "${VALA_LIB_DIR}")
elseif(UNIX)
  set(CMAKE_INSTALL_RPATH "${VALA_LIB_DIR}")
endif()

if(VALA_ENABLE_RECOMPILE)
  # if user wants to recompile, go into the bootstrap directory
  add_subdirectory(bootstrap)
  # need to know the actual output location of the bootstrapped compiler
  get_target_property(VALA_COMPILER valac_bootstrap LOCATION)
  set(VALA_DO_PRECOMPILE TRUE)
endif()

# extend include paths
if(VALA_DO_PRECOMPILE)
  include_directories("${CMAKE_BINARY_DIR}/include")
else()
  include_directories(
    "${CMAKE_SOURCE_DIR}/gee/generated"
    "${CMAKE_SOURCE_DIR}/ccode/generated"
    "${CMAKE_SOURCE_DIR}/vala/generated"
    "${CMAKE_SOURCE_DIR}/codegen/generated"
    )
endif()

# build actual vala library and compiler
add_subdirectory(vala)
add_subdirectory(compiler)

# since we have our own compiler now, use that one from now on
get_target_property(VALA_COMPILER valac LOCATION)
# once more, extend include path
if(NOT VALA_ENABLE_RECOMPILE AND NOT VALA_USE_SYSTEM_COMPILER)
  include_directories(
    gee/generated
    ccode/generated
    vala/generated
    codegen/generated
    )
else()
  include_directories("${CMAKE_BINARY_DIR}/include")
endif()

# deal with the vapis
add_subdirectory(vapi)

# do vapigen if enabled
if(VALA_ENABLE_VAPIGEN)
  add_subdirectory(gobject-introspection)
  add_subdirectory(vapigen)
endif()

# do the testing stuff if enabled
if(VALA_ENABLE_TESTING)
  include(CTest)
  add_subdirectory(tests)
endif()

# generate the docs
add_subdirectory(doc)

# export targets to build and install tree
##########################################

set(VALA_EXPORT_TARGETS valac vala)
if(VALA_ENABLE_VAPIGEN)
  list(APPEND VALA_EXPORT_TARGETS gen-introspect vapigen vapicheck)
endif()
export(TARGETS ${VALA_EXPORT_TARGETS}
  NAMESPACE Vala:
  FILE "${CMAKE_BINARY_DIR}/ValaExports.cmake")
if(${CMAKE_VERSION} VERSION_GREATER 2.6.4)
  export(PACKAGE Vala)
endif()
install(EXPORT ValaExports
  DESTINATION "${VALA_DATA_DIR}/vala/cmake"
  NAMESPACE Vala:
  COMPONENT dev)

# configure and install CMake files
###################################

configure_file(cmake/UseVala.cmake
  "${CMAKE_BINARY_DIR}/UseVala.cmake" COPYONLY)
configure_file(cmake/ValaDriver.cmake.in
  "${CMAKE_BINARY_DIR}/ValaDriver.cmake.in" COPYONLY)
configure_file(cmake/FindValaGLib2.cmake
  "${CMAKE_BINARY_DIR}/FindValaGLib2.cmake" COPYONLY)
configure_file(cmake/FindValaGModule2.cmake
  "${CMAKE_BINARY_DIR}/FindValaGModule2.cmake" COPYONLY)
configure_file(cmake/FindValaGThread2.cmake
  "${CMAKE_BINARY_DIR}/FindValaGThread2.cmake" COPYONLY)
configure_file(cmake/ValaConfigVersion.cmake.in
  "${CMAKE_BINARY_DIR}/ValaConfigVersion.cmake" @ONLY)
# set up for build tree
set(CONFIG_CMAKE_DIR "${CMAKE_BINARY_DIR}")
set(CONFIG_VAPI_DIR "${CMAKE_BINARY_DIR}/vapi")
set(CONFIG_INC_DIR "${CMAKE_BINARY_DIR}/include")
set(CONFIG_VALA_GEN_INTROSPECT_LOCATION
  "${CMAKE_BINARY_DIR}/vapigen/vala-gen-introspect/vala-gen-introspect")
configure_file(cmake/ValaConfig.cmake.in
  "${CMAKE_BINARY_DIR}/ValaConfig.cmake" @ONLY)
# set up for install tree
set(CONFIG_CMAKE_DIR "${VALA_DATA_DIR}/vala/cmake")
set(CONFIG_VAPI_DIR "${VALA_DATA_DIR}/vala/vapi")
set(CONFIG_INC_DIR "${VALA_INC_DIR}/vala-1.0")
set(CONFIG_VALA_GEN_INTROSPECT_LOCATION
  "${VALA_LIB_DIR}/vala/vala-gen-introspect")
configure_file(cmake/ValaConfig.cmake.in
  "${CMAKE_BINARY_DIR}/install_files/ValaConfig.cmake" @ONLY)
# install the cmake files
install(FILES
  cmake/UseVala.cmake
  cmake/ValaDriver.cmake.in
  cmake/FindValaGLib2.cmake
  cmake/FindValaGModule2.cmake
  cmake/FindValaGThread2.cmake
  "${CMAKE_BINARY_DIR}/ValaConfigVersion.cmake"
  "${CMAKE_BINARY_DIR}/install_files/ValaConfig.cmake"
  DESTINATION "${CONFIG_CMAKE_DIR}" COMPONENT dev)

if(VALA_ENABLE_MAINTAINER_MODE AND IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.git")
  find_program(PERL_EXECUTABLE perl)
  mark_as_advanced(PERL_EXECUTABLE)

  # convenience target to update the changelog
  ############################################
  configure_file(cmake/ValaUpdateChangeLog.cmake.in
    "${CMAKE_BINARY_DIR}/ValaUpdateChangeLog.cmake" @ONLY)
  if(PERL_EXECUTABLE)
    # add target to generate ChangeLog
    add_custom_target(gen-ChangeLog
      COMMAND "${CMAKE_COMMAND}" -P
      "${CMAKE_BINARY_DIR}/ValaUpdateChangeLog.cmake"
      COMMENT "Creating ${CMAKE_SOURCE_DIR}/ChangeLog"
      VERBATIM
      )
  endif()

  # convenience target to create/update .version
  ##############################################
  add_custom_target(gen-version
    "${CMAKE_COMMAND}" -DVALA_VERSION=${VALA_VERSION}
      -P "${CMAKE_SOURCE_DIR}/cmake/ValaUpdateVersionFile.cmake"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Creating ${CMAKE_SOURCE_DIR}/.version"
    VERBATIM
    )
  # TODO Automatically create .version when creating source dist
endif()

# add 'check' target to configure, build, test and run coverage tool
####################################################################

if(VALA_ENABLE_TESTING AND BUILD_TESTING)
  set(test_command "${CMAKE_CTEST_COMMAND}")
  if(CMAKE_CONFIGURATION_TYPES)
    list(APPEND test_command -C "${CMAKE_CFG_INTDIR}")
  endif(CMAKE_CONFIGURATION_TYPES)
  list(APPEND test_command -D Experimental)
  add_custom_target(check
    COMMAND ${test_command}Start
    COMMAND ${test_command}Configure
    COMMAND ${test_command}Build
    COMMAND ${test_command}Test
    COMMAND ${test_command}Coverage
    )
endif()

# configure and install pkg-config file
#######################################

set(VERSION "${VALA_VERSION}")
set(prefix "${CMAKE_INSTALL_PREFIX}")
set(exec_prefix)
set(bindir "${VALA_BIN_DIR}")
set(libdir "${VALA_LIB_DIR}")
set(includedir "${VALA_INC_DIR}")
set(datarootdir "${VALA_DATA_DIR}")
set(datadir "\${datarootdir}")
set(vapidir "\${datarootdir}/vala/vapi")
if(VALA_ENABLE_VAPIGEN)
  set(vapigen_decl "vapigen=\${bindir}/vapigen")
  set(gen_introspect_decl "gen_introspect=\${libdir}/vala/gen-introspect")
  set(vala_gen_introspect_decl "vala_gen_introspect=\${libdir}/vala/vala-gen-introspect")
endif()
configure_file(vala-1.0.pc.in "${CMAKE_BINARY_DIR}/install_files/vala-1.0.pc" @ONLY)
install(FILES "${CMAKE_BINARY_DIR}/install_files/vala-1.0.pc"
  DESTINATION "${VALA_LIB_DIR}/pkgconfig" COMPONENT dev)
