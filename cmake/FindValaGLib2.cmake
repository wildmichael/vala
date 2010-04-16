# - This module finds the glib-2.0 (and gobject-2.0) library
#
# The following variables will be defined for your use
#
#   GLIB2_FOUND - Were all of your specified components found?
#   GLIB2_INCLUDE_DIRS - All include directories
#   GLIB2_LIBRARIES - All libraries
#
#   GLIB2_VERSION - The version of glib-2.0 found (x.y.z)
#   GLIB2_MAJOR_VERSION - The major version of glib-2.0
#   GLIB2_MINOR_VERSION - The minor version of glib-2.0
#   GLIB2_PATCH_VERSION - The patch version of glib-2.0
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

#=============================================================
# _GLIB2_GET_VERSION
# Internal function to parse the version number in gtkversion.h
#   _OUT_major = Major version number
#   _OUT_minor = Minor version number
#   _OUT_micro = Micro version number
#   _gtkversion_hdr = Header file to parse
#=============================================================
function(_GLIB2_GET_VERSION _OUT_major _OUT_minor _OUT_micro _gtkversion_hdr)
  file(READ ${_gtkversion_hdr} _contents)
  if(_contents)
    string(REGEX REPLACE ".*#define GTK_MAJOR_VERSION[ \t]+\\(([0-9]+)\\).*" "\\1" ${_OUT_major} "${_contents}")
    string(REGEX REPLACE ".*#define GTK_MINOR_VERSION[ \t]+\\(([0-9]+)\\).*" "\\1" ${_OUT_minor} "${_contents}")
    string(REGEX REPLACE ".*#define GTK_MICRO_VERSION[ \t]+\\(([0-9]+)\\).*" "\\1" ${_OUT_micro} "${_contents}")

    if(NOT ${_OUT_major} MATCHES "[0-9]+")
      message(FATAL_ERROR "Version parsing failed for GLIB2_MAJOR_VERSION!")
    endif()
    if(NOT ${_OUT_minor} MATCHES "[0-9]+")
      message(FATAL_ERROR "Version parsing failed for GLIB2_MINOR_VERSION!")
    endif()
    if(NOT ${_OUT_micro} MATCHES "[0-9]+")
      message(FATAL_ERROR "Version parsing failed for GLIB2_MICRO_VERSION!")
    endif()

    set(${_OUT_major} ${${_OUT_major}} PARENT_SCOPE)
    set(${_OUT_minor} ${${_OUT_minor}} PARENT_SCOPE)
    set(${_OUT_micro} ${${_OUT_micro}} PARENT_SCOPE)
  else()
    message(FATAL_ERROR "Include file ${_gtkversion_hdr} does not exist")
  endif()
endfunction()

#=============================================================
# _GLIB2_FIND_INCLUDE_DIR
# Internal function to find the GLIB include directories
#  _var = variable to set
#  _hdr = header file to look for
#=============================================================
function(_GLIB2_FIND_INCLUDE_DIR _var _hdr)
  find_path(${_var} ${_hdr}
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
      glib-2.0
      glib-2.0/include
  )
  if(${_var})
    set(GLIB2_INCLUDE_DIRS ${GLIB2_INCLUDE_DIRS} ${${_var}} PARENT_SCOPE)
    mark_as_advanced(${_var})
  endif()
endfunction()

#=============================================================
# _GLIB2_FIND_LIBRARY
# Internal function to find libraries packaged with GLIB2
#  _var = library variable to create
#=============================================================
function(_GLIB2_FIND_LIBRARY _var _lib)

  # Not GTK versions per se but the versions encoded into Windows import
  # libraries. Also the MSVC libraries use _ for . (this is handled below)
  set(_versions 2.20 2.18 2.16 2.14 2.12
         2.10 2.8 2.6 2.4 2.2 2.0)

  set(_lib_list)
  foreach(_ver ${_versions})
    list(APPEND _lib_list "${_lib}-${_ver}")
  endforeach()

  find_library(${_var}
    NAMES ${_lib_list}
    PATHS
      /opt/gnome/lib
      /opt/gnome/lib64
      /usr/openwin/lib
      /usr/openwin/lib64
      /sw/lib
    )

  mark_as_advanced(${_var})
  list(APPEND GLIB2_LIBRARIES ${${_var}})
  set(GLIB2_LIBRARIES ${GLIB2_LIBRARIES} PARENT_SCOPE)
endfunction()

