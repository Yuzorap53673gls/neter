cmake_minimum_required(VERSION 3.21)
project(rbx_esp LANGUAGES CXX)

if(NOT MSVC)
    message(FATAL_ERROR "rbx_esp targets MSVC x64 only")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(imgui STATIC
    vendor/imgui/imgui.cpp
    vendor/imgui/imgui_draw.cpp
    vendor/imgui/imgui_tables.cpp
    vendor/imgui/imgui_widgets.cpp
    vendor/imgui/backends/imgui_impl_win32.cpp
    vendor/imgui/backends/imgui_impl_dx11.cpp
)
target_include_directories(imgui PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui ${CMAKE_CURRENT_SOURCE_DIR}/vendor/imgui/backends)
target_compile_options(imgui PRIVATE /W0 /utf-8)
target_compile_definitions(imgui PUBLIC UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)

add_executable(rbx_esp WIN32
    src/main.cpp
    src/game.cpp
    src/memory.cpp
    src/log.cpp
    src/esp.cpp
    src/panel.cpp
    src/overlay.cpp
)

target_link_libraries(rbx_esp PRIVATE
    imgui
    d3d11
    dxgi
    dwmapi
    psapi
    shell32
    user32
    gdi32
)

target_compile_options(rbx_esp PRIVATE /W4 /permissive- /utf-8 /Zc:__cplusplus)
target_compile_definitions(rbx_esp PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN _CRT_SECURE_NO_WARNINGS)

set_target_properties(rbx_esp PROPERTIES
    OUTPUT_NAME rbx_esp
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
# The Visual Studio generator appends the config name unless each config
# directory is pinned explicitly. The spec wants the binary exactly at
# build/bin/rbx_esp.exe, not build/bin/Release/rbx_esp.exe.
foreach(config Debug Release RelWithDebInfo MinSizeRel)
    string(TOUPPER "${config}" config_upper)
    set_target_properties(rbx_esp PROPERTIES RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${CMAKE_BINARY_DIR}/bin")
endforeach()

add_custom_command(TARGET rbx_esp POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_FILE:rbx_esp>" "${CMAKE_BINARY_DIR}/bin/1.exe"
    COMMENT "Copying rbx_esp.exe to 1.exe (identical build)"
)
