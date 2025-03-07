from conan import ConanFile
class CMakeConanFileTest(ConanFile):
    name = "cmake_conanfile_test"

    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"
    requires = "zlib/1.3.1@"
