#
# cmake-conanfile
#
# v 0.3.0-dev
# https://github.com/tkhyn/cmake-conanfile
#
# CMake wrapper for Conan 2
#
#
#
# The MIT License (MIT)
#
# Copyright (c) 2025+ Thomas Khyn
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# requires cmake_path
cmake_minimum_required(VERSION 3.20)

function(_check_conan)

  # extract cached variables for convenience
  set(CONAN_CMD ${CONANFILE_CONAN_CMD})
  set(CONAN_MODE ${CONANFILE_CONAN})
  if (NOT CONAN_MODE)
    set(CONAN_MODE AUTO)
  endif()

  if (NOT CONAN_CMD)
    if(CONAN_MODE STREQUAL LOCAL)
      # Conan not found yet, do not bother trying with system conan as we'll
      # have to set up a local conan by configuration
      message(NOTICE "Conanfile: Local conan not detected with CONANFILE_CONAN set to LOCAL")
      return()
    endif()

    # Try system-wide conan
    set(CONAN_CMD "conan")
  elseif(CONAN_CMD STREQUAL "conan")
    # Currently using system conan - check if we should switch to local
    if (CONAN_MODE STREQUAL LOCAL)
      # we were using system conan but switched to local
      message(NOTICE "Conanfile: Switching from system to local conan because CONANFILE_CONAN was set to LOCAL.")
      unset(CONANFILE_CONAN_CMD CACHE)
      return()
    endif()
  else()
    # Currently using local conan - check if we should (try to) switch to system
    if (CONAN_MODE STREQUAL SYSTEM)
      # we were using local conan but just switched to system
      message(NOTICE "Conanfile: Switching from local to system conan because CONANFILE_CONAN was set to SYSTEM.")
      set(CONAN_CMD "conan")
    elseif(CONAN_MODE STREQUAL AUTO)
      # CONAN_MODE is AUTO
      message(NOTICE "Conanfile: Currently using local conan but checking if local is available ")
      set(CONAN_CMD "conan")
    endif()
  endif()

  # test current conan and extract version if it works
  while(TRUE)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E env ${CONAN_CMD} --version
      RESULT_VARIABLE VERSION_RESULT
      OUTPUT_VARIABLE VERSION_INSTALLED
      ERROR_VARIABLE VERSION_ERROR
    )

    if(VERSION_RESULT STREQUAL "0" AND VERSION_INSTALLED MATCHES ".*Conan version ([0-9]+\\.[0-9]+\\.[0-9]+)[\\s\\r\\n]*")
      set(CONAN_FOUND TRUE)
    endif()

    if(NOT CONAN_FOUND)
      # conan --version failed or could not parse result
      if (CONAN_MODE STREQUAL AUTO AND CONAN_CMD STREQUAL "conan" AND CONANFILE_CONAN_CMD)
        # if we are here in auto mode and system conan isn't found
        # and there was a previous local conan command, try it
        set(CONAN_CMD ${CONANFILE_CONAN_CMD})
        continue()
      endif()

      # otherwise, we don't have a fallback option and need to look for another (probably local) conan
      list(GET CONAN_CMD -1 CONANFILE_CONAN_CMD_FOR_MSG)
      if (VERSION_RESULT STREQUAL "0")
        message(NOTICE "Conanfile: Conan not found (tried '${CONANFILE_CONAN_CMD_FOR_MSG}')")
      else()
        message(
          NOTICE
          "Conanfile: Could not extract conan version from \"${CONANFILE_CONAN_CMD_FOR_MSG} (got \"${VERSION_INSTALLED}\")."
        )
      endif()
      unset(CONANFILE_CONAN_CMD CACHE)

      if(CONAN_CMD STREQUAL "conan" AND CONAN_MODE STREQUAL SYSTEM)
        # We're in a dead end
        message(FATAL_ERROR
          "Conanfile: Conan not found in system and CONANFILE_CONAN is set to SYSTEM.\n"
          "Please install Conan on your system or set CONANFILE_CONAN to LOCAL or AUTO."
        )
      endif()

      return()
    endif()

    # we now have a valid version number, check if it matches the requirements
    set(VERSION_INSTALLED ${CMAKE_MATCH_1})

    # requirements results
    set(REQ_RESULT)

    set(VERSION_REQUIREMENTS ${CONANFILE_CONAN_VERSION})
    if (NOT VERSION_REQUIREMENTS)
      set(VERSION_REQUIREMENTS ~=2.0)
    endif()

    # sanity check to exclude conan 1
    if(VERSION_INSTALLED VERSION_LESS "2.0.0")
      list(APPEND REQ_RESULT "invalid conan version (${VERSION_INSTALLED}). cmake-conanfile only works with conan 2")
    endif()

    string(REPLACE " " "" VERSION_REQUIREMENTS ${VERSION_REQUIREMENTS})
    string(REPLACE "," ";" VERSION_REQUIREMENTS ${VERSION_REQUIREMENTS})
    list(LENGTH VERSION_REQUIREMENTS N_REQUIREMENTS)
    if (N_REQUIREMENTS EQUAL 0)
      message(
        FATAL_ERROR
        "Conanfile: No Conan version requirement defined in CONANFILE_CONAN_VERSION"
      )
    elseif(N_REQUIREMENTS GREATER 2)
      message(
        FATAL_ERROR
        "Conanfile: Cannot have more than 2 version requirements defined in CONANFILE_CONAN_VERSION"
      )
    else()
      foreach(VERSION_REQUIREMENT IN LISTS VERSION_REQUIREMENTS)
        string(
          REGEX MATCH "(==|>=|>|~=|<|<=)([0-9]+(\.[0-9]+(\.[0-9]+)?)?)"
          VERSION_REQUIREMENT_MATCH ${VERSION_REQUIREMENT}
        )
        if(CMAKE_MATCH_COUNT LESS 2)
          message(
            FATAL_ERROR
            "Conanfile: Could not parse version requirement '${VERSION_REQUIREMENT}'"
          )
        endif()
        set(VERSION_OPERATOR ${CMAKE_MATCH_1})
        set(VERSION_OPERAND ${CMAKE_MATCH_2})
        if (VERSION_OPERATOR STREQUAL "==")
          # exact match
          if (NOT VERSION_INSTALLED VERSION_EQUAL VERSION_OPERAND)
            list(APPEND REQ_RESULT "${VERSION_INSTALLED} does not match ${VERSION_OPERAND}")
          endif()
        elseif(VERSION_OPERATOR STREQUAL ">")
          # strictly greater
          if (NOT VERSION_INSTALLED VERSION_GREATER VERSION_OPERAND)
            list(APPEND REQ_RESULT "${VERSION_INSTALLED} is not greater than ${VERSION_OPERAND}")
          endif()
        elseif(VERSION_OPERATOR STREQUAL ">=")
          # greater or equal
          if (NOT VERSION_INSTALLED VERSION_GREATER_EQUAL VERSION_OPERAND)
            list(APPEND REQ_RESULT "${VERSION_INSTALLED} is not greater or equal than ${VERSION_OPERAND}")
          endif()
        elseif(VERSION_OPERATOR STREQUAL "~=")
          # versions must match except the last specified number
          if(NOT VERSION_INSTALLED VERSION_GREATER_EQUAL VERSION_OPERAND)
            if (NOT VERSION_INSTALLED VERSION_GREATER_EQUAL VERSION_OPERAND)
              list(APPEND REQ_RESULT "${VERSION_INSTALLED} is not greater or equal than ${VERSION_OPERAND}")
            endif()
          else()
            # trim installed version string to make its length match the requirement
            set(VERSION_INSTALLED_TRIMMED ${VERSION_INSTALLED})
            set(VERSION_OPERAND_TRIMMED ${VERSION_OPERAND})
            foreach(VERSION IN ITEMS OPERAND INSTALLED)
              # remove the last version in each version string
              string(REPLACE "." ";" VERSION_${VERSION}_TRIMMED ${VERSION_${VERSION}_TRIMMED})
              list(LENGTH VERSION_${VERSION}_TRIMMED N_${VERSION})
              if(${VERSION} STREQUAL "INSTALLED")
                while(N_INSTALLED GREATER N_OPERAND)
                  list(REMOVE_AT VERSION_INSTALLED_TRIMMED -1)
                  list(LENGTH VERSION_INSTALLED_TRIMMED N_INSTALLED)
                endwhile()
              endif()
              list(REMOVE_AT VERSION_${VERSION}_TRIMMED -1)
              list(JOIN VERSION_${VERSION}_TRIMMED "." VERSION_${VERSION}_TRIMMED)
            endforeach()
            if(NOT VERSION_INSTALLED_TRIMMED VERSION_EQUAL VERSION_OPERAND_TRIMMED)
              list(APPEND REQ_RESULT "${VERSION_INSTALLED} does not approximately match ${VERSION_OPERAND}")
            endif()
          endif()
        elseif(VERSION_OPERATOR STREQUAL "<")
          # strictly lower
          if(NOT VERSION_INSTALLED VERSION_LESS VERSION_OPERAND)
            list(APPEND REQ_RESULT "${VERSION_INSTALLED} is not lower than ${VERSION_OPERAND}")
          endif()
        elseif(VERSION_OPERATOR STREQUAL "<=")
          # lower or equal
          if(NOT VERSION_INSTALLED VERSION_LESS_EQUAL VERSION_OPERAND)
            list(APPEND REQ_RESULT "${VERSION_INSTALLED} is not lower or equal than ${VERSION_OPERAND}")
          endif()
        endif()
      endforeach()
    endif()

    if(NOT REQ_RESULT)
      # All good, installed version meets requirements, we can exit the check loop !
      break()
    endif()

    # prepare requirement issues list for reporting
    list(JOIN REQ_RESULT " and " REQ_RESULT)

    # in auto mode, we may have another go with local conan
    if (CONAN_MODE STREQUAL AUTO AND CONAN_CMD STREQUAL "conan" AND CONANFILE_CONAN_CMD MATCHES "^CONAN_HOME=.+")
      # if we are here in auto mode and system conan isn't found
      # and there was a previous local conan command, try it
      set(CONAN_CMD ${CONANFILE_CONAN_CMD})
      list(GET CONAN_CMD -1 CONANFILE_CONAN_CMD_FOR_MSG)
      message(
        NOTICE "Conanfile: found local conan but it doesn't satisfy the requirements (${REQ_RESULT}). Checking ${CONANFILE_CONAN_CMD_FOR_MSG}."
      )
      continue()
    endif()

    # otherwise, we don't have a fallback option and will need to look for another (probably local)
    # conan, but first, the user needs a report

    if (CONAN_MODE STREQUAL SYSTEM)
      # Can't go with local conan. Fail the configuration
      message(
        FATAL_ERROR
        "Conanfile: Conan version requirement (${CONANFILE_CONAN_VERSION}) not met for system conan: ${REQ_RESULT}\n"
        "Either:\n"
        "  - update system conan to a version that meets the requirement.\n"
        "  - relax the conan version requirements\n"
        "  - set CONANFILE_CONAN to AUTO or LOCAL\n"
      )
    elseif(CONAN_MODE STREQUAL AUTO AND CONAN_CMD STREQUAL "conan")
      # Go with local conan and warn the user
      message(
        WARNING
        "Conanfile: Conan version requirement (${CONANFILE_CONAN_VERSION}) not met on system conan: ${REQ_RESULT}\n"
        "Switching to a local conan installation as CONANFILE_CONAN is set to AUTO.\n"
      )
    else()
      message(
        NOTICE
        "Conanfile: Current conan version requirement (${CONANFILE_CONAN_VERSION}) not met: ${REQ_RESULT}\n"
        "Reinstalling local conan.\n"
      )
    endif()
    unset(CONANFILE_CONAN_CMD CACHE)
    return()
  endwhile()

  if ("${CONAN_CMD}" STREQUAL "conan")
    message(
      STATUS
      "Conanfile: Using system conan (version ${VERSION_INSTALLED})"
    )
  else()
    list(GET CONAN_CMD -1 CONANFILE_CONAN_CMD_FOR_MSG)
    list(GET CONAN_CMD -2 CONANFILE_CONAN_HOME)
    message(
      STATUS
      "Conanfile: Using conan from ${CONANFILE_CONAN_CMD_FOR_MSG} (version ${VERSION_INSTALLED}) "
      "with ${CONANFILE_CONAN_HOME}"
    )
  endif()

  set(CONANFILE_CONAN_CMD ${CONAN_CMD} CACHE INTERNAL "Conan executable for conanfile module")

