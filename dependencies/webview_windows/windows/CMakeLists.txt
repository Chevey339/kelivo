cmake_minimum_required(VERSION 3.15)

# Set CMP0175 to NEW to properly handle add_custom_command arguments
if(POLICY CMP0175)
  cmake_policy(SET CMP0175 NEW)
endif()

set(PROJECT_NAME "webview_windows")

set(WIL_VERSION "1.0.220914.1")
set(WEBVIEW_VERSION "1.0.2365.46")

message(VERBOSE "CMake system version is ${CMAKE_SYSTEM_VERSION} (using SDK ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION})")

project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "webview_windows_plugin")

set(NUGET_URL https://dist.nuget.org/win-x86-commandline/v5.10.0/nuget.exe)
set(NUGET_SHA256 852b71cc8c8c2d40d09ea49d321ff56fd2397b9d6ea9f96e532530307bbbafd3)

# Find or download NuGet
find_program(NUGET nuget)
if(NOT NUGET)
  message(NOTICE "Nuget is not installed.")
  set(NUGET ${CMAKE_BINARY_DIR}/nuget.exe)
  if (NOT EXISTS ${NUGET})
    message(NOTICE "Attempting to download nuget.")
    file(DOWNLOAD ${NUGET_URL} ${NUGET})
  endif()

  file(SHA256 ${NUGET} NUGET_DL_HASH)
  if (NOT NUGET_DL_HASH STREQUAL NUGET_SHA256)
    message(FATAL_ERROR "Integrity check for ${NUGET} failed.")
  endif()
endif()

# Create custom target for dependencies
add_custom_target(${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD ALL)

# Download dependencies using NuGet
# Note: Removed DEPENDS keyword from TARGET version of add_custom_command
add_custom_command(
  TARGET ${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD PRE_BUILD
  COMMAND ${CMAKE_COMMAND} -E echo "Downloading dependencies..."
  COMMAND ${NUGET} install Microsoft.Windows.ImplementationLibrary -Version ${WIL_VERSION} -ExcludeVersion -OutputDirectory ${CMAKE_CURRENT_BINARY_DIR}/packages
  COMMAND ${NUGET} install Microsoft.Web.WebView2 -Version ${WEBVIEW_VERSION} -ExcludeVersion -OutputDirectory ${CMAKE_CURRENT_BINARY_DIR}/packages
  COMMENT "Downloading and installing NuGet packages"
)

# Define source files
set(PLUGIN_SOURCES
  "webview_windows_plugin.cc"
  "webview_platform.cc"
  "webview.cc"
  "restricted_preview.cc"
  "webview_host.cc"
  "webview_bridge.cc"
  "texture_bridge.cc"
  "texture_bridge_gpu.cc"
  "graphics_context.cc"
  "util/direct3d11.interop.cc"
  "util/rohelper.cc"
  "util/string_converter.cc"
)

# Create the plugin library
add_library(${PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})
add_dependencies(${PLUGIN_NAME} ${PROJECT_NAME}_DEPENDENCIES_DOWNLOAD)

# Configure compiler options
if(MSVC)
  target_compile_options(${PLUGIN_NAME} PRIVATE "/await")
endif()

# Apply standard settings
apply_standard_settings(${PLUGIN_NAME})

# Set C++ standard to 20 for std::format support
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)

# Configure visibility
set_target_properties(${PLUGIN_NAME} PROPERTIES 
  CXX_VISIBILITY_PRESET hidden
)

# Add dependencies
target_link_libraries(${PLUGIN_NAME} PRIVATE 
  ${CMAKE_CURRENT_BINARY_DIR}/packages/Microsoft.Web.WebView2/build/native/Microsoft.Web.WebView2.targets
  ${CMAKE_CURRENT_BINARY_DIR}/packages/Microsoft.Windows.ImplementationLibrary/build/native/Microsoft.Windows.ImplementationLibrary.targets
  flutter 
  flutter_wrapper_plugin
)

# Configure definitions and includes
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Set bundled libraries
set(webview_windows_bundled_libraries
  PARENT_SCOPE
) 
