# build the vala library
_vala_build_libvala()

# set up for installation and creating a self-contained distribution
if(VALA_DO_PRECOMPILE)
  set(VALA_HDRS
    "${CMAKE_BINARY_DIR}/include/valagee.h"
    "${CMAKE_BINARY_DIR}/include/valaccode.h"
    "${CMAKE_BINARY_DIR}/include/vala.h"
    "${CMAKE_BINARY_DIR}/include/valacodegen.h"
    )
  _vala_write_c_files(VALAGEE_C_SOURCES
    "\${CMAKE_SOURCE_DIR}/gee/generated"
    "${CMAKE_BINARY_DIR}/gee/files.cmake")
  _vala_write_c_files(VALACCODE_C_SOURCES
    "\${CMAKE_SOURCE_DIR}/ccode/generated"
    "${CMAKE_BINARY_DIR}/ccode/files.cmake")
  _vala_write_c_files(VALACORE_C_SOURCES
    "\${CMAKE_SOURCE_DIR}/vala/generated"
    "${CMAKE_CURRENT_BINARY_DIR}/files.cmake")
  _vala_write_c_files(VALACODEGEN_C_SOURCES
    "\${CMAKE_SOURCE_DIR}/codegen/generated"
    "${CMAKE_BINARY_DIR}/codegen/files.cmake")

  _vala_create_self_contained(gee "${CMAKE_SOURCE_DIR}/gee/generated"
    "${VALAGEE_C_SOURCES}"
    "${CMAKE_BINARY_DIR}/gee/files.cmake"
    "${CMAKE_BINARY_DIR}/gee/gee.vapi"
    )
  _vala_create_self_contained(ccode "${CMAKE_SOURCE_DIR}/ccode/generated"
    "${VALACCODE_C_SOURCES}"
    "${CMAKE_BINARY_DIR}/ccode/files.cmake"
    "${CMAKE_BINARY_DIR}/ccode/ccode.vapi"
    )
  _vala_create_self_contained(vala "${CMAKE_CURRENT_SOURCE_DIR}/generated"
    "${VALACORE_C_SOURCES}"
    "${CMAKE_CURRENT_BINARY_DIR}/files.cmake"
    "${CMAKE_BINARY_DIR}/vala/vala.vapi"
    )
  _vala_create_self_contained(codegen "${CMAKE_SOURCE_DIR}/codegen/generated"
    "${VALACODEGEN_C_SOURCES}"
    "${CMAKE_BINARY_DIR}/codegen/files.cmake"
    "${CMAKE_BINARY_DIR}/codegen/codegen.vapi"
    )
else()
  set(VALA_HDRS
    "${CMAKE_SOURCE_DIR}/gee/generated/valagee.h"
    "${CMAKE_SOURCE_DIR}/ccode/generated/valaccode.h"
    "${CMAKE_SOURCE_DIR}/vala/generated/vala.h"
    "${CMAKE_SOURCE_DIR}/codegen/generated/valacodegen.h"
    )
endif()

set_target_properties(vala PROPERTIES
  PUBLIC_HEADER "${VALA_HDRS}"
  )

# install libvala
install(TARGETS vala EXPORT ValaExports
  ARCHIVE DESTINATION "${VALA_LIB_DIR}" COMPONENT dev
  RUNTIME DESTINATION "${VALA_BIN_DIR}" COMPONENT shlibs
  LIBRARY DESTINATION "${VALA_LIB_DIR}" COMPONENT shlibs
  PUBLIC_HEADER DESTINATION "${VALA_INC_DIR}/vala-1.0" COMPONENT dev
  )