endfunction()


function(_check_venv)
  if (NOT DEFINED CONANFILE_VENV_PYTHON_CMD)
    # no virtual env
    return()
  endif()

  execute_process(
    COMMAND ${CONANFILE_VENV_PYTHON_CMD} --version
    RESULT_VARIABLE CONANFILE_PYTHON_CMD
    OUTPUT_VARIABLE CONANFILE_PYTHON_VERSION
  )

  if(NOT CONANFILE_PYTHON_CMD EQUAL 0)
    message(
      NOTICE "Conanfile: Invalid virtual environment or python executable (tried ${CONANFILE_VENV_PYTHON_CMD})"
    )
    unset(CONANFILE_VENV_PYTHON_CMD CACHE)
  endif()
endfunction()


function(_conanfile_setup)

  if (DEFINED CONANFILE_CONAN AND NOT CONANFILE_CONAN MATCHES "^(SYSTEM|AUTO|LOCAL)$")
    message(
      FATAL_ERROR
      "Conanfile: Invalid value for CONANFILE_CONAN: \"${CONANFILE_CONAN}\". Expects SYSTEM, AUTO or LOCAL."
    )
  elseif(CONANFILE_CONAN STREQUAL SYSTEM AND DEFINED CONANFILE_LOCAL_CONAN_HOME)
    message(
      NOTICE
      "Conanfile: CONANFILE_LOCAL_CONAN_HOME is not used when CONANFILE_CONAN is set to SYSTEM."
    )
  endif()

  if(NOT CONANFILE_CONAN STREQUAL "SYSTEM" AND
    DEFINED CONANFILE_LOCAL_CONAN_HOME AND CONANFILE_CONAN_CMD AND
    NOT CONANFILE_CONAN_CMD MATCHES "^(conan|CONAN_HOME=${CONANFILE_LOCAL_CONAN_HOME}.+)"
  )
    message(NOTICE "Conanfile: CONANFILE_LOCAL_CONAN_HOME has changed. Reinstalling conan.")
    unset(CONANFILE_CONAN_CMD CACHE)
  else()
    # We may already be setup - check this first
    _check_conan()
    if(DEFINED CONANFILE_CONAN_CMD)
      # Conan found and valid, no need to do anything
      return()
    endif()
  endif()

  # Conan not found, wrong version or incorrectly installed, (re)install

  # Check that we have a functional virtual environment and python executable
  _check_venv()

  # Figure out default virtual environment path if not user-defined
  if (DEFINED CONANFILE_LOCAL_CONAN_HOME)
    # User-defined conan home
    set(CONAN_HOME "${CONANFILE_LOCAL_CONAN_HOME}")
  else()
    # By default, the conan home is in the project source directory, so that all conan packages
    # for the project can be shared among builds
    set(CONAN_HOME "${PROJECT_SOURCE_DIR}/.conan")
  endif()
  if (NOT EXISTS "${CONAN_HOME}")
    file(MAKE_DIRECTORY "${CONAN_HOME}")
  endif()
  # This will set CONAN_HOME when conan is run
  set(SET_CONAN_HOME "CONAN_HOME=${CONAN_HOME}")

  set(REBUILD_VENV FALSE)
  if (DEFINED CONANFILE_VENV_PYTHON_CMD)
    # Check if conan home has changed since last time, if so, rebuild venv
    if (NOT "${CONANFILE_VENV_PYTHON_CMD}" MATCHES "${CONAN_HOME}/venv/(Scripts/python.exe|bin/python)")
      set(REBUILD_VENV TRUE)
    endif()
  else()
    set(REBUILD_VENV TRUE)
  endif()

  if (REBUILD_VENV)
    # Issue with virtual environment's python, this needs to be reinstalled

    # This is where the virtual environment will be created
    set(VENV_DIR "${CONAN_HOME}/venv")
    # Clear venv directory
    if (EXISTS "${VENV_DIR}")
      file(REMOVE_RECURSE "${VENV_DIR}")
    endif()

    # look for python
    if (DEFINED CONANFILE_PYTHON_EXECUTABLE)
      # User-defined python
      execute_process(COMMAND ${CONANFILE_PYTHON_EXECUTABLE} --version RESULT_VARIABLE CONANFILE_PYTHON_EXECUTABLE_RESULT)
      if (CONANFILE_PYTHON_EXECUTABLE_RESULT GREATER 0)
        message(FATAL_ERROR "Conanfile: Invalid CONANFILE_PYTHON_EXECUTABLE specified: ${CONANFILE_PYTHON_EXECUTABLE}")
      endif()
      set(PYTHON_EXECUTABLE "${CONANFILE_PYTHON_EXECUTABLE}")
    else()
      # do not use find_package as it doesn't work with pyenv
      find_program(PYTHON_EXECUTABLE NAMES python3;python NO_CACHE)
      if(NOT PYTHON_EXECUTABLE)
        message(FATAL_ERROR "Conanfile: No Python executable found. Please install Python or set PATH.")
      elseif(${PYTHON_EXECUTABLE} MATCHES ".*/shims/python.*")
        # this is a python executable provided by pyenv, find actual python executable by executing
        # `pyenv which python`
        find_program(PYENV_EXECUTABLE NAMES pyenv NO_CACHE)
        if(CMAKE_HOST_WIN32) # Used instead of WIN32 for cross-compiling
          find_program(BASH_EXECUTABLE NAMES bash NO_CACHE)
          execute_process(COMMAND "${BASH_EXECUTABLE}" "${PYENV_EXECUTABLE}" which python OUTPUT_VARIABLE PYTHON_EXECUTABLE
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        else()
          execute_process(COMMAND ${PYENV_EXECUTABLE} which python OUTPUT_VARIABLE PYTHON_EXECUTABLE OUTPUT_STRIP_TRAILING_WHITESPACE)
        endif()
      endif()
    endif()

    # now we have a pyton executable to create the virtual environment from
    message(
      STATUS "Conanfile: Creating virtual environment for Conan in ${VENV_DIR}"
    )
    execute_process(
      COMMAND "${PYTHON_EXECUTABLE}" -m venv "${VENV_DIR}"
      RESULT_VARIABLE VENV_CREATE_RESULT
    )
    if(NOT ${VENV_CREATE_RESULT} STREQUAL "0")
      message(FATAL_ERROR
        "Conanfile: Virtual environment creation failed. Return code was '${VENV_CREATE_RESULT}'"
      )
    endif()

    # Sets the virtual environment's scripts directory according to the platform
    if(CMAKE_HOST_WIN32)
      set(PYTHON_REL_PATH Scripts/python.exe)
    else()
      set(PYTHON_REL_PATH bin/python)
    endif()
    set(
      CONANFILE_VENV_PYTHON_CMD "${VENV_DIR}/${PYTHON_REL_PATH}"
      CACHE INTERNAL "Python executable for conanfile"
    )
  endif()

  message(
    STATUS "Conanfile: Using python from ${CONANFILE_VENV_PYTHON_CMD}"
  )

  # Extract pip path from python executable path
  cmake_path(GET CONANFILE_VENV_PYTHON_CMD PARENT_PATH VENV_BIN_DIR)
  cmake_path(GET VENV_BIN_DIR PARENT_PATH VENV_DIR)

  if (DEFINED CONANFILE_CONAN_VERSION)
    set(PIP_INSTALL_CONAN conan${CONANFILE_CONAN_VERSION})
  else()
    set(PIP_INSTALL_CONAN conan)
  endif()

  # Invoke pip to (re) install conan
  message(
    STATUS
    "Conanfile: Installing ${PIP_INSTALL_CONAN} in ${VENV_DIR} virtual environment."
  )
  execute_process(
    COMMAND ${VENV_BIN_DIR}/pip install ${PIP_INSTALL_CONAN} --force-reinstall
    RESULT_VARIABLE PIP_INSTALL_RESULT
  )
  if(NOT ${PIP_INSTALL_RESULT} STREQUAL "0")
    message(FATAL_ERROR
      "Conanfile: Conan installation failed. Return code was '${PIP_INSTALL_RESULT}'"
    )
  endif()

  find_program(CONAN_CMD conan HINTS ${VENV_BIN_DIR} NO_DEFAULT_PATH NO_CACHE)
  set(CONANFILE_CONAN_CMD "${SET_CONAN_HOME};${CONAN_CMD}" CACHE INTERNAL "Conan executable for conanfile module")

  # check that it's all good
  _check_conan()

  if(NOT DEFINED CONANFILE_CONAN_CMD)
    message(FATAL_ERROR "Conanfile: Conan installation failed. Please look at the CMake log to investigate.")
  endif()

endfunction()

# Run _conanfile_setup to have a valid conan in CONANFILE_CONAN_CMD
_conanfile_setup()


# Copied from cmake-conan 1.0 (https://github.com/conan-io/cmake-conan/)
function(_conanfile_detect_unix_libcxx result)
  # Take into account any -stdlib in compile options
  get_directory_property(compile_options DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} COMPILE_OPTIONS)
  string(GENEX_STRIP "${compile_options}" compile_options)

  # Take into account any _GLIBCXX_USE_CXX11_ABI in compile definitions
  get_directory_property(defines DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} COMPILE_DEFINITIONS)
  string(GENEX_STRIP "${defines}" defines)

  foreach(define ${defines})
    if(define MATCHES "_GLIBCXX_USE_CXX11_ABI")
      if(define MATCHES "^-D")
        set(compile_options ${compile_options} "${define}")
      else()
        set(compile_options ${compile_options} "-D${define}")
      endif()
    endif()
  endforeach()

  # add additional compiler options ala cmRulePlaceholderExpander::ExpandRuleVariable
  set(EXPAND_CXX_COMPILER ${CMAKE_CXX_COMPILER})
  if(CMAKE_CXX_COMPILER_ARG1)
    # CMake splits CXX="foo bar baz" into CMAKE_CXX_COMPILER="foo", CMAKE_CXX_COMPILER_ARG1="bar baz"
    # without this, ccache, winegcc, or other wrappers might lose all their arguments
    separate_arguments(SPLIT_CXX_COMPILER_ARG1 NATIVE_COMMAND ${CMAKE_CXX_COMPILER_ARG1})
    list(APPEND EXPAND_CXX_COMPILER ${SPLIT_CXX_COMPILER_ARG1})
  endif()

  if(CMAKE_CXX_COMPILE_OPTIONS_TARGET AND CMAKE_CXX_COMPILER_TARGET)
    # without --target= we may be calling the wrong underlying GCC
    list(APPEND EXPAND_CXX_COMPILER "${CMAKE_CXX_COMPILE_OPTIONS_TARGET}${CMAKE_CXX_COMPILER_TARGET}")
  endif()

  if(CMAKE_CXX_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN AND CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN)
    list(APPEND EXPAND_CXX_COMPILER "${CMAKE_CXX_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN}${CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN}")
  endif()

  if(CMAKE_CXX_COMPILE_OPTIONS_SYSROOT)
    # without --sysroot= we may find the wrong #include <string>
    if(CMAKE_SYSROOT_COMPILE)
      list(APPEND EXPAND_CXX_COMPILER "${CMAKE_CXX_COMPILE_OPTIONS_SYSROOT}${CMAKE_SYSROOT_COMPILE}")
    elseif(CMAKE_SYSROOT)
      list(APPEND EXPAND_CXX_COMPILER "${CMAKE_CXX_COMPILE_OPTIONS_SYSROOT}${CMAKE_SYSROOT}")
    endif()
  endif()

  separate_arguments(SPLIT_CXX_FLAGS NATIVE_COMMAND ${CMAKE_CXX_FLAGS})

  if(CMAKE_OSX_SYSROOT)
    set(xcode_sysroot_option "--sysroot=${CMAKE_OSX_SYSROOT}")
  endif()

  execute_process(
    COMMAND ${CMAKE_COMMAND} -E echo "#include <string>"
    COMMAND ${EXPAND_CXX_COMPILER} ${SPLIT_CXX_FLAGS} -x c++ ${xcode_sysroot_option} ${compile_options} -E -dM -
    OUTPUT_VARIABLE string_defines
  )

  if(string_defines MATCHES "#define __GLIBCXX__")
    # Allow -D_GLIBCXX_USE_CXX11_ABI=ON/OFF as argument to cmake
    if(DEFINED _GLIBCXX_USE_CXX11_ABI)
      if(_GLIBCXX_USE_CXX11_ABI)
        set(${result} libstdc++11 PARENT_SCOPE)
        return()
      else()
        set(${result} libstdc++ PARENT_SCOPE)
        return()
      endif()
    endif()

    if(string_defines MATCHES "#define _GLIBCXX_USE_CXX11_ABI 1\n")
      set(${result} libstdc++11 PARENT_SCOPE)
    else()
      # Either the compiler is missing the define because it is old, and so
      # it can't use the new abi, or the compiler was configured to use the
      # old abi by the user or distro (e.g. devtoolset on RHEL/CentOS)
      set(${result} libstdc++ PARENT_SCOPE)
    endif()
  else()
    set(${result} libc++ PARENT_SCOPE)
  endif()
