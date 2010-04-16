# - This module finds the GIO-1.0 library
#
# The following variables will be defined for your use
#
#   GIO_FOUND - Were all of your specified components found?
#   GIO_INCLUDE_DIRS - All include directories
#   GIO_LIBRARIES - All libraries
#

#=============================================================================
# Copyright 2010 Michael Wild <themiwi@users.sf.net>
# Copyright 2009 Kitware, Inc.
# Copyright 2008-2009 Philip Lowman <philip@yhbt.com>
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file Copyright.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distributed this file outside of CMake, substitute the full
#  License text for the above reference.)

# This file is derived from FindGTK2.cmake (taken from CVS revision 1.4)
# The changelog below is for the original file.
#
# Version 0.8 (1/4/2010)
#   * Get module working under MacOSX fink by adding /sw/include, /sw/lib
#     to PATHS and the gobject library
# Version 0.7 (3/22/09)
#   * Checked into CMake CVS
#   * Added versioning support
#   * Module now defaults to searching for GTK if COMPONENTS not specified.
#   * Added HKCU prior to HKLM registry key and GTKMM specific environment
#      variable as per mailing list discussion.
#   * Added lib64 to include search path and a few other search paths where GTK
#      may be installed on Unix systems.
#   * Switched to lowercase CMake commands
#   * Prefaced internal variables with _GTK2 to prevent collision
#   * Changed internal macros to functions
#   * Enhanced documentation
# Version 0.6 (1/8/08)
#   Added GTK2_SKIP_MARK_AS_ADVANCED option
# Version 0.5 (12/19/08)
#   Second release to cmake mailing list

find_package(ValaGLib2 REQUIRED)

find_library(GIO_LIBRARY NAMES gio-2.0
  PATHS
    /usr/local/lib64
    /usr/local/lib
    /usr/lib64
    /usr/lib
    /opt/gnome/lib
    /usr/openwin/lib
    /sw/lib
  )

mark_as_advanced(GIO_LIBRARY)

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(GIO DEFAULT_MSG
  GIO_LIBRARY
  )

set(GIO_INCLUDE_DIRS ${GLIB2_INCLUDE_DIRS})
set(GIO_LIBRARIES ${GIO_LIBRARY} ${GLIB2_LIBRARIES})
