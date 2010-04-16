# - This module finds the DBus-1.0 library
#
# The following variables will be defined for your use
#
#   DBUS_FOUND - Were all of your specified components found?
#   DBUS_INCLUDE_DIRS - All include directories
#   DBUS_LIBRARIES - All libraries
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

find_path(DBUS_dbus_INCLUDE_DIR dbus/dbus.h
  PATHS
    /opt/gnome/include
    /opt/openwin/include
    /sw/include
  PATH_SUFFIXES
    dbus-1.0
    dbus-1.0/include
  )
find_path(DBUS_arch_INCLUDE_DIR dbus/dbus-arch-deps.h
  PATHS
    /usr/local/lib64
    /usr/local/lib
    /usr/lib64
    /usr/lib
    /opt/gnome/include
    /opt/gnome/lib
    /opt/openwin/include
    /usr/openwin/lib
    /sw/include
    /sw/lib
  PATH_SUFFIXES
    dbus-1.0
    dbus-1.0/include
  )
find_library(DBUS_dbus_LIBRARY NAMES dbus-1
  PATHS
    /usr/local/lib64
    /usr/local/lib
    /usr/lib64
    /usr/lib
    /opt/gnome/lib
    /usr/openwin/lib
    /sw/lib
  )
find_library(DBUS_dbus-glib_LIBRARY NAMES dbus-glib-1
  PATHS
    /usr/local/lib64
    /usr/local/lib
    /usr/lib64
    /usr/lib
    /opt/gnome/lib
    /usr/openwin/lib
    /sw/lib
  )
mark_as_advanced(DBUS_dbus_INCLUDE_DIR DBUS_arch_INCLUDE_DIR
  DBUS_dbus_LIBRARY DBUS_dbus-glib_LIBRARY)

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(DBus DEFAULT_MSG
  DBUS_dbus_INCLUDE_DIR
  DBUS_arch_INCLUDE_DIR
  DBUS_dbus_LIBRARY
  DBUS_dbus-glib_LIBRARY
  )

set(DBUS_INCLUDE_DIRS ${DBUS_dbus_INCLUDE_DIR} ${DBUS_arch_INCLUDE_DIR})
set(DBUS_LIBRARIES ${DBUS_dbus_LIBRARY} ${DBUS_dbus-glib_LIBRARY})
