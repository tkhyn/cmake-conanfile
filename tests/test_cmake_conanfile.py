import os
import logging
import re
import shutil
import subprocess

from functools import partial
from pathlib import Path

import pytest


# Runs a command in shell
run = partial(subprocess.run, shell=True)

@pytest.fixture(scope="session", autouse=True)
def setup_conan_home(tmp_path_factory):
    """Creates a temporary conan home for testing and sets CONAN_HOME"""
    conan_home = tmp_path_factory.mktemp("conan_home")
    old_env = dict(os.environ)
    os.environ.update({"CONAN_HOME": conan_home.as_posix()})
    logging.info(f"CONAN_HOME set to: {conan_home}")
    yield conan_home
    os.environ.clear()
    os.environ.update(old_env)
    shutil.rmtree(conan_home)

@pytest.fixture(scope="session", autouse=True)
def check_system_conan():
    cp = run(f"conan --version", stdout=subprocess.PIPE)

    if (cp.returncode != 0):
        raise SystemError("No system conan found. Please install conan on your system.")

    m = re.match("Conan version (\d)\.\d+\.\d+", cp.stdout.decode("utf-8"))
    if m is None:
        raise SystemError(
            "Could not extract system conan version. Please (re)install conan on your system."
        )

    if int(m[1]) < 2:
        raise SystemError("System conan version too old. Please install conan 2 on your system.")


class TestBase:

    binary_dir = None

    @pytest.fixture(scope="class", autouse=True)
    def setup_workdir(self, tmp_path_factory):
        cls = self.__class__
        cls.binary_dir = tmp_path_factory.mktemp(cls.__name__)
        cwd = os.getcwd()
        os.chdir(cls.binary_dir.as_posix())
        yield
        os.chdir(cwd)
        shutil.rmtree(cls.binary_dir)


class TestAuto(TestBase):

    source_dir = Path(__file__).parent / "auto"

    def test_auto_system(self, capfd):
        run(f"cmake -S {self.source_dir} -DCMAKE_BUILD_TYPE=Release")
        out, err = capfd.readouterr()

        print(out)
        print(err)

        assert all(expected in out for expected in [
            "Conanfile: Using system conan",
            "Conanfile: Running conan install"
        ])

        conan_toolchain_paths_path = Path("conanfile.py") / ("conan_toolchain_paths.cmake")
        conan_home = Path(os.environ["CONAN_HOME"])
        logging.info(f"CWD = {os.getcwd()}")
        assert conan_toolchain_paths_path.exists()
        with open(conan_toolchain_paths_path, "r") as f:
             conan_toolchain_paths = f.read()
             m = re.search(
                 "list\(PREPEND CMAKE_LIBRARY_PATH \"(.*)\/p\/zlib[0-9a-f]+\/p\/lib\"\)",
                 conan_toolchain_paths, re.MULTILINE
             )
             assert m
             assert Path(m[1]) == conan_home

class TestLocal(TestBase):
    source_dir = Path(__file__).parent / "local"

    def test_local(self, capfd):
        run(f"cmake -S {self.source_dir} -DCMAKE_BUILD_TYPE=Release")
        out, err = capfd.readouterr()

        assert all(expected in out for expected in [
            "Conanfile: Creating virtual environment for Conan in",
            "Conanfile: Using python from ",
            "Conanfile: Installing conan in"
        ])

        assert "Conanfile: Local conan not detected with CONANFILE_CONAN set to LOCAL" in err

        conan_toolchain_paths_path = Path("conanfile.py") / ("conan_toolchain_paths.cmake")
        conan_home = Path(os.environ["CONAN_HOME"])
        logging.info(f"CWD = {os.getcwd()}")
        assert conan_toolchain_paths_path.exists()
        with open(conan_toolchain_paths_path, "r") as f:
            conan_toolchain_paths = f.read()
            m = re.search(
                "list\(PREPEND CMAKE_LIBRARY_PATH \"(.*)\/p\/zlib[0-9a-f]+\/p\/lib\"\)",
                conan_toolchain_paths, re.MULTILINE
            )
            assert m
            assert Path(m[1]) == self.binary_dir / ".conan"


class TestSystem(TestBase):

    source_dir = Path(__file__).parent / "system"

    def test_system(self, capfd):
        run(f"cmake -S {self.source_dir} -DCMAKE_BUILD_TYPE=Release")
        out = capfd.readouterr()[0]

        assert all(expected in out for expected in [
            "Conanfile: Using system conan",
            "Conanfile: Running conan install"
        ])

        conan_toolchain_paths_path = Path("conanfile.py") / ("conan_toolchain_paths.cmake")
        conan_home = Path(os.environ["CONAN_HOME"])
        logging.info(f"CWD = {os.getcwd()}")
        assert conan_toolchain_paths_path.exists()
        with open(conan_toolchain_paths_path, "r") as f:
            conan_toolchain_paths = f.read()
            m = re.search(
                "list\(PREPEND CMAKE_LIBRARY_PATH \"(.*)\/p\/zlib[0-9a-f]+\/p\/lib\"\)",
                conan_toolchain_paths, re.MULTILINE
            )
            assert m
            assert Path(m[1]) == conan_home
