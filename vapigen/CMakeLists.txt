# do vala-gen-introspect
add_subdirectory(vala-gen-introspect)

# compile vapigen and vapicheck
set(vapigen_VALA_SOURCES
  valagidlparser.vala
  valavapigen.vala
  )

set(vapicheck_VALA_SOURCES valavapicheck.vala)

foreach(app vapigen vapicheck)
  vala_add_executable(${app}
    ${${app}_VALA_SOURCES}
    PACKAGES vala
    CUSTOM_VAPIS "${CMAKE_SOURCE_DIR}/gobject-introspection/gidl.vapi"
    BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    )
  target_link_libraries(${app}
    gidl
    )
endforeach()

# install them
install(TARGETS vapigen vapicheck EXPORT ValaExports
  RUNTIME DESTINATION "${VALA_BIN_DIR}" COMPONENT bin
  )
