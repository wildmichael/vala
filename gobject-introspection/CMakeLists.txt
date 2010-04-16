# compile the gidl library
add_library(gidl STATIC
  gidlmodule.c
  gidlmodule.h
  gidlnode.c
  gidlnode.h
  gidlparser.c
  gidlparser.h
  girepository.h
  gmetadata.c
  gmetadata.h
  )

target_link_libraries(gidl
  ${GLIB2_LIBRARIES}
  ${GMODULE2_LIBRARIES}
  )

if(VALA_USE_FLEX_AND_BISON)
  # generate lexer and parser
  flex_target(scannerlexer scannerlexer.l
    "${CMAKE_CURRENT_BINARY_DIR}/scannerlexer.c")
  # (-d option is added by bison_target)
  bison_target(scannerparser scannerparser.y
    "${CMAKE_CURRENT_BINARY_DIR}/scannerparser.c")
  add_flex_bison_dependency(scannerlexer scannerparser)
  set(SCANNER_SOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/scannerlexer.c"
    "${CMAKE_CURRENT_BINARY_DIR}/scannerparser.c"
    "${CMAKE_CURRENT_BINARY_DIR}/scannerparser.h"
    )
  # set up for self-contained distribution
  _vala_write_c_files(SCANNER_SOURCES generated
    "${CMAKE_CURRENT_BINARY_DIR}/files.cmake")
  _vala_create_self_contained(gen-introspect
    "${CMAKE_CURRENT_SOURCE_DIR}/generated" "${SCANNER_SOURCES}"
    "${CMAKE_CURRENT_BINARY_DIR}/files.cmake" "")
else()
  # use precompiled lexer and parser sources
  include(generated/files.cmake)
  include_directories(generated)
endif()

# compile the gen-introspect executable
add_executable(gen-introspect
  grealpath.h
  gidlwriter.c
  gidlwriter.h
  scanner.c
  scanner.h
  ${SCANNER_SOURCES}
  )

set(LINK_LIBS
  gidl
  ${GLIB2_LIBRARIES}
  ${GMODULE2_LIBRARIES}
  ${GTHREAD2_LIBRARIES}
  )
list(REMOVE_DUPLICATES LINK_LIBS)

target_link_libraries(gen-introspect ${LINK_LIBS})

# install gen-introspect
install(TARGETS gen-introspect EXPORT ValaExports
  RUNTIME DESTINATION "${VALA_LIB_DIR}/vala" COMPONENT bin
  )
