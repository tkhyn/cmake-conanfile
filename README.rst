cmake-conanfile
###############

A CMake wrapper for `Conan 2 <https://conan.io/>`_. Allows installing, configuring and
running Conan 2 from CMake.


What it does
============

The main purpose of ``cmake-conanfile`` is to configure and pass options to Conan 2 from CMake,
which is not possible with the `official CMake dependency provider <https://github.com/conan-io/cmake-conan/>`_.

To make the integration even smoother, ``cmake-conanfile`` can work without Conan being installed
on the system at all. If Conan is not found on the system (or if the installed Conan does not
match a minimum version), it can:

- create a dedicated Python virtual environment
- install Conan in this virtual environment
- set the ``CONAN_HOME`` environment variable to a project-specific folder so that dependencies can
  be shared between builds
- and run the Conan executable from the virtual environment

By default, the virtual environment and the local conan home folder will be located in the
``${CMAKE_PROJECT_DIR}/.conan`` directory. If this ends up being the case, you will probably want
to ignore this folder in your version control software. This directory can be customised using the
``CONANFILE_LOCAL_CONAN_HOME`` variable.

Requirements
============

``cmake-conanfile`` requires the following software to be present on the host machine:

- obviously, a compatible version of `CMake <https://cmake.org/>`_ (≥ 3.20), and
- either:

  - a version of Conan that satisfies the conan version requirements (if any), or
  - a recent version of `Python 3 <https://www.python.org/>`_, which will be used to create the
    virtual environment. If neither ``python3`` nor ``python`` are in the ``PATH`` or if you need
    to use a specific Python binary, this can be done using the ``CONANFILE_PYTHON_EXECUTABLE``
    setup variable (see below)

Installation
============

Download the `conanfile.cmake <conanfile.cmake>`_ file and add it to your project in a place where
it can be found by CMake's ``include()`` command (you most likely already have a custom modules
directory), and simply use:

.. code-block:: cmake

   include(conanfile)

Alternatively, the file can be downloaded directly from this repository using the following code:

.. code-block:: cmake

   # Download conanfile.cmake if needed
   set(CMAKE_CONANFILE_VERSION 0.1a NO_CACHE)
   set(CMAKE_CONANFILE_PATH "${PROJECT_BINARY_DIR}/conanfile_${CMAKE_CONANFILE_VERSION}.cmake")
   if(NOT EXISTS "${CMAKE_CONANFILE_PATH}")
     message(STATUS "Downloading conanfile.cmake from https://github.com/tkhyn/cmake-conanfile")
     file(
       DOWNLOAD
       "https://raw.githubusercontent.com/tkhyn/cmake-conanfile/${CMAKE_CONANFILE_VERSION}/conanfile.cmake"
       "${CMAKE_CONANFILE_PATH}"
       TLS_VERIFY ON
     )
   endif()
   include("${CMAKE_CONANFILE_PATH}")


Setup
=====

The behaviour of ``cmake-conanfile`` can be customised using optional cmake variables, that must be
defined before the call to ``include(conanfile)``.

CONANFILE_CONAN
   Can be ``LOCAL``, ``AUTO`` (default) or ``SYSTEM``:

   - If set to ``LOCAL``, ``cmake-conanfile`` will not consider any system-wide Conan installation
     and install a local conan and local conan packages (re-used for all builds, but not shared
     with other projects in the system)
   - If set to ``AUTO``, ``cmake-conanfile`` will try to find a system-wide Conan installation
     and will use it if it satisfies the version requirements. If not, it will install a local
     conan and local packages as if ``LOCAL`` was selected.
   - If set to ``SYSTEM``, ``cmake-conanfile`` will try to find a system-wide Conan installation
     and throw an error if it can't or if the installed version doesn't match the version
     requirements.

CONANFILE_CONAN_VERSION = ~=2.0
   The version requirement of Conan, `pip-style <https://pip.pypa.io/en/stable/reference/requirement-specifiers/>`_.
   Combined with ``CONANFILE_CONAN`` to determine if a local conan needs to be installed.

CONANFILE_LOCAL_CONAN_HOME
   The path to the directory that will contain the virtual environment and the local conan home,
   if a local conan gets installed (which depends on ``CONANFILE_CONAN_VERSION`` and
   ``CONANFILE_CONAN``). All invocations to the main `conanfile()` function within the
   scope of the CMake project will use the same virtual environment, conan version and conan home
   folder. Defaults to ``${PROJECT_SOURCE_DIR}/.conan``.

