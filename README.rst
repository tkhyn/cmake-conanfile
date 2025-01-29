cmake-conanfile
###############

A CMake wrapper for `Conan 2 <https://conan.io/>`_. Allows installing, configuring and
running Conan from CMake.


What it does
============

The main task of ``cmake-conanfile`` is to configure and pass options to Conan from CMake, which
is not possible with the `official CMake dependency provider <https://github.com/conan-io/cmake-conan/>`_.

To make the integration even smoother, ``cmake-conanfile`` does not depend on Conan being
installed on the system, as it will:

- create a Python virtual environment
- install Conan in this virtual environment
- and run Conan from the virtual environment


Requirements
============

``cmake-conanfile`` requires the following software to be present on the host machine:

- obviously, a compatible version of `CMake <https://cmake.org/>`_!, and
- either:

  - a version of Conan compatible with the conan version requirements (if any), or
  - a recent version of `Python 3 <https://www.python.org/>`_, which will be used to create the
    virtual environment. If ``python`` is not in the ``PATH`` or if you need to use a specific
    Python version, this can be done using the ``CONANFILE_PYTHON_EXECUTABLE`` setup
    variable (see below)


Installation
============

Download the `conanfile.cmake <conanfile.cmake>`_ file and add it to your project in a place where
it can be found by CMake's ``include()`` command (you most likely already have a custom modules
path), and simply use:

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

CONANFILE_CONAN_VERSION = ~=2.0
   The version requirement of Conan, `pip-style <https://pip.pypa.io/en/stable/reference/requirement-specifiers/>`_.
   If Conan is installed system-wide and meets the version requirements, it will use it.
   Otherwise the latest available version will be installed in a virtual environment.

CONANFILE_VENV_DIR
   The path to the virtual environment directory that will be created if conan needs to be
   installed. Defaults to `${PROJECT_BINARY_DIR}/conanfile_venv`. All invocations to the main
   `conanfile()` function within the CMake project will use the same virtual environment and conan
   version.

CONANFILE_PYTHON_EXECUTABLE
   Defines the python executable to use to create the virtual environment. Generally passed as a
   cmake command line option such as ``cmake -DCONANFILE_PYTHON_EXECUTABLE=/usr/bin/python3``


Usage
=====

Once the module has been loaded, the only interface is the ``conanfile()`` function.

This function will invoke ``conan`` against a specified conan file (by default it will be
``./conanfile.py``).

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

   Note: This means that it is also possible to run standalone `conan` against that `conanfile.py`. The
   default options will then be used.

conanfile parameters
--------------------

CONANFILE
   The path to the conanfile to run, relative to the current list directory. Defaults to
   ``conanfile.py``

OPTIONS
   A list of options that will be forwarded to the conanfile.py
