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
    ${METAL_LIB})
