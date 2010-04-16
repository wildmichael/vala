# suffix appended to bootstrap targets
set(VALA_BOOTSTRAP_SUFFIX _bootstrap)
# subdirectory under which to place bootstrapped files
set(VALA_BOOTSTRAP_DIR /bootstrap)
# set up include directories and whether to precompile vala sources or use
# packaged C sources
include_directories(BEFORE "${CMAKE_CURRENT_BINARY_DIR}")
# set up libraries to link against
set(VALA_LIBRARIES
  vala${VALA_BOOTSTRAP_SUFFIX}
  ${GLIB2_LIBRARIES}
  )
if(VALA_USE_SYSTEM_COMPILER)
  set(VALA_DO_PRECOMPILE TRUE)
  include_directories(BEFORE "${CMAKE_CURRENT_BINARY_DIR}/include")
else()
  set(VALA_DO_PRECOMPILE FALSE)
  include_directories(BEFORE
    "${CMAKE_SOURCE_DIR}/gee/generated"
    "${CMAKE_SOURCE_DIR}/ccode/generated"
    "${CMAKE_SOURCE_DIR}/vala/generated"
    "${CMAKE_SOURCE_DIR}/codegen/generated"
    )
endif()
# set up a dummy config.h which doesnt cause the bootstrap library and compiler
# to rebuild all the time (after all, they're not installed).
set(VALA_VERSION "UNKNOWN-bootstrap")
set(VALA_DATA_DIR "${CMAKE_SOURCE_DIR}")
configure_file("${CMAKE_SOURCE_DIR}/config.h.in" "${CMAKE_CURRENT_BINARY_DIR}/config.h")
configure_file("${CMAKE_SOURCE_DIR}/version.h.in" "${CMAKE_CURRENT_BINARY_DIR}/version.h")

# bootstrap vala library and compiler
add_subdirectory(vala)
add_subdirectory(compiler)