#=============================================================

#
# main()
#

set(GLIB2_FOUND)
set(GLIB2_INCLUDE_DIRS)
set(GLIB2_LIBRARIES)

#
# If specified, enforce version number
#
if(GLIB2_FIND_VERSION)
  cmake_minimum_required(VERSION 2.6.2)
  set(GLIB2_FAILED_VERSION_CHECK true)
  _GLIB2_FIND_INCLUDE_DIR(GLIB2_GLIBCONFIG_INCLUDE_DIR glibconfig.h)
  if(GLIB2_GLIBCONFIG_INCLUDE_DIR)
    _GLIB2_GET_VERSION(
      GLIB2_MAJOR_VERSION
      GLIB2_MINOR_VERSION
      GLIB2_PATCH_VERSION
      "${GLIB2_GLIBCONFIG_INCLUDE_DIR}/glibconfig.h")
    set(GLIB2_VERSION
      ${GLIB2_MAJOR_VERSION}.${GLIB2_MINOR_VERSION}.${GLIB2_PATCH_VERSION})
    if(GLIB2_FIND_VERSION_EXACT)
      if(GLIB2_VERSION VERSION_EQUAL GLIB2_FIND_VERSION)
        set(GLIB2_FAILED_VERSION_CHECK false)
      endif()
    else()
      if(GLIB2_VERSION VERSION_EQUAL  GLIB2_FIND_VERSION OR
          GLIB2_VERSION VERSION_GREATER GLIB2_FIND_VERSION)
        set(GLIB2_FAILED_VERSION_CHECK false)
      endif()
    endif()
  else()
    # If we can't find the GLIB config dir, we can't do version checking
    if(GLIB2_FIND_REQUIRED AND NOT GLIB2_FIND_QUIETLY)
      message(FATAL_ERROR
        "Could not find GLIB2 include directory containing glibconfig.h")
    endif()
    return()
  endif()

  if(GLIB2_FAILED_VERSION_CHECK)
    if(GLIB2_FIND_REQUIRED AND NOT GLIB2_FIND_QUIETLY)
      if(GLIB2_FIND_VERSION_EXACT)
        message(FATAL_ERROR
          "GLIB2 version check failed. Version ${GLIB2_VERSION} was found, "
          "version ${GLIB2_FIND_VERSION} is needed exactly.")
      else()
        message(FATAL_ERROR
          "GLIB2 version check failed. Version ${GLIB2_VERSION} was found, "
          "at least version ${GLIB2_FIND_VERSION} is required")
      endif()
    endif()

    # If the version check fails, exit out of the module here
    return()
  endif()
endif()

#
# Find libraries and headers
#

_GLIB2_FIND_INCLUDE_DIR(GLIB2_GLIB_INCLUDE_DIR glib.h)
_GLIB2_FIND_INCLUDE_DIR(GLIB2_GLIBCONFIG_INCLUDE_DIR glibconfig.h)
_GLIB2_FIND_LIBRARY    (GLIB2_GLIB_LIBRARY glib false true)

_GLIB2_FIND_INCLUDE_DIR(GLIB2_GOBJECT_INCLUDE_DIR gobject/gobject.h)
_GLIB2_FIND_LIBRARY    (GLIB2_GOBJECT_LIBRARY gobject false true)

#
# Solve for the GLIB2 version if we haven't already
#
if(NOT GLIB2_FIND_VERSION AND GLIB2_GLIBCONFIG_INCLUDE_DIR)
  _GLIB2_GET_VERSION(
    GLIB2_MAJOR_VERSION
    GLIB2_MINOR_VERSION
    GLIB2_PATCH_VERSION
    ${GLIB2_GLIBCONFIG_INCLUDE_DIR}/glibconfig.h)
  set(GLIB2_VERSION ${GLIB2_MAJOR_VERSION}.${GLIB2_MINOR_VERSION}.${GLIB2_PATCH_VERSION})
endif()

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(GLib2 DEFAULT_MSG
  GLIB2_GLIB_INCLUDE_DIR
  GLIB2_GLIBCONFIG_INCLUDE_DIR
  GLIB2_GLIB_LIBRARY
  GLIB2_GOBJECT_INCLUDE_DIR
  GLIB2_GOBJECT_LIBRARY
  )

if(GLIB2_INCLUDE_DIRS)
  list(REMOVE_DUPLICATES GLIB2_INCLUDE_DIRS)
endif()

