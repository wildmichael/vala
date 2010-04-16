# build the compiler
_vala_build_compiler()

# set up for creating self-contained distribution
if(VALA_DO_PRECOMPILE)
  get_target_property(VALAC_C_SOURCES valac VALA_C_SOURCES)
  _vala_write_c_files(VALAC_C_SOURCES
    "\${CMAKE_SOURCE_DIR}/compiler/generated"
    "${CMAKE_CURRENT_BINARY_DIR}/files.cmake")
  _vala_create_self_contained(compiler "${CMAKE_CURRENT_SOURCE_DIR}/generated"
    "${VALAC_C_SOURCES}" "${CMAKE_CURRENT_BINARY_DIR}/files.cmake" "")
endif()

# install valac
install(TARGETS valac EXPORT ValaExports
  RUNTIME DESTINATION "${VALA_BIN_DIR}" COMPONENT bin
  )