endfunction()


function(_conanfile_detect_arch ARCH)
  if (${ARCH})
    return()
  endif()

  if(CMAKE_C_COMPILER)
    execute_process(COMMAND ${CMAKE_C_COMPILER} -dumpmachine OUTPUT_VARIABLE DETECTED_ARCH)
  elseif(CMAKE_CXX_COMPILER)
    execute_process(COMMAND ${CMAKE_CXX_COMPILER} -dumpmachine OUTPUT_VARIABLE DETECTED_ARCH)
  else()
    message(FATAL_ERROR "Conanfile: No CMAKE_C(XX)_COMPILER available to detect architecture")
  endif()

  string(REPLACE "-" ";" DETECTED_ARCH ${DETECTED_ARCH})

  list(GET DETECTED_ARCH 0 DETECTED_ARCH)
  if (${DETECTED_ARCH} STREQUAL "aarch64")
    set(DETECTED_ARCH armv8)
  endif()

  set(${ARCH} ${DETECTED_ARCH} PARENT_SCOPE)
endfunction()


# Largely inspired from cmake-conan 1.0 implementation (https://github.com/conan-io/cmake-conan/)
function(_conanfile_detect_host_settings DETECTED_SETTINGS)

  cmake_parse_arguments(ARGS "" "ARCH" "" ${ARGN})

  # Architecture, if provided
  if(ARGS_ARCH)
    set(CONAN_ARCH ${ARGS_ARCH})
  endif()


  # System name. Inherit from CMake and transform for conan
  set(SYSTEM_NAME ${CMAKE_${TYPE_PREFIX}SYSTEM_NAME})
  if(SYSTEM_NAME AND NOT SYSTEM_NAME STREQUAL "Generic")
    # if SYSTEM_NAME is not defined, use default conan os setting
    set(CONAN_SYSTEM_NAME ${SYSTEM_NAME})
    if(${SYSTEM_NAME} STREQUAL "Darwin")
      set(CONAN_SYSTEM_NAME Macos)
    endif()
    if(${SYSTEM_NAME} STREQUAL "QNX")
      set(CONAN_SYSTEM_NAME Neutrino)
    endif()
    set(CONAN_SUPPORTED_PLATFORMS Windows Linux Macos Android iOS FreeBSD WindowsStore WindowsCE watchOS tvOS FreeBSD SunOS AIX Arduino Emscripten Neutrino)
    list (FIND CONAN_SUPPORTED_PLATFORMS "${CONAN_SYSTEM_NAME}" _index)
    # check if the cmake system is a conan supported one
    if (${_index} GREATER -1)
      set(CONAN_OS ${CONAN_SYSTEM_NAME})
    else()
      message(FATAL_ERROR "Conanfile: cmake system ${CONAN_SYSTEM_NAME} is not supported by conan. Use one of ${CONAN_SUPPORTED_PLATFORMS}")
    endif()
  endif()

  # Language
  get_property(LANGUAGES GLOBAL PROPERTY ENABLED_LANGUAGES)
  if (";${LANGUAGES};" MATCHES ";CXX;")
    set(LANGUAGE CXX)
    set(USING_CXX 1)
  elseif (";${LANGUAGES};" MATCHES ";C;")
    set(LANGUAGE C)
    set(USING_CXX 0)
  else ()
    message(FATAL_ERROR "Conanfile: Neither C or C++ was detected as a language for the project. Unable to detect compiler version.")
  endif()

  # Build type
  if(CMAKE_BUILD_TYPE)
    set(CONAN_BUILD_TYPE ${CMAKE_BUILD_TYPE})
  else()
    message(FATAL_ERROR "Conanfile: CMAKE_BUILD_TYPE not specified. Use -DCMAKE_BUILD_TYPE=... cmake argument")
  endif()

  # Compiler
  if(USING_CXX)
    set(CONAN_COMPILER_CPPSTD ${CMAKE_CXX_STANDARD})
  endif()

  if (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL GNU OR ${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL QCC)
    # using GCC or QCC
    string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
    list(GET VERSION_LIST 0 MAJOR)
    list(GET VERSION_LIST 1 MINOR)

    if (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL GNU)
      set(CONAN_COMPILER gcc)
      # mimic Conan client autodetection
      if (${MAJOR} GREATER_EQUAL 5)
        set(COMPILER_VERSION ${MAJOR})
      else()
        set(COMPILER_VERSION ${MAJOR}.${MINOR})
      endif()
    elseif (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL QCC)
      set(CONAN_COMPILER qcc)
      set(COMPILER_VERSION ${MAJOR}.${MINOR})
    endif ()

    set(CONAN_COMPILER_VERSION ${COMPILER_VERSION})

    if (USING_CXX)
      _conanfile_detect_unix_libcxx(_LIBCXX)
      set(CONAN_COMPILER_LIBCXX ${_LIBCXX})
    endif ()
    _conanfile_detect_arch(CONAN_ARCH)
  elseif (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL Intel)
    string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
    list(GET VERSION_LIST 0 MAJOR)
    list(GET VERSION_LIST 1 MINOR)
    set(COMPILER_VERSION ${MAJOR})
    set(CONAN_COMPILER intel)
    set(CONAN_COMPILER_VERSION ${COMPILER_VERSION})
    if (USING_CXX)
      _conanfile_detect_unix_libcxx(_LIBCXX)
      set(CONAN_COMPILER_LIBCXX ${_LIBCXX})
    endif ()
  elseif (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL AppleClang)
    # using AppleClang
    string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
    list(GET VERSION_LIST 0 MAJOR)
    list(GET VERSION_LIST 1 MINOR)

    # mimic Conan client autodetection
    if (${MAJOR} GREATER_EQUAL 13)
      set(COMPILER_VERSION ${MAJOR})
    else()
      set(COMPILER_VERSION ${MAJOR}.${MINOR})
    endif()

    set(CONAN_COMPILER_VERSION ${COMPILER_VERSION})

    set(CONAN_COMPILER apple-clang)
    if (USING_CXX)
      _conanfile_detect_unix_libcxx(_LIBCXX)
      set(CONAN_COMPILER_LIBCXX ${_LIBCXX})
    endif ()
  elseif (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL Clang
    AND NOT "${CMAKE_${LANGUAGE}_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC"
    AND NOT "${CMAKE_${LANGUAGE}_SIMULATE_ID}" STREQUAL "MSVC")

    if(NOT CONAN_ARCH AND EMSCRIPTEN)
      set(CONAN_ARCH asm.js)
    endif()

    string(REPLACE "." ";" VERSION_LIST ${CMAKE_${LANGUAGE}_COMPILER_VERSION})
    list(GET VERSION_LIST 0 MAJOR)
    list(GET VERSION_LIST 1 MINOR)
    set(CONAN_COMPILER clang)

    # mimic Conan client autodetection
    if (${MAJOR} GREATER_EQUAL 8)
      set(COMPILER_VERSION ${MAJOR})
    else()
      set(COMPILER_VERSION ${MAJOR}.${MINOR})
    endif()

    set(CONAN_COMPILER_VERSION ${COMPILER_VERSION})

    if(APPLE)
      cmake_policy(GET CMP0025 APPLE_CLANG_POLICY)
      if(NOT APPLE_CLANG_POLICY STREQUAL NEW)
        message(STATUS "Conanfile: APPLE and Clang detected. Assuming apple-clang compiler. Set CMP0025 to avoid it")
        set(CONAN_COMPILER apple-clang)
      endif()
    endif()
    if (USING_CXX)
      _conanfile_detect_unix_libcxx(_LIBCXX)
      set(CONAN_COMPILER_LIBCXX ${_LIBCXX})
    endif ()
    _conanfile_detect_arch(CONAN_ARCH)
  elseif(${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL MSVC
    OR (${CMAKE_${LANGUAGE}_COMPILER_ID} STREQUAL Clang
    AND "${CMAKE_${LANGUAGE}_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC"
    AND "${CMAKE_${LANGUAGE}_SIMULATE_ID}" STREQUAL "MSVC"))

    set(CONAN_COMPILER "msvc")
    # Find MSVC version by trimming the last digit
    string(SUBSTRING ${MSVC_VERSION} 0 3 CONAN_COMPILER_VERSION)

    if(NOT CONAN_ARCH)
      if (MSVC_${LANGUAGE}_ARCHITECTURE_ID MATCHES "64")
        set(CONAN_ARCH x86_64)
      elseif (MSVC_${LANGUAGE}_ARCHITECTURE_ID MATCHES "^ARM")
        message(STATUS "Conanfile: Using default ARM architecture from MSVC")
        set(CONAN_ARCH armv6)
      elseif (MSVC_${LANGUAGE}_ARCHITECTURE_ID MATCHES "86")
        set(CONAN_ARCH x86)
      else ()
        message(FATAL_ERROR "Conanfile: Unknown MSVC architecture [${MSVC_${LANGUAGE}_ARCHITECTURE_ID}]")
      endif()
    endif()

    # Detect VS runtime
    # Build type. Inherit from CMake
    string(TOUPPER "${CONAN_BUILD_TYPE}" CONAN_BUILD_TYPE_UPPER)
    set(VARIABLES CMAKE_CXX_FLAGS_${CONAN_BUILD_TYPE_UPPER} CMAKE_C_FLAGS_${CONAN_BUILD_TYPE_UPPER} CMAKE_CXX_FLAGS CMAKE_C_FLAGS)
    foreach(VARIABLE ${VARIABLES})
      if(NOT "${${VARIABLE}}" STREQUAL "")
        string(REPLACE " " ";" flags "${${VARIABLE}}")
        foreach (flag ${flags})
          if("${flag}" STREQUAL "/MD" OR "${flag}" STREQUAL "/MDd" OR "${flag}" STREQUAL "/MT" OR "${flag}" STREQUAL "/MTd")
            string(SUBSTRING "${flag}" 1 -1 VS_RUNTIME)
            if (${VS_RUNTIME} STREQUAL "MD")
              set(${VS_RUNTIME} "dynamic")
            elseif (${VS_RUNTIME} STREQUAL "MT")
              set(${VS_RUNTIME} "static")
            endif()
            break()
          endif()
        endforeach()
        if (DEFINED VS_RUNTIME)
          break()
        endif()
      endif()
    endforeach()
    if (NOT DEFINED VS_RUNTIME)
      # If VS runtime cannot be extracted from the flags, we use the default 'dynamic'
      # see https://cmake.org/cmake/help/latest/prop_tgt/MSVC_RUNTIME_LIBRARY.html
      set(VS_RUNTIME "dynamic")
    endif()

    message(STATUS "Conanfile: Detected VS runtime: ${VS_RUNTIME}")
    set(CONAN_COMPILER_RUNTIME ${VS_RUNTIME})

    if (CMAKE_GENERATOR_TOOLSET)
      set(CONAN_COMPILER_TOOLSET ${CMAKE_VS_PLATFORM_TOOLSET})
    elseif(CMAKE_VS_PLATFORM_TOOLSET AND (CMAKE_GENERATOR STREQUAL "Ninja"))
      set(CONAN_COMPILER_TOOLSET ${CMAKE_VS_PLATFORM_TOOLSET})
    endif()
  else()
    message(FATAL_ERROR "Conanfile: Compiler setup not recognized")
  endif()

  set(ARGUMENTS_PROFILE_AUTO arch build_type compiler compiler.version
    compiler.runtime compiler.libcxx compiler.toolset
    compiler.cppstd os)
  foreach(ARG ${ARGUMENTS_PROFILE_AUTO})
    string(TOUPPER ${ARG} _arg_name)
    string(REPLACE "." "_" _arg_name ${_arg_name})
    if(CONAN_${_arg_name})
      set(SETTINGS ${SETTINGS} ${ARG}=${CONAN_${_arg_name}})
    endif()
  endforeach()
  set(${DETECTED_SETTINGS} ${SETTINGS} PARENT_SCOPE)

endfunction()


# Uses `conan profile detect` to detect build settings - used for cross-compiling
function(_conanfile_detect_build_settings DETECTED_SETTINGS)

  string(SHA256 PROFILE_HASH ${CMAKE_CURRENT_BINARY_DIR})
  set(PROFILE_NAME cmake-conanfile_detect_${PROFILE_HASH})
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env ${CONANFILE_CONAN_CMD} profile detect --name ${PROFILE_NAME} --force
    RESULT_VARIABLE PROFILE_DETECT_RESULT
    OUTPUT_VARIABLE PROFILE_DETECT_OUTPUT ECHO_OUTPUT_VARIABLE
    ERROR_VARIABLE PROFILE_DETECT_ERROR
  )
  if (NOT ${PROFILE_DETECT_RESULT} STREQUAL "0")
    message(FATAL_ERROR
      "Conanfile: Conan profile detection failed. Return code was '${PROFILE_DETECT_RESULT}':\n"
      "${PROFILE_DETECT_ERROR}\n\n"
      "Command output: ${PROFILE_DETECT_OUTPUT}"
    )
  endif()

  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env ${CONANFILE_CONAN_CMD} profile path ${PROFILE_NAME}
    RESULT_VARIABLE PROFILE_PATH_RESULT
    OUTPUT_VARIABLE PROFILE_PATH_OUTPUT
    ERROR_VARIABLE PROFILE_PATH_ERROR
  )
  if (NOT ${PROFILE_PATH_RESULT} STREQUAL "0")
    message(FATAL_ERROR
      "Conanfile: Conan profile path retrieval failed. Return code was '${PROFILE_PATH_RESULT}':\n"
      "${PROFILE_PATH_ERROR}\n\n"
      "Command output: ${PROFILE_PATH_OUTPUT}"
    )
  endif()


  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env ${CONANFILE_CONAN_CMD} profile show -f json -pr:b ${PROFILE_NAME} -pr:h ${PROFILE_NAME}
    RESULT_VARIABLE PROFILE_JSON_RESULT
    OUTPUT_VARIABLE PROFILE_JSON
    ERROR_VARIABLE PROFILE_JSON_ERROR
  )
  string(STRIP "${PROFILE_PATH_OUTPUT}" PROFILE_PATH_OUTPUT)
  file(REMOVE "${PROFILE_PATH_OUTPUT}")
  if (NOT ${PROFILE_JSON_RESULT} STREQUAL "0")
    message(FATAL_ERROR
      "Conanfile: Conan profile path retrieval failed. Return code was '${PROFILE_JSON_RESULT}':\n"
      "${PROFILE_JSON_ERROR}\n\n"
      "Full output: ${PROFILE_JSON}"
    )
  endif()

  string(JSON SETTINGS_JSON GET ${PROFILE_JSON} "build" "settings")
  string(JSON N_SETTINGS LENGTH ${SETTINGS_JSON})
  math(EXPR N_SETTINGS "${N_SETTINGS}-1")

  foreach(I RANGE ${N_SETTINGS})
    string(JSON SETTING MEMBER ${SETTINGS_JSON} ${I})
    string(JSON VALUE GET ${SETTINGS_JSON} ${SETTING})
    set(SETTINGS ${SETTINGS} ${SETTING}=${VALUE})
  endforeach()

  set(${DETECTED_SETTINGS} ${SETTINGS} PARENT_SCOPE)
