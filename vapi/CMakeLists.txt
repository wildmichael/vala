if(VALA_USE_SYSTEM_COMPILER OR VALA_ENABLE_RECOMPILE)
  # combine gee.vapi, ccode.vapi, vala.vapi and codegen.vapi into vala-1.0.vapi
  configure_file("${CMAKE_SOURCE_DIR}/cmake/ValaCreateVapi.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/ValaCreateVapi.cmake" @ONLY)

  set(VALA_VAPI "${CMAKE_BINARY_DIR}/vapi/vala-1.0.vapi")
  add_custom_command(
    OUTPUT "${VALA_VAPI}"
    COMMAND "${CMAKE_COMMAND}"
      -P "${CMAKE_CURRENT_BINARY_DIR}/ValaCreateVapi.cmake"
    DEPENDS vala
    COMMENT "Creating ${VALA_VAPI}"
    )
  # convenience target to depend on
  add_custom_target(vala-vapi ALL DEPENDS "${VALA_VAPI}")
  # set up for self-contained distribution
  _vala_create_self_contained(vapi "${CMAKE_CURRENT_SOURCE_DIR}/generated"
    "" "" "${VALA_VAPI}")
else()
  set(VALA_VAPI generated/vala-1.0.vapi)
endif()

# get all the other vapis and append vala-1.0.vapi to the list
include(files.cmake)
foreach(v ${VAPIS})
  # configure vapis into binary tree
  configure_file(${v} "${CMAKE_CURRENT_BINARY_DIR}/${v}" COPYONLY)
endforeach()
list(APPEND VAPIS "${VALA_VAPI}")

# install the vapis
install(FILES ${VAPIS} DESTINATION "${VALA_DATA_DIR}/vala/vapi" COMPONENT data)
