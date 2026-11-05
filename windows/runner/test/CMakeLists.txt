cmake_minimum_required(VERSION 3.14)
project(kelivo_engine_shutdown_test LANGUAGES CXX)

# Standalone native test; no Windows engine DLL, WebView2, or NuGet required.
# Point this at Flutter's common/client_wrapper source directory (or the
# generated windows/flutter/ephemeral/cpp_client_wrapper directory).
set(FLUTTER_CLIENT_WRAPPER_DIR "" CACHE PATH "Flutter C++ client wrapper sources")
set(FLUTTER_PUBLIC_HEADERS "${FLUTTER_CLIENT_WRAPPER_DIR}/../public" CACHE PATH
  "Directory containing flutter_messenger.h")
if(NOT EXISTS "${FLUTTER_CLIENT_WRAPPER_DIR}/core_implementations.cc")
  message(FATAL_ERROR "Set FLUTTER_CLIENT_WRAPPER_DIR to Flutter's C++ wrapper sources")
endif()

add_executable(engine_shutdown_test
  engine_shutdown_test.cpp
  "${FLUTTER_CLIENT_WRAPPER_DIR}/core_implementations.cc"
  "${FLUTTER_CLIENT_WRAPPER_DIR}/standard_codec.cc")
target_compile_features(engine_shutdown_test PRIVATE cxx_std_17)
# These tests provide the C engine boundary themselves, including on Windows.
target_compile_definitions(engine_shutdown_test PRIVATE FLUTTER_DESKTOP_LIBRARY)
target_include_directories(engine_shutdown_test PRIVATE
  "${FLUTTER_CLIENT_WRAPPER_DIR}"
  "${FLUTTER_CLIENT_WRAPPER_DIR}/include"
  "${FLUTTER_PUBLIC_HEADERS}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../dependencies/flutter_inappwebview_windows/windows")
find_package(Threads REQUIRED)
target_link_libraries(engine_shutdown_test PRIVATE Threads::Threads)
enable_testing()
add_test(NAME engine_shutdown_test COMMAND engine_shutdown_test)
set_tests_properties(engine_shutdown_test PROPERTIES TIMEOUT 30)
