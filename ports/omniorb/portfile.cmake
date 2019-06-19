if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
    message(FATAL_ERROR "${PORT} does not currently support UWP")
endif()

if (VCPKG_LIBRARY_LINKAGE STREQUAL static)
  if(NOT VCPKG_CMAKE_SYSTEM_NAME)
    set(DLL_DECORATOR s)
  endif()
  set(MPC_STATIC_FLAG -static)
endif()
include(vcpkg_common_functions)

set(OMNIORB_ROOT ${CURRENT_BUILDTREES_DIR}/src/omniORB-4.2.3)


set(INSTALLED_PATH ${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET})
if(${CMAKE_BUILD_TYPE} MATCHES "^Debug$")
set(INSTALLED_PATH ${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET}/debug)
endif()

set(SSL_ROOT ${INSTALLED_PATH})
set(ENV{SSL_ROOT} ${SSL_ROOT})
set(ENV{ZLIB_ROOT} ${INSTALLED_PATH})

#.\pacman.exe -S diffutils --noconfirm

vcpkg_download_distfile(ARCHIVE
    URLS "https://downloads.sourceforge.net/project/omniorb/omniORB/omniORB-4.2.3/omniORB-4.2.3.tar.bz2"
    FILENAME omniORB-4.2.3.tar.bz2
    SHA512 12cd0eb25cbbc28e42671053a567ede076f33d434f82f605023b35e12a8de77cce7def709ef215653fb93feafd1df49896d6d56f39682e4c81470cfd8cf2f7a0
)
vcpkg_extract_source_archive(${ARCHIVE})

vcpkg_acquire_msys(MSYS_ROOT PACKAGES bash make diffutils)
vcpkg_acquire_msys(MSYS_ROOT)
set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
set(MAKE ${MSYS_ROOT}/usr/bin/make.exe)

# Insert msys into the path between the compiler toolset and windows system32. This prevents masking of "link.exe" but DOES mask "find.exe".
string(REPLACE ";$ENV{SystemRoot}\\system32;" ";${MSYS_ROOT}/usr/bin;$ENV{SystemRoot}\\system32;" NEWPATH "$ENV{PATH}")
string(REPLACE ";$ENV{SystemRoot}\\System32;" ";${MSYS_ROOT}/usr/bin;$ENV{SystemRoot}\\System32;" NEWPATH "${NEWPATH}")
set(ENV{PATH} "${NEWPATH}")


set(PYTHON3 "${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET}/python3/tools/python3/python.exe")
get_filename_component(PYTHON_PATH ${PYTHON3} DIRECTORY)
vcpkg_add_to_path(${PYTHON_PATH})

file(READ ${OMNIORB_ROOT}/config/config.mk  CONFIG_MK_DATA)
string(REGEX REPLACE "#platform = x86_win32_vs_15" "platform = x86_win32_vs_16" NEW_CONFIG_MK_DATA ${CONFIG_MK_DATA})
file(WRITE ${OMNIORB_ROOT}/config/config.mk  ${NEW_CONFIG_MK_DATA})


file(READ ${OMNIORB_ROOT}/mk/platforms/x86_win32_vs_15.mk PLATFORM_FILE_DATA)
string(REGEX REPLACE "compiler_version_suffix=_vc15" "compiler_version_suffix=_vc16" PLATFORM_FILE_DATA ${PLATFORM_FILE_DATA})
string(REGEX REPLACE "[CcdDeEfF]:" "/cydrive/c" CYG_PYTHON_PATH ${PYTHON3})
string(REGEX REPLACE "#PYTHON = /cygdrive/c/Python36/python" "PYTHON = ${CYG_PYTHON_PATH}" PLATFORM_FILE_DATA ${PLATFORM_FILE_DATA})
string(REGEX REPLACE "[CcdDeEfF]:" "/cydrive/c" CYG_SSL_ROOT ${SSL_ROOT})
string(REGEX REPLACE "#OPEN_SSL_ROOT = /cygdrive/c/openssl" "OPEN_SSL_ROOT = ${CYG_SSL_ROOT}" PLATFORM_FILE_DATA ${PLATFORM_FILE_DATA})
string(REGEX REPLACE "libssl.lib libcrypto.lib" "ssleay32.lib libeay32.lib" PLATFORM_FILE_DATA ${PLATFORM_FILE_DATA})
string(REGEX REPLACE "#EnableZIOP = 1" "EnableZIOP = 1" PLATFORM_FILE_DATA ${PLATFORM_FILE_DATA})
string(REGEX REPLACE "#ZLIB_ROOT = /cygdrive/c/zlib-1.2.11" "ZLIB_ROOT = ${CYG_SSL_ROOT}" PLATFORM_FILE_DATA ${PLATFORM_FILE_DATA})
#file(WRITE ${OMNIORB_ROOT}/mk/platforms/x86_win32_vs_16.mk ${PLATFORM_FILE_DATA})

#file(READ ${OMNIORB_ROOT}/mk/python.mk PYTHON_MK_DATA)
#string(REGEX REPLACE "PYVERSION :.*\r?\n" "" PYTHON_MK_DATA ${PYTHON_MK_DATA})
#string(REGEX REPLACE "" "" PYTHON_MK_DATA ${PYTHON_MK_DATA})
#string(REGEX REPLACE "" "" PYTHON_MK_DATA ${PYTHON_MK_DATA})
#string(REGEX REPLACE "" "" PYTHON_MK_DATA ${PYTHON_MK_DATA})
#file(WRITE ${OMNIORB_ROOT}/mk/python.bak ${PYTHON_MK_DATA})

file(READ ${OMNIORB_ROOT}/src/tool/omniidl/cxx/dir.mk CXX_DIR_MK_DATA)
string(REGEX REPLACE "/lib/x86_win32" "/lib" CXX_DIR_MK_DATA ${CXX_DIR_MK_DATA})
file(WRITE ${OMNIORB_ROOT}/src/tool/omniidl/cxx/dir.mk ${CXX_DIR_MK_DATA})


message("Building omniORB")
vcpkg_execute_required_process(
        COMMAND ${BASH} --noprofile --norc -c "${MAKE} export -j ${VCPKG_CONCURRENCY} VERBOSE=1"
        NO_PARALLEL_COMMAND ${BASH} --noprofile --norc -c "make"
        WORKING_DIRECTORY "${OMNIORB_ROOT}/src"
        LOGNAME "make-build-${TARGET_TRIPLET}-rel")


# Handle copyright
#file(COPY ${ACE_ROOT}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/ace-tao)
#file(RENAME ${CURRENT_PACKAGES_DIR}/share/ace-tao/COPYING ${CURRENT_PACKAGES_DIR}/share/ace-tao/copyright)

vcpkg_copy_pdbs()
