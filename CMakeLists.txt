# CMake firmware build entrypoint for Raspberry Pi Pico (RP2040) + Swift Embedded.
#
# Important:
# - This build links Pico SDK C runtime/startup with a Swift object file.
# - Swift code is compiled through CMake/SwiftEmbedded.cmake for predictable flags.

cmake_minimum_required(VERSION 3.21)

project(swift_pico_blink C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT DEFINED PICO_SDK_PATH AND DEFINED ENV{PICO_SDK_PATH})
  set(PICO_SDK_PATH "$ENV{PICO_SDK_PATH}")
endif()

if(NOT PICO_SDK_PATH)
  message(FATAL_ERROR "PICO_SDK_PATH is not set. Run Scripts/init.sh first.")
endif()

include("${PICO_SDK_PATH}/external/pico_sdk_import.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/CMake/SwiftEmbedded.cmake")

pico_sdk_init()

# Compile all Swift code into one embedded object.
set(SWIFT_SOURCES
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Main.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/TrafficLight.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/BoardSupport/PicoBoard.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Hardware/MMIO.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Hardware/RP2040GPIO.swift"
)

compile_swift_embedded_object(
  TARGET_NAME swift_embedded_object
  OUTPUT_OBJECT "${CMAKE_BINARY_DIR}/swift/PicoBlink.o"
  SOURCES "${SWIFT_SOURCES}"
)

# Tiny C bootstrap calls into Swift's embedded entry function.
add_executable(swift-pico-blink
  CMake/bootstrap.c
  "${CMAKE_BINARY_DIR}/swift/PicoBlink.o"
)

target_link_libraries(swift-pico-blink
  pico_stdlib
  hardware_gpio
)

target_include_directories(swift-pico-blink PRIVATE
  "${PICO_SDK_PATH}/src/common/pico_stdlib_headers/include"
)

add_dependencies(swift-pico-blink swift_embedded_object)

set_target_properties(swift-pico-blink PROPERTIES SUFFIX ".elf")

pico_enable_stdio_uart(swift-pico-blink 0)
pico_enable_stdio_usb(swift-pico-blink 0)
pico_add_extra_outputs(swift-pico-blink)
