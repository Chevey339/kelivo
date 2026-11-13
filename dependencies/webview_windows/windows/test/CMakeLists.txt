cmake_minimum_required(VERSION 3.15)
project(restricted_preview_tests LANGUAGES CXX)
enable_testing()
add_executable(restricted_preview_policy_test restricted_preview_policy_test.cc)
target_compile_features(restricted_preview_policy_test PRIVATE cxx_std_20)
if(MSVC)
  target_compile_options(restricted_preview_policy_test PRIVATE /W4 /WX)
else()
  target_compile_options(restricted_preview_policy_test PRIVATE -Wall -Wextra -Werror)
endif()
add_test(NAME restricted_preview_policy COMMAND restricted_preview_policy_test)

if(WIN32)
  add_executable(webview_platform_test
    webview_platform_test.cc
    ../webview_platform.cc
    ../graphics_context.cc
    ../util/direct3d11.interop.cc
    ../util/rohelper.cc
  )
  target_include_directories(webview_platform_test PRIVATE ..)
  target_compile_features(webview_platform_test PRIVATE cxx_std_20)
  target_compile_definitions(webview_platform_test PRIVATE
    UNICODE
    _UNICODE
    _HAS_EXCEPTIONS=0
  )
  if(MSVC)
    target_compile_options(webview_platform_test PRIVATE /W4 /WX /wd4100 /EHsc)
  endif()
  target_link_libraries(webview_platform_test PRIVATE d3d11 dxgi)
  add_test(NAME webview_platform COMMAND webview_platform_test)
endif()
