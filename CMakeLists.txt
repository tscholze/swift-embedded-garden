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

# Board target. Use Scripts/switch.sh to change between pico and pico_w.
if(NOT DEFINED PICO_BOARD)
  set(PICO_BOARD pico_w)
endif()

include("${PICO_SDK_PATH}/external/pico_sdk_import.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/CMake/SwiftEmbedded.cmake")

pico_sdk_init()

# Compile all Swift code into one embedded object. Sources are explicitly listed
# because CMake/SwiftEmbedded.cmake invokes swiftc directly rather than SwiftPM.
set(SWIFT_SOURCES
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Main.swift"

  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/Sample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/BuzzerSample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/TrafficLightSample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/GPIOSample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/ButtonSample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/PWMSample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/DisplaySample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/DHT11Sample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/DRV8833Sample.swift"

  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/TrafficLight/TrafficLight.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SSD1306Driver.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SSD1306Renderer.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SSD1306Configuration.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SwiftGFX.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/RotaryButton/RotaryButton.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/RotaryButton/RotaryButtonConfiguration.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/DHT11/DHT11.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/DHT11/DHT11Configuration.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/Buzzer/Buzzer.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/Button/Button.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/DRV8833/DRV8833.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/DRV8833/DRV8833Configuration.swift"

  "${CMAKE_CURRENT_LIST_DIR}/Sources/Board/RP2040/MMIO.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Board/RP2040/GPIO.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Board/RP2040/I2C.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Board/RP2040/PWM.swift"
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

# When targeting Pico W, link the minimal CYW43 driver (no RTOS, no WiFi) so
# cyw43_arch_init() and cyw43_arch_gpio_put() are available for the LED.
if(PICO_BOARD STREQUAL "pico_w")
  target_link_libraries(swift-pico-blink pico_cyw43_arch_none)
endif()

target_include_directories(swift-pico-blink PRIVATE
  "${PICO_SDK_PATH}/src/common/pico_stdlib_headers/include"
)

add_dependencies(swift-pico-blink swift_embedded_object)

set_target_properties(swift-pico-blink PROPERTIES SUFFIX ".elf")

pico_enable_stdio_uart(swift-pico-blink 0)
pico_enable_stdio_usb(swift-pico-blink 0)
pico_add_extra_outputs(swift-pico-blink)
