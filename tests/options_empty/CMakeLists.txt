cmake_minimum_required(VERSION 3.20)
project(auto_test)

set(CONANFILE_CONAN LOCAL)
set(CONANFILE_LOCAL_CONAN_HOME ${PROJECT_BINARY_DIR}/.conan)

include(../../conanfile.cmake)

conanfile(OPTIONS)