.. warning::
   If multiple OSes use the same working tree (for example building from WSL on Windows),
   `CONANFILE_LOCAL_CONAN_HOME` should be OS-dependent, as the conan configuration and virtual
   environments cannot be shared. You may for example have:

   ```cmake
   set(CONANFILE_LOCAL_CONAN_HOME "${PROJECT_SOURCE_DIR}/.conan/${CMAKE_SYSTEM_NAME}")
   ```

CONANFILE_PYTHON_EXECUTABLE
   Defines the python executable to use to create the virtual environment. Generally passed as a
   cmake command line option such as ``cmake -DCONANFILE_PYTHON_EXECUTABLE=/usr/bin/python3``


Usage
=====

Once the module has been loaded, the only interface is the ``conanfile()`` function.

This function will invoke ``conan`` against a specified conan file (by default the ``conanfile.py``
in the current source directory).

.. code-block:: cmake

   # Run conan against conanfile.py
   conanfile()

   # Run conan against conanfile_alt.py
   conanfile(CONANFILE conanfile_alt.py)

If some `OPTIONS` are passed, and if a `CMAKE_OPTIONS` dictionary has been initialised in
`conanfile.py` as below, then the options are forwarded to `conanfile.py`, which allows for
example installing optional dependencies only if specific conditions or internal CMake options
are set.

.. code-block:: cmake

   # Run conan against conanfile.py, with options
   set(MY_CONANFILE_OPTIONS "ENABLE_MY_OPTION=True")
   conanfile(OPTIONS ${MY_CONANFILE_OPTIONS})

.. code-block:: python

   from conan import ConanFile

   CMAKE_OPTIONS = {
     "ENABLE_MY_OPTION": False
   }

   class MyConanFile(ConanFile):
     def requirements(self):
       if CMAKE_OPTIONS["ENABLE_MY_OPTION"]:
           self.requires("my_optional_depenceny/0.0.1@user/channel")

.. note::

   Thanks to the unobtrusive way ``cmake-conanfile`` deals with forwarding CMake options to
   conan, it is also possible to run standalone `conan` against that `conanfile.py`.
   The default options will then be used.

``conanfile()`` function parameters
-----------------------------------

CONANFILE
   The path to the conanfile to run, relative to the current list directory. Defaults to
   ``conanfile.py``

OPTIONS
   A list of options ``key=value`` (``value`` must be understandable by python) that will be
   forwarded to the conanfile.py


Troubleshooting
===============

``cmake-conanfile`` tries to avoid re-creating its virtual environment and running ``conan
install`` when it's not needed to save time. However, some system changes (e.g. deletion of a conan
package previously installed and required) can break things.

A heavy handed way to resolve this is to wipe the build folder and start clean. This will work,
but for large codebases this can be fairly expensive.

Problems with the ``conan`` command
-----------------------------------

This can happen if conan has been installed, uninstalled, or reinstalled on the system or if the
local virtual environment has been corrupted.

First, try to remove the value ``CONANFILE_CONAN_CMD`` from the CMake cache (in CMakeCache.txt)
and re-run CMake.

If this doesn't work and a local conan home / virtual environment are used (see
``CONANFILE_CONAN`` variable), delete the ``${CONANFILE_LOCAL_CONAN_HOME}/venv`` directory and
re-run CMake. This will re-create the virtual environment

Problems with ``conan install``
-------------------------------

On a few rare occasions, the conan installation itself will fail. Although there is a
mechanism in place to ensure that it re-runs fully and cleanly when needed, sometimes it cannot
detect that something else has changed on the host system. The most common causes include bugs
in recipes or deletion of packages in the system conan repository.

To force re-running a specific ``conan install``, navigate to the relevant binary directory in the
build folder - the one corresponding to the ``CMakeLists.txt`` - and find the folder that is named
after the conanfile that ``conan install`` has run against (it will generally be ``conanfile.py``
unless you have used the ``CONANFILE`` argument of the ``conanfile()`` function). Delete the
``_hash`` file in that conanfile folder and rerun cmake.

Other problems
--------------

Please report any problem, with steps to reproduce it at
https://github.com/tkhyn/cmake-conanfile/issues

And even better, solve it and create a pull request! If you do so, please use the
`Conventional Commits <https://www.conventionalcommits.org/en/v1.0.0/#specification>`_ format for
your commit messages, with the following base types:

- **fix**: bug fix
- **feat**: new feature
- **enh**: enhancement of an existing feature
- **perf**: code change that improves performance
- **refactor**: code change that neither fixes a bug or adds a feature (clean-ups, warning fixes ...)
- **style**: code changes that do not affect the meaning of the code (white-space, formatting,
  missing semi-colons ...)
- **doc**: Documentation only changes
- **test**: Adding / changing / fixing tests
- **chore**: Anything else (general maintenance, build process, auxiliary tools / libraries ...)
