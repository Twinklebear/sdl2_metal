cmake_minimum_required(VERSION 3.5)
project(sdl2_metal)

add_definitions(-DSDL_MAIN_HANDLED)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_LIST_DIR}/cmake")

find_package(Threads REQUIRED)
find_package(SDL2 REQUIRED)
find_library(QUARTZ_CORE QuartzCore)
if (NOT QUARTZ_CORE)
    message(FATAL_ERROR "QuartzCore not found")
endif()

find_library(METAL_LIB Metal)
if (NOT METAL_LIB)
    message(FATAL_ERROR "Metal not found")
endif()

# That this isn't an error by default is insane
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror=objc-method-access")

# Build the Metal shader library
add_custom_command(OUTPUT shaders.metallib
    COMMAND xcrun -sdk macosx metal -c ${CMAKE_CURRENT_LIST_DIR}/shaders.metal -o shaders.air
    COMMAND xcrun -sdk macosx metallib shaders.air -o shaders.metallib
    DEPENDS ${CMAKE_CURRENT_LIST_DIR}/shaders.metal
    BYPRODUCTS shaders.air)

add_custom_target(shader_library_wrapper ALL DEPENDS shaders.metallib)

add_library(shader_library INTERFACE)
add_dependencies(shader_library shader_library_wrapper)

add_executable(sdl2_metal main.mm)

set_target_properties(sdl2_metal PROPERTIES
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED ON)

target_include_directories(sdl2_metal PUBLIC
    $<BUILD_INTERFACE:${SDL2_INCLUDE_DIR}>)

target_link_libraries(sdl2_metal
    PUBLIC
    ${SDL2_LIBRARY}
    ${QUARTZ_CORE}
    ${METAL_LIB}
    shader_library)

