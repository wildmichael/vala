# build the vala docs
add_subdirectory(vala)

# install the man-pages
set(VALA_MANPAGES valac.1)
if(VALA_ENABLE_VAPIGEN)
  list(APPEND VALA_MANPAGES vala-gen-introspect.1 vapigen.1)
endif()

install(FILES ${VALA_MANPAGES}
  DESTINATION "${VALA_MAN_DIR}/man1" COMPONENT doc)

