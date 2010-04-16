# set up include directories
include_directories(
  ${DBUS_INCLUDE_DIRS}
  ${GIO_INCLUDE_DIRS}
  )

# parse the test descriptions
include(tests.cmake)
vala_create_tests("${CMAKE_CURRENT_BINARY_DIR}/main.vala" ${TESTS})

# set up options for vala packages used by the test executable
if(VALA_TEST_PACKAGES)
  list(REMOVE_DUPLICATES VALA_TEST_PACKAGES)
  set(VALA_TEST_PACKAGES PACKAGES ${VALA_TEST_PACKAGES})
endif()

# compile the test executable (don't use the name "test", that is reserved)
vala_add_executable(vala_test
  "${CMAKE_CURRENT_BINARY_DIR}/main.vala"
  ${VALA_TEST_PACKAGES}
  VAPI_DIRS "${CMAKE_SOURCE_DIR}/vapi"
  COMPILE_FLAGS --main=main --disable-warnings
  BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  )
target_link_libraries(vala_test
  ${DBUS_LIBRARIES}
  ${GIO_LIBRARIES}
  )
# make sure the executable is named "test"
set_target_properties(vala_test PROPERTIES
  OUTPUT_NAME test)

# add the tests
foreach(testpath IN LISTS VALA_TEST_PATHS)
  add_test(/${testpath} gcov test${CMAKE_EXECUTABLE_SUFFIX} /${testpath})
endforeach()
