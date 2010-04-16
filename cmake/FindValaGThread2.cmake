# - This module finds the GThread-2.0 library
#
# The following variables will be defined for your use
#
#   GTHREAD2_FOUND - Were all of your specified components found?
#   GTHREAD2_INCLUDE_DIRS - All include directories
#   GTHREAD2_LIBRARIES - All libraries
#

find_package(ValaGLib2 REQUIRED)

set(_GTHREAD_NAMES)
foreach(_version RANGE 30 0 -2)
  list(APPEND _GTHREAD_NAMES "gthread-2.${_version}")
endforeach()

get_filename_component(_GTHREAD_HINT "${GLIB2_GLIB_LIBRARY}" PATH)

find_library(GTHREAD2_LIBRARY NAMES ${_GTHREAD_NAMES}
  HINTS "${_GTHREAD_HINT}"
  )
mark_as_advanced(GTHREAD2_LIBRARY)

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(ValaGThread2 DEFAULT_MSG
  GTHREAD2_LIBRARY
  )

set(GTHREAD2_INCLUDE_DIRS ${GLIB2_INCLUDE_DIRS})
set(GTHREAD2_LIBRARIES ${GTHREAD2_LIBRARY} ${GLIB2_LIBRARIES})
