#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "${SCRIPT_DIR}"

if [[ $* == *--cuda* ]]
then
    export BUILD_CUDA_ENABLED="ON"
else
    export BUILD_CUDA_ENABLED="OFF"
fi

export VCPKG_TARGET_TRIPLET="x64-linux-release"


mkdir -p "${SCRIPT_DIR}/build/vcpkg_binarycache/"

# paths are in the container file system:
export VCPKG_INSTALLATION_ROOT="/vcpkg"
export VCPKG_DEFAULT_BINARY_CACHE="/vcpkg_binarycache/"
export CMAKE_TOOLCHAIN_FILE="${VCPKG_INSTALLATION_ROOT}/scripts/buildsystems/vcpkg.cmake"

# Fix: cibuildhweel cannot interpolate env variables.
export CONFIG_SETTINGS="cmake.define.CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
export CONFIG_SETTINGS="${CONFIG_SETTINGS} cmake.define.VCPKG_TARGET_TRIPLET=${VCPKG_TARGET_TRIPLET}"
export CONFIG_SETTINGS="${CONFIG_SETTINGS} cmake.define.VCPKG_INSTALLED_DIR=/project/build/vcpkg_installed"
export CIBW_CONFIG_SETTINGS_LINUX="${CONFIG_SETTINGS}"

# Remap caching paths to the container
mkdir -p "${SCRIPT_DIR}/build/compiler-cache/"
export CONTAINER_COMPILER_CACHE_DIR="/compiler-cache"
export CIBW_CONTAINER_ENGINE="docker; create_args: -v ${SCRIPT_DIR}/build/compiler-cache:${CONTAINER_COMPILER_CACHE_DIR} -v ${SCRIPT_DIR}/build/vcpkg_binarycache:${VCPKG_DEFAULT_BINARY_CACHE} "
export CCACHE_DIR="${CONTAINER_COMPILER_CACHE_DIR}/ccache"
export CCACHE_BASEDIR="/project"

export CIBW_BUILD="cp3{8,9,10,11,12,13}-manylinux*"

# Make sure environment variables are passed to the container by cibuildwheel
export CIBW_ENVIRONMENT_PASS_LINUX="VCPKG_TARGET_TRIPLET VCPKG_INSTALLATION_ROOT VCPKG_DEFAULT_BINARY_CACHE CMAKE_TOOLCHAIN_FILE VCPKG_BINARY_SOURCES CONTAINER_COMPILER_CACHE_DIR CCACHE_DIR CCACHE_BASEDIR BUILD_CUDA_ENABLED"

# Use a CUDA-enabled manylinux container image
export CIBW_MANYLINUX_X86_64_IMAGE="sameli/manylinux_2_34_x86_64_cuda_12.8"

# Do not bundle CUDA libraries in the wheel
export CIBW_REPAIR_WHEEL_COMMAND="auditwheel repair --exclude libcudart* --exclude libcurand* -w {dest_dir} {wheel}"

# Uncomment the following line to not delete the container after the build. Really helpful for debugging purposes!
#export CIBW_DEBUG_KEEP_CONTAINER=True

rm -rf wheelhouse/
uvx cibuildwheel --platform=linux

if [[ $* == *--upload* ]]
then
    echo "Uploading wheels to PyPI"
    uvx twine upload wheelhouse/*
fi