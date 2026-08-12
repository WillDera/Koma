cmake_minimum_required(VERSION 3.22.1)
project(koma_piper LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(PIPER_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../piper")
set(LIBPIPER_DIR "${PIPER_ROOT}/libpiper")

include(ExternalProject)

# espeak-ng (static) — same pin as piper1-gpl libpiper.
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
        "-DCMAKE_C_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
        "-DCMAKE_CXX_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
        ${ESPEAK_ANDROID_ARGS}
    BUILD_BYPRODUCTS
        ${ESPEAKNG_STATIC_LIB}
        ${UCD_STATIC_LIB}
    UPDATE_DISCONNECTED TRUE
)

find_package(onnxruntime REQUIRED CONFIG)

add_library(koma_piper SHARED
    piper_jni.cpp
    ${LIBPIPER_DIR}/src/piper.cpp
)

target_compile_definitions(koma_piper PRIVATE BUILDING_LIBPIPER)

add_dependencies(koma_piper espeak_ng_external)

target_include_directories(koma_piper PRIVATE
    ${LIBPIPER_DIR}/include
    ${ESPEAKNG_INSTALL_DIR}/include
)

target_link_libraries(koma_piper PRIVATE
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    onnxruntime::onnxruntime
)
