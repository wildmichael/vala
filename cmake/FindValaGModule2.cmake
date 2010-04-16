# - This module finds the GModule-2.0 library
#
# The following variables will be defined for your use
#
#   GMODULE2_FOUND - Were all of your specified components found?
#   GMODULE2_INCLUDE_DIRS - All include directories
#   GMODULE2_LIBRARIES - All libraries
#

find_package(ValaGLib2 REQUIRED)

set(_GMODULE_NAMES)
foreach(_version RANGE 30 0 -2)
  list(APPEND _GMODULE_NAMES "gmodule-2.${_version}")
endforeach()

get_filename_component(_GMODULE_HINT "${GLIB2_GLIB_LIBRARY}" PATH)

find_library(GMODULE2_LIBRARY NAMES ${_GMODULE_NAMES}
  HINTS "${_GMODULE_HINT}"
  )
mark_as_advanced(GMODULE2_LIBRARY)

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(ValaGModule2 DEFAULT_MSG
  GMODULE2_LIBRARY
  )

set(GMODULE2_INCLUDE_DIRS ${GLIB2_INCLUDE_DIRS})
set(GMODULE2_LIBRARIES ${GMODULE2_LIBRARY} ${GLIB2_LIBRARIES})