endfunction()

# This is called by the conanfile() macro below, so that internal variables don't pollute the
# cmake cache and global namespace
function(_conanfile)

  cmake_parse_arguments(ARGS "" "CONANFILE" "SETTINGS;OPTIONS" ${ARGN})

  set(CONANFILE_TEMPLATE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${ARGS_CONANFILE}")
  set(CONANFILE_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_CONANFILE}")
  set(CONANFILE_OUTPUT_PATH "${CONANFILE_OUTPUT_DIR}/conanfile.py")

  # Also watch source conanfile
  set_property(
    DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CONANFILE_TEMPLATE_FILE}
  )

  message(
    STATUS
    "Conanfile: Generating ${CONANFILE_OUTPUT_PATH} from ${CONANFILE_TEMPLATE_FILE}"
  )

  # insert CMAKE_OPTIONS modification code in conanfile
  file(READ "${CONANFILE_TEMPLATE_FILE}" CONANFILE_TEMPLATE)

  # replace ; by , in arguments list
  string(REPLACE ";" ",\\n    " CMAKE_OPTIONS "${ARGS_OPTIONS}")

  # inject CMake options to update python variable, if present and defined
  string(REGEX REPLACE
    "(CMAKE_OPTIONS *= * \\{[^\\}]*\\})"
    "\\1\\n\\n# CMake injection start\\nCMAKE_OPTIONS.update(dict(\\n    ${CMAKE_OPTIONS}\\n))\\n# CMake injection end"
    CONANFILE_OUTPUT "${CONANFILE_TEMPLATE}"
  )

  # write output conan file to disk
  file(WRITE "${CONANFILE_OUTPUT_PATH}" "${CONANFILE_OUTPUT}")

  # auto detect host settings
  _conanfile_detect_host_settings(CONANFILE_HOST_SETTINGS)

  # make sure CMAKE_GENERATOR is propagated to the conan host config
  list(APPEND CONANFILE_HOST_CONF "tools.cmake.cmaketoolchain:generator=${CMAKE_GENERATOR}")

  # handle different build and host settings, environment and configuration when cross-compiling
  if (CMAKE_CROSSCOMPILING)
    # This uses `conan profile detect` to get the build environment's default settings
    _conanfile_detect_build_settings(CONANFILE_BUILD_SETTINGS)
    if (CMAKE_TOOLCHAIN_FILE)
      # propagate toolchain file to configuration and host environment
      string(REPLACE "\\" "/" CMAKE_TOOLCHAIN_FILE ${CMAKE_TOOLCHAIN_FILE})
      list(APPEND CONANFILE_HOST_CONF tools.cmake.cmaketoolchain:user_toolchain=["${CMAKE_TOOLCHAIN_FILE}"])
      list(APPEND CONANFILE_HOST_ENV CONAN_CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
    endif()
    if (CMAKE_SYSTEM_PROCESSOR)
      # propagate architecture information to host environment
      list(APPEND CONANFILE_HOST_CONF tools.cmake.cmaketoolchain:system_processor=${CMAKE_SYSTEM_PROCESSOR})
      list(APPEND CONANFILE_HOST_ENV CONAN_CMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR})
    endif()
    if (CMAKE_SYSROOT)
      # propagate sys root to host config and environment
      list(APPEND CONANFILE_HOST_CONF tools.build:sysroot=${CMAKE_SYSROOT})
      list(APPEND CONANFILE_HOST_ENV CONAN_CMAKE_SYSROOT=${CMAKE_SYSROOT})
    endif()
  else()
    # When not cross-compiling, the host and build settings are identical
    set(CONANFILE_BUILD_SETTINGS ${CONANFILE_HOST_SETTINGS})
    # also propagate compiler environment variable to build environment (will be added to host
    # environment as well below)
    list(
      APPEND CONANFILE_BUILD_ENV
      CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER} CONAN_DISABLE_CHECK_COMPILER="ON"
    )
  endif()

  # propagate compiler environment variable to host environment
  list(
    APPEND CONANFILE_HOST_ENV
    CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER} CONAN_DISABLE_CHECK_COMPILER="ON"
  )

  # Some application packages do not have del self.info.settings.build_type in package_id.
  # We force the build_type to Release to avoid unoptimised dependencies to be pulled in / built
  list(TRANSFORM CONANFILE_BUILD_SETTINGS REPLACE "build_type=.*" "build_type=Release")

  # use a hash file to check if we need to run conan
  set(CONANFILE_HASH_FILE ${CONANFILE_OUTPUT_DIR}/_hash)
  # TODO: get conan version and add it to hash
  string(SHA256 CONANFILE_HASH
    "${CONANFILE_CONAN_CMD}${CONANFILE_OUTPUT}{CONANFILE_HOST_SETTINGS}${CONANFILE_HOST_ENV}${CONANFILE_BUILD_ENV}${CONANFILE_BUILD_CONF}${CONANFILE_HOST_CONF}"
  )

  # load existing hash
  set(CONANFILE_HASH_EXISTING NONE)
  if (EXISTS ${CONANFILE_HASH_FILE})
    file(READ ${CONANFILE_HASH_FILE} CONANFILE_HASH_EXISTING)
  endif()

  if (NOT ${CONANFILE_HASH_EXISTING} STREQUAL ${CONANFILE_HASH})
    # hashes differ, run conan
    foreach(SECTION BUILD_SETTINGS HOST_SETTINGS BUILD_ENV HOST_ENV BUILD_CONF HOST_CONF)
      string (REPLACE ";" "\n" CONANFILE_${SECTION} "${CONANFILE_${SECTION}}")
    endforeach()

    # Generate profiles (build and host)
    set(CONANFILE_BUILD_PROFILE ${CONANFILE_OUTPUT_DIR}/conanfile.profile.build)
    file(CONFIGURE OUTPUT ${CONANFILE_BUILD_PROFILE} CONTENT "
[settings]
@CONANFILE_BUILD_SETTINGS@

[runenv]
@CONANFILE_BUILD_ENV@

[buildenv]
@CONANFILE_BUILD_ENV@

[conf]
@CONANFILE_BUILD_CONF@
")

    set(CONANFILE_HOST_PROFILE ${CONANFILE_OUTPUT_DIR}/conanfile.profile.host)
    # We need to duplicate the runenv into buildenv as it otherwise causes cross-compilation issues
    # with boost (see https://github.com/conan-io/conan-center-index/issues/14767)
    file(CONFIGURE OUTPUT ${CONANFILE_HOST_PROFILE} CONTENT "
[settings]
@CONANFILE_HOST_SETTINGS@

[runenv]
@CONANFILE_HOST_ENV@

[buildenv]
@CONANFILE_HOST_ENV@

[conf]
@CONANFILE_HOST_CONF@
")

    # run conan
    set(CONANFILE_INSTALL_ARGS install ${CONANFILE_OUTPUT_PATH} --build missing
      --profile:build ${CONANFILE_BUILD_PROFILE}
      --profile:host ${CONANFILE_HOST_PROFILE}
    )
    string(REPLACE ";" " " CONANFILE_INSTALL_ARGS_STR "${CONANFILE_INSTALL_ARGS}")
    list(GET CONANFILE_CONAN_CMD -1 CONANFILE_CONAN_CMD_FOR_MSG)
    message(STATUS "Conanfile: Running ${CONANFILE_CONAN_CMD_FOR_MSG} ${CONANFILE_INSTALL_ARGS_STR}")

    execute_process(
      COMMAND ${CMAKE_COMMAND} -E env ${CONANFILE_CONAN_CMD} ${CONANFILE_INSTALL_ARGS}
      RESULT_VARIABLE CONANFILE_INSTALL_RESULT
      WORKING_DIRECTORY ${CONANFILE_OUTPUT_DIR}
    )

    if(NOT ${CONANFILE_INSTALL_RESULT} STREQUAL "0")
      message(FATAL_ERROR
        "Conanfile: Conan install failed. Return code was '${CONANFILE_INSTALL_RESULT}'"
      )
    endif()

    # remove all cmake global variable changes from conan_toolchain.cmake - we are only interested in
    # retrieving paths to dependencies
    set(TOOLCHAIN ${CONANFILE_OUTPUT_DIR}/conan_toolchain.cmake)
    set(TOOLCHAIN_PATHS ${CONANFILE_OUTPUT_DIR}/conan_toolchain_paths.cmake)
    message(
      STATUS
      "Conanfile: Extracting conan packages paths from ${TOOLCHAIN} into ${TOOLCHAIN_PATHS}"
    )

    # Only extract find_path and pkg_config blocks from conan toolchain
    file(READ "${TOOLCHAIN}" TOOLCHAIN_STR)

    # REGEX MATCH can't match \n, so replace it with another character that's unlikely to be there,
    # for example ASCII value 27
    string(ASCII 27 EOL)
    string(REGEX REPLACE "(\r\n|\r|\n)" "${EOL}" TOOLCHAIN_STR "${TOOLCHAIN_STR}")

    # extract header with include guard
    string(FIND "${TOOLCHAIN_STR}" "##########" TOOLCHAIN_HEADER_END)
    if(TOOLCHAIN_HEADER_END EQUAL -1)
      message(FATAL_ERROR "Conanfile: Could not find header block in ${TOOLCHAIN}")
    endif()
    string(SUBSTRING "${TOOLCHAIN_STR}" "0" "${TOOLCHAIN_HEADER_END}" TOOLCHAIN_PATHS_STR)

    # extract relevant blocks
    foreach(BLOCK IN ITEMS find_paths pkg_config)
      # CMake doesn't support .*?, so we need to find the start of the block and then manually look
      # for the start of the next one ...
      set(BLOCK_HEADER "########## '${BLOCK}' block #############")
      string(REGEX MATCH "${BLOCK_HEADER}.*" TOOLCHAIN_${BLOCK}_BLOCK "${TOOLCHAIN_STR}")
      if (NOT TOOLCHAIN_${BLOCK}_BLOCK)
        message(FATAL_ERROR "Conanfile: Could not find '${BLOCK}' block in ${TOOLCHAIN}")
      endif()
      string(LENGTH "${BLOCK_HEADER}" BLOCK_HEADER_LENGTH)
      string(SUBSTRING "${TOOLCHAIN_${BLOCK}_BLOCK}" "${BLOCK_HEADER_LENGTH}" -1 TOOLCHAIN_${BLOCK}_BLOCK)
      string(FIND "${TOOLCHAIN_${BLOCK}_BLOCK}" "##########" TOOLCHAIN_${BLOCK}_BLOCK_END)
      string(SUBSTRING "${TOOLCHAIN_${BLOCK}_BLOCK}" "0" "${TOOLCHAIN_${BLOCK}_BLOCK_END}" TOOLCHAIN_${BLOCK}_BLOCK)
      set(TOOLCHAIN_PATHS_STR "${TOOLCHAIN_PATHS_STR}\n${BLOCK_HEADER}${TOOLCHAIN_${BLOCK}_BLOCK}")
    endforeach()

    # write modified toolchain file to disk
    string(REGEX REPLACE "${EOL}" "\n" TOOLCHAIN_PATHS_STR "${TOOLCHAIN_PATHS_STR}")
    file(WRITE "${TOOLCHAIN_PATHS}" "${TOOLCHAIN_PATHS_STR}")

    # write hash
    file(WRITE ${CONANFILE_HASH_FILE} ${CONANFILE_HASH})
  endif()

endfunction()


# Executes conan - that's the main entry point to the module
# This has to be a macro so that include() works and CMAKE_PREFIX_PATH can be amended
macro(conanfile)

  cmake_parse_arguments(ARGS "" "CONANFILE" "" ${ARGN})

  # set CONANFILE to conanfile.py by default
  if (NOT ARGS_CONANFILE)
    set(ARGS_CONANFILE "conanfile.py")
  endif()

  _conanfile(CONANFILE ${ARGS_CONANFILE} ${ARGS_UNPARSED_ARGUMENTS})

  # include resulting toolchain file after adding conan directory to CMAKE_PREFIX_PATH
  set(CONANFILE_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARGS_CONANFILE}")
  list(PREPEND CMAKE_PREFIX_PATH ${CONANFILE_OUTPUT_DIR})
  include(${CONANFILE_OUTPUT_DIR}/conan_toolchain_paths.cmake)

endmacro()
