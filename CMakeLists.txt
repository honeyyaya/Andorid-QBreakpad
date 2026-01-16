cmake_minimum_required(VERSION 3.14)
project(QBreakpadDemo LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(BUILD_DEMO_QML "Build the QML demo executable" OFF)

if(BUILD_DEMO_QML)
    find_package(Qt5 5.14 COMPONENTS Core Gui Qml Quick Network REQUIRED)
else()
    find_package(Qt5 5.14 COMPONENTS Core REQUIRED)
endif()

if(ANDROID)
    message(STATUS "Building for Android ABI: ${ANDROID_ABI}")
endif()

if(ANDROID)
    find_library(ANDROID_ZLIB_LIBRARY z REQUIRED)
    if(BUILD_DEMO_QML)
        find_library(ANDROID_GLESV2_LIBRARY GLESv2 REQUIRED)
        find_library(ANDROID_EGL_LIBRARY EGL REQUIRED)
    endif()
endif()

# 兜底：非 ANDROID 或未找到时尝试一般名
if(NOT ANDROID_ZLIB_LIBRARY)
    find_library(ANDROID_ZLIB_LIBRARY z)
endif()

set(BREAKPAD_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/third_party/breakpad)
set(BREAKPAD_SRC ${BREAKPAD_ROOT}/src)
set(BREAKPAD_PREBUILT ${BREAKPAD_ROOT}/obj/local/arm64-v8a/libbreakpad_client.a)

if(EXISTS ${BREAKPAD_PREBUILT})
    add_library(breakpad_client STATIC IMPORTED GLOBAL)
    set_target_properties(breakpad_client PROPERTIES
        IMPORTED_LOCATION ${BREAKPAD_PREBUILT}
        INTERFACE_INCLUDE_DIRECTORIES "${BREAKPAD_SRC};${BREAKPAD_SRC}/third_party/lss"
    )
    target_link_libraries(breakpad_client INTERFACE log android atomic ${ANDROID_ZLIB_LIBRARY})
    message(STATUS "Using prebuilt breakpad_client: ${BREAKPAD_PREBUILT}")
else()
    message(FATAL_ERROR "Prebuilt breakpad_client not found at ${BREAKPAD_PREBUILT}. Please provide the .a.")
endif()


set(QML_QRC qml/qml.qrc)
qt5_add_resources(QML_RES ${QML_QRC})

# 核心封装库，默认生成 SHARED（可改 STATIC）
add_library(qbreakpad_wrapper SHARED
    src/CrashHandler.cpp
    src/CrashHandler.h
    src/CrashBridge.h
    src/qbreakpad_c_api.cpp
)

target_link_libraries(qbreakpad_wrapper
    Qt5::Core
    ${ANDROID_ZLIB_LIBRARY}
)

if(TARGET breakpad_client)
    target_link_libraries(qbreakpad_wrapper breakpad_client)
    target_compile_definitions(qbreakpad_wrapper PRIVATE HAVE_BREAKPAD=1)
endif()

target_compile_definitions(qbreakpad_wrapper PRIVATE QBREAKPAD_WRAPPER_LIBRARY)

set_target_properties(qbreakpad_wrapper PROPERTIES
    AUTOMOC ON
    AUTORCC OFF
    AUTOUIC OFF
)

# 可选：构建 QML Demo（需要 Qt Quick），默认关闭
option(BUILD_DEMO_QML "Build the QML demo executable" OFF)

if(BUILD_DEMO_QML)
    add_executable(appQBreakpadDemo
        src/main.cpp
        src/CrashHandler.cpp
        src/CrashHandler.h
        src/CrashBridge.h
        ${QML_RES}
    )

    target_link_libraries(appQBreakpadDemo
        Qt5::Core
        Qt5::Gui
        Qt5::Qml
        Qt5::Quick
        Qt5::Network
        ${ANDROID_GLESV2_LIBRARY}
        ${ANDROID_EGL_LIBRARY}
        ${ANDROID_ZLIB_LIBRARY}
    )

    if(ANDROID)
        if(ANDROID_ABI STREQUAL "arm64-v8a")
            set(_ndk_triple "aarch64-linux-android")
        elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
            set(_ndk_triple "arm-linux-androideabi")
        elseif(ANDROID_ABI STREQUAL "x86_64")
            set(_ndk_triple "x86_64-linux-android")
        elseif(ANDROID_ABI STREQUAL "x86")
            set(_ndk_triple "i686-linux-android")
        endif()
        if(_ndk_triple AND ANDROID_PLATFORM_LEVEL)
            target_link_options(appQBreakpadDemo PRIVATE
                "-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/${_ndk_triple}"
                "-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/${_ndk_triple}/${ANDROID_PLATFORM_LEVEL}"
            )
        endif()
    endif()

    if(TARGET breakpad_client)
        target_link_libraries(appQBreakpadDemo breakpad_client)
        target_compile_definitions(appQBreakpadDemo PRIVATE HAVE_BREAKPAD=1)
    endif()

    set_target_properties(appQBreakpadDemo PROPERTIES
        AUTOMOC ON
        AUTORCC ON
        AUTOUIC OFF
    )
endif()
