# configure and install the vala-gen-introspect script
set(prefix "\"${CMAKE_INSTALL_PREFIX}\"")
set(exec_prefix)
set(libdir "\"${VALA_LIB_DIR}\"")
set(pkglibdir "\"${VALA_LIBEXEC_DIR}\"")

configure_file(vala-gen-introspect.in
  "${CMAKE_CURRENT_BINARY_DIR}/vala-gen-introspect" @ONLY)

install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/vala-gen-introspect"
  DESTINATION "${VALA_BIN_DIR}" COMPONENT bin)
