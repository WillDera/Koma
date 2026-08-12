cmake_minimum_required(VERSION 3.22.1)
project(koma_piper LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(PIPER_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../piper")
set(LIBPIPER_DIR "${PIPER_ROOT}/libpiper")

include(ExternalProject)

# ---- onnxruntime (Android) ----
#
# The onnxruntime-android AAR has no prefab metadata, so find_package() can
# never resolve it. Unpack the AAR and point an imported target at the ABI's
# libonnxruntime.so, mirroring how upstream libpiper consumes the desktop
# onnxruntime release archives. The Gradle `onnxruntime-android` dependency
# is what actually packages the .so into the APK; this copy is link-time only
# and must stay on the same version.

if(NOT DEFINED ONNXRUNTIME_VERSION)
    set(ONNXRUNTIME_VERSION "1.22.0")
endif()

set(ONNXRUNTIME_ROOT "${PIPER_ROOT}/onnxruntime")
set(ONNXRUNTIME_DIR "${ONNXRUNTIME_ROOT}/onnxruntime-android-${ONNXRUNTIME_VERSION}")
set(ONNXRUNTIME_AAR "${ONNXRUNTIME_ROOT}/onnxruntime-android-${ONNXRUNTIME_VERSION}.aar")
set(ONNXRUNTIME_URL
    "https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/${ONNXRUNTIME_VERSION}/onnxruntime-android-${ONNXRUNTIME_VERSION}.aar")

if(NOT EXISTS "${ONNXRUNTIME_DIR}/headers/onnxruntime_cxx_api.h")
    if(NOT EXISTS "${ONNXRUNTIME_AAR}")
        message(STATUS "Downloading ${ONNXRUNTIME_URL}")
        file(DOWNLOAD "${ONNXRUNTIME_URL}" "${ONNXRUNTIME_AAR}"
            STATUS ONNXRUNTIME_DOWNLOAD_STATUS
            SHOW_PROGRESS
        )
        list(GET ONNXRUNTIME_DOWNLOAD_STATUS 0 ONNXRUNTIME_DOWNLOAD_CODE)
        if(NOT ONNXRUNTIME_DOWNLOAD_CODE EQUAL 0)
            list(GET ONNXRUNTIME_DOWNLOAD_STATUS 1 ONNXRUNTIME_DOWNLOAD_ERROR)
            file(REMOVE "${ONNXRUNTIME_AAR}")
            message(FATAL_ERROR
                "Failed to download onnxruntime AAR: ${ONNXRUNTIME_DOWNLOAD_ERROR}")
        endif()
    endif()

    file(MAKE_DIRECTORY "${ONNXRUNTIME_DIR}")
    file(ARCHIVE_EXTRACT
        INPUT "${ONNXRUNTIME_AAR}"
        DESTINATION "${ONNXRUNTIME_DIR}"
    )
endif()

set(ONNXRUNTIME_LIB "${ONNXRUNTIME_DIR}/jni/${ANDROID_ABI}/libonnxruntime.so")
if(NOT EXISTS "${ONNXRUNTIME_LIB}")
    message(FATAL_ERROR
        "onnxruntime is missing a build for ABI '${ANDROID_ABI}': ${ONNXRUNTIME_LIB}")
endif()

add_library(onnxruntime::onnxruntime SHARED IMPORTED)
set_target_properties(onnxruntime::onnxruntime PROPERTIES
    IMPORTED_LOCATION "${ONNXRUNTIME_LIB}"
    INTERFACE_INCLUDE_DIRECTORIES "${ONNXRUNTIME_DIR}/headers"
)

# ---- espeak-ng (static) — same pin as piper1-gpl libpiper ----

set(ESPEAKNG_BUILD_DIR ${CMAKE_BINARY_DIR}/espeak_ng)
set(ESPEAKNG_INSTALL_DIR ${CMAKE_BINARY_DIR}/espeak_ng-install)

get_property(IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTI_CONFIG)
    set(UCD_CONFIG_SUBDIR "$<CONFIG>/")
else()
    set(UCD_CONFIG_SUBDIR "")
endif()

set(UCD_TOOLS_DIR ${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external-build/src/ucd-tools)
set(ESPEAKNG_STATIC_LIB ${ESPEAKNG_INSTALL_DIR}/lib/libespeak-ng.a)
set(UCD_STATIC_LIB ${UCD_TOOLS_DIR}/${UCD_CONFIG_SUBDIR}libucd.a)

set(ESPEAK_ANDROID_ARGS)
if(ANDROID)
    list(APPEND ESPEAK_ANDROID_ARGS
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}
        -DANDROID_ABI=${ANDROID_ABI}
        -DANDROID_PLATFORM=${ANDROID_PLATFORM}
        -DANDROID_NDK=${ANDROID_NDK}
        -DANDROID_STL=c++_shared
    )
endif()

ExternalProject_Add(espeak_ng_external
    GIT_REPOSITORY https://github.com/espeak-ng/espeak-ng.git
    GIT_TAG 212928b394a96e8fd2096616bfd54e17845c48f6
    PREFIX ${ESPEAKNG_BUILD_DIR}
    CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=${ESPEAKNG_INSTALL_DIR}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DBUILD_SHARED_LIBS:BOOL=OFF
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
        -DUSE_ASYNC:BOOL=OFF
        -DUSE_MBROLA:BOOL=OFF
        -DUSE_LIBSONIC:BOOL=OFF
        -DUSE_LIBPCAUDIO:BOOL=OFF
        -DUSE_KLATT:BOOL=OFF
        -DUSE_SPEECHPLAYER:BOOL=OFF
        -DEXTRA_cmn:BOOL=ON
        -DEXTRA_ru:BOOL=ON
        # Phoneme/intonation data is shipped prebuilt in app assets; compiling
        # it needs a host espeak-ng binary that does not exist when cross
        # compiling for Android.
        -DCOMPILE_INTONATIONS:BOOL=OFF
        -DENABLE_TESTS:BOOL=OFF
        -DBUILD_TESTING:BOOL=OFF
        "-DCMAKE_C_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
        "-DCMAKE_CXX_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
        ${ESPEAK_ANDROID_ARGS}
    BUILD_BYPRODUCTS
        ${ESPEAKNG_STATIC_LIB}
        ${UCD_STATIC_LIB}
    UPDATE_DISCONNECTED TRUE
)

# ---- koma_piper ----

add_library(koma_piper SHARED
    piper_jni.cpp
    ${LIBPIPER_DIR}/src/piper.cpp
)

add_dependencies(koma_piper espeak_ng_external)

target_include_directories(koma_piper PRIVATE
    ${LIBPIPER_DIR}/include
    ${ESPEAKNG_INSTALL_DIR}/include
)

target_link_libraries(koma_piper PRIVATE
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    onnxruntime::onnxruntime
    android
    log
)
