#!/usr/bin/env bash
#
# Tobias Scholze, 2026, MIT License
#
# Standalone project generator for Swift Embedded + Raspberry Pi Pico.
# This script is self-contained: you can copy only this file anywhere, run it,
# and it will create a complete ready-to-use project scaffold.

set -euo pipefail

# -----------------------------
# Defaults (can be overridden by flags or interactive prompts)
# -----------------------------
PROJECT_NAME="SwiftPicoEmbeddedGarden"
OUTPUT_DIR=""
TARGET_NAME="swift-pico-blink"
PICO_SDK_REF="master"
SWIFTLY_CHANNEL="main-snapshot"
FLASH_VOLUME_HINT="/Volumes"
INCLUDE_CI=1
FORCE_OVERWRITE=0
NON_INTERACTIVE=0
POST_ACTION="ask" # ask|none|init|build

# -----------------------------
# Simple UI helpers
# -----------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""
  C_BOLD=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_CYAN=""
fi

# Prints a progress message in a consistent format.
log()  { printf "%s==>%s %s\n" "${C_CYAN}" "${C_RESET}" "$*"; }
# Prints a warning message.
warn() { printf "%s⚠%s %s\n" "${C_YELLOW}" "${C_RESET}" "$*"; }
# Prints an error and exits with failure.
fail() { printf "%s❌%s %s\n" "${C_RED}" "${C_RESET}" "$*"; exit 1; }
# Prints a success message.
ok()   { printf "%s✅%s %s\n" "${C_GREEN}" "${C_RESET}" "$*"; }

# Renders the startup banner for the interactive experience.
show_header() {
  cat <<'EOF'

   _____           _  __ _     _
  / ____|         (_)/ _| |   | |
 | (___  __      ___| |_| |_  | | _____   _____  ___
  \___ \ \ \ /\ / / |  _| __| | |/ _ \ \ / / _ \/ __|
  ____) | \ V  V /| | | | |_  | | (_) \ V /  __/\__ \
 |_____/   \_/\_/ |_|_|  \__| |_|\___/ \_/ \___||___/

  _____  _
 |  __ \(_)
 | |__) |_  ___ ___
 |  ___/| |/ __/ _ \
 | |    | | (_| (_) |
 |_|    |_|\___\___/

EOF
}

# Shows command-line help with all supported options and examples.
print_usage() {
  cat <<'EOF'
Usage: ./generate-swift-pico-project.sh [options]

Options:
  --project-name <name>        Project folder/package display name
  --output-dir <path>          Output directory for the generated project
  --target-name <name>         Firmware target/binary name (default: swift-pico-blink)
  --pico-sdk-ref <ref>         Pico SDK branch/tag/commit-ish (default: master)
  --swiftly-channel <name>     swiftly channel used in init.sh (default: main-snapshot)
  --flash-volume-hint <path>   Default mount root used by run.sh (default: /Volumes)
  --include-ci                 Include GitHub Actions Linux no-flash workflow (default)
  --no-include-ci              Skip CI workflow generation
  --post-action <mode>         none | init | build | ask (default: ask)
  --non-interactive            Disable prompts; require/assume provided values
  --force                      Allow generation into non-empty directory
  --help                       Show this help

Examples:
  ./generate-swift-pico-project.sh
  ./generate-swift-pico-project.sh --project-name MyPicoBlink --output-dir ./MyPicoBlink --post-action none
  ./generate-swift-pico-project.sh --non-interactive --project-name LabPico --output-dir ./LabPico --target-name lab-pico
EOF
}

# Normalizes firmware target names for file and binary safety.
sanitize_target_name() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-_'
}

# Normalizes package names into Swift-package-friendly identifiers.
sanitize_package_name() {
  local value
  value="$(printf "%s" "$1" | tr -cd '[:alnum:]')"
  if [ -z "${value}" ]; then
    value="SwiftPicoEmbeddedGarden"
  fi
  printf "%s" "${value}"
}

# Prompts for yes/no confirmation with support for default answers.
confirm() {
  local prompt="$1"
  local default_yes="$2"
  local answer=""
  if [ "${NON_INTERACTIVE}" -eq 1 ]; then
    [ "${default_yes}" -eq 1 ] && return 0 || return 1
  fi
  if [ "${default_yes}" -eq 1 ]; then
    read -r -p "${prompt} [Y/n]: " answer || true
    case "${answer:-Y}" in
      y|Y|yes|YES|"") return 0 ;;
      *) return 1 ;;
    esac
  else
    read -r -p "${prompt} [y/N]: " answer || true
    case "${answer:-N}" in
      y|Y|yes|YES) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# Parses command-line flags and stores values in configuration variables.
parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-name) shift; [ "$#" -gt 0 ] || fail "--project-name requires a value"; PROJECT_NAME="$1" ;;
      --output-dir) shift; [ "$#" -gt 0 ] || fail "--output-dir requires a value"; OUTPUT_DIR="$1" ;;
      --target-name) shift; [ "$#" -gt 0 ] || fail "--target-name requires a value"; TARGET_NAME="$1" ;;
      --pico-sdk-ref) shift; [ "$#" -gt 0 ] || fail "--pico-sdk-ref requires a value"; PICO_SDK_REF="$1" ;;
      --swiftly-channel) shift; [ "$#" -gt 0 ] || fail "--swiftly-channel requires a value"; SWIFTLY_CHANNEL="$1" ;;
      --flash-volume-hint) shift; [ "$#" -gt 0 ] || fail "--flash-volume-hint requires a value"; FLASH_VOLUME_HINT="$1" ;;
      --include-ci) INCLUDE_CI=1 ;;
      --no-include-ci) INCLUDE_CI=0 ;;
      --post-action) shift; [ "$#" -gt 0 ] || fail "--post-action requires a value"; POST_ACTION="$1" ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      --force) FORCE_OVERWRITE=1 ;;
      -h|--help) print_usage; exit 0 ;;
      *) fail "Unknown option: $1 (use --help)" ;;
    esac
    shift
  done
}

# Collects missing configuration interactively unless non-interactive mode is enabled.
interactive_prompts() {
  [ "${NON_INTERACTIVE}" -eq 1 ] && return 0

  printf "\n%sProject setup%s\n" "${C_BOLD}" "${C_RESET}"
  read -r -p "Project name [${PROJECT_NAME}]: " input || true
  PROJECT_NAME="${input:-$PROJECT_NAME}"

  if [ -z "${OUTPUT_DIR}" ]; then
    OUTPUT_DIR="./${PROJECT_NAME}"
  fi
  read -r -p "Output directory [${OUTPUT_DIR}]: " input || true
  OUTPUT_DIR="${input:-$OUTPUT_DIR}"

  TARGET_NAME="$(sanitize_target_name "${TARGET_NAME}")"
  read -r -p "Firmware target name [${TARGET_NAME}]: " input || true
  TARGET_NAME="$(sanitize_target_name "${input:-$TARGET_NAME}")"

  printf "\n%sToolchain and SDK%s\n" "${C_BOLD}" "${C_RESET}"
  read -r -p "Pico SDK ref [${PICO_SDK_REF}]: " input || true
  PICO_SDK_REF="${input:-$PICO_SDK_REF}"
  read -r -p "swiftly channel [${SWIFTLY_CHANNEL}]: " input || true
  SWIFTLY_CHANNEL="${input:-$SWIFTLY_CHANNEL}"

  printf "\n%sRuntime defaults%s\n" "${C_BOLD}" "${C_RESET}"
  read -r -p "Flash mount root hint [${FLASH_VOLUME_HINT}]: " input || true
  FLASH_VOLUME_HINT="${input:-$FLASH_VOLUME_HINT}"

  if confirm "Include GitHub Action workflow (Linux no-flash build)?" 1; then
    INCLUDE_CI=1
  else
    INCLUDE_CI=0
  fi

  printf "\n%sPost generation%s\n" "${C_BOLD}" "${C_RESET}"
  printf "1) Generate files only\n"
  printf "2) Generate + run setup (Scripts/init.sh)\n"
  printf "3) Generate + run setup + no-flash build (Scripts/run.sh --no-flash)\n"
  read -r -p "Choose [1-3, default 1]: " input || true
  case "${input:-1}" in
    2) POST_ACTION="init" ;;
    3) POST_ACTION="build" ;;
    *) POST_ACTION="none" ;;
  esac
}

# Validates final configuration values before generating any files.
validate_config() {
  [ -n "${PROJECT_NAME}" ] || fail "Project name cannot be empty."
  [ -n "${OUTPUT_DIR}" ] || OUTPUT_DIR="./${PROJECT_NAME}"
  TARGET_NAME="$(sanitize_target_name "${TARGET_NAME}")"
  [ -n "${TARGET_NAME}" ] || fail "Target name must contain letters/numbers."
  case "${POST_ACTION}" in
    ask|none|init|build) ;;
    *) fail "Invalid --post-action value: ${POST_ACTION}" ;;
  esac
}

# Ensures output directory exists and handles overwrite safety checks.
prepare_output_dir() {
  mkdir -p "${OUTPUT_DIR}"
  if [ -n "$(find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]; then
    if [ "${FORCE_OVERWRITE}" -eq 1 ]; then
      warn "Output directory is not empty. Continuing because --force was set."
    elif [ "${NON_INTERACTIVE}" -eq 1 ]; then
      fail "Output directory is not empty. Re-run with --force or a new --output-dir."
    else
      if ! confirm "Output directory is not empty. Continue and overwrite matching files?" 0; then
        fail "Aborted by user."
      fi
    fi
  fi
}

# Writes template content to a file after replacing placeholder tokens.
emit_template() {
  local output_path="$1"
  local dir
  dir="$(dirname "${output_path}")"
  mkdir -p "${dir}"

  local tmp
  tmp="$(mktemp)"
  cat > "${tmp}"

  awk \
    -v project_name="${PROJECT_NAME}" \
    -v package_name="${PACKAGE_NAME}" \
    -v target_name="${TARGET_NAME}" \
    -v pico_sdk_ref="${PICO_SDK_REF}" \
    -v swiftly_channel="${SWIFTLY_CHANNEL}" \
    -v flash_volume_hint="${FLASH_VOLUME_HINT}" \
    '{
      gsub(/__PROJECT_NAME__/, project_name);
      gsub(/__PACKAGE_NAME__/, package_name);
      gsub(/__TARGET_NAME__/, target_name);
      gsub(/__PICO_SDK_REF__/, pico_sdk_ref);
      gsub(/__SWIFTLY_CHANNEL__/, swiftly_channel);
      gsub(/__FLASH_VOLUME_HINT__/, flash_volume_hint);
      print
    }' "${tmp}" > "${output_path}"

  rm -f "${tmp}"
}

# Generates the complete project structure and all project files from templates.
write_project_files() {
  log "Generating project in: ${OUTPUT_DIR}"

  emit_template "${OUTPUT_DIR}/.gitignore" <<'EOF'
# macOS
.DS_Store

# Local build outputs
build/
.build/

# Local dependencies and host tools downloaded by Scripts/init.sh
.deps/
.tools/

# Local shell environment generated by Scripts/init.sh
Scripts/env.sh
EOF

  emit_template "${OUTPUT_DIR}/Package.swift" <<'EOF'
// swift-tools-version: 6.0
//
// Generated by generate-swift-pico-project.sh
// This package file is prepared for future Swift Embedded dependencies.

import PackageDescription

let package = Package(
    name: "__PACKAGE_NAME__",
    products: [
        .executable(name: "PicoBlink", targets: ["PicoBlink"])
    ],
    dependencies: [
        // Example:
        // .package(url: "https://github.com/apple/swift-mmio.git", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "PicoBlink",
            dependencies: [
                // Example:
                // .product(name: "MMIO", package: "swift-mmio"),
            ],
            path: "Sources",
            sources: [
                "Application",
                "BoardSupport",
              "Display",
              "Graphics",
                "Hardware",
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-enable-experimental-feature",
                    "Embedded",
                ], .when(configuration: .release)),
            ]
        )
    ]
)
EOF

  emit_template "${OUTPUT_DIR}/CMakeLists.txt" <<'EOF'
# CMake firmware build entrypoint for Raspberry Pi Pico (RP2040) + Swift Embedded.

cmake_minimum_required(VERSION 3.21)

project(__TARGET_NAME__ C CXX ASM)

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

set(SWIFT_SOURCES
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Main.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/DisplaySample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/BoardSupport/PicoSSD1306.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Display/SSD1306Driver.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Graphics/SwiftGFX.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Hardware/MMIO.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Hardware/RP2040GPIO.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Hardware/RP2040I2C.swift"
)

compile_swift_embedded_object(
  TARGET_NAME swift_embedded_object
  OUTPUT_OBJECT "${CMAKE_BINARY_DIR}/swift/PicoBlink.o"
  SOURCES "${SWIFT_SOURCES}"
)

add_executable(__TARGET_NAME__
  CMake/bootstrap.c
  "${CMAKE_BINARY_DIR}/swift/PicoBlink.o"
)

target_link_libraries(__TARGET_NAME__
  pico_stdlib
  hardware_gpio
)

target_include_directories(__TARGET_NAME__ PRIVATE
  "${PICO_SDK_PATH}/src/common/pico_stdlib_headers/include"
)

add_dependencies(__TARGET_NAME__ swift_embedded_object)

set_target_properties(__TARGET_NAME__ PROPERTIES SUFFIX ".elf")

pico_enable_stdio_uart(__TARGET_NAME__ 0)
pico_enable_stdio_usb(__TARGET_NAME__ 0)
pico_add_extra_outputs(__TARGET_NAME__)
EOF

  emit_template "${OUTPUT_DIR}/CMake/SwiftEmbedded.cmake" <<'EOF'
# Helper to compile Swift Embedded sources into a single object file.

function(compile_swift_embedded_object)
  set(options)
  set(oneValueArgs TARGET_NAME OUTPUT_OBJECT)
  set(multiValueArgs SOURCES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_TARGET_NAME)
    message(FATAL_ERROR "compile_swift_embedded_object requires TARGET_NAME.")
  endif()

  if(NOT ARG_OUTPUT_OBJECT)
    message(FATAL_ERROR "compile_swift_embedded_object requires OUTPUT_OBJECT.")
  endif()

  if(NOT ARG_SOURCES)
    message(FATAL_ERROR "compile_swift_embedded_object requires SOURCES.")
  endif()

  if(NOT DEFINED SWIFT_EXECUTABLE)
    find_program(SWIFT_EXECUTABLE swiftc REQUIRED)
  endif()

  get_filename_component(SWIFT_OUTPUT_DIR "${ARG_OUTPUT_OBJECT}" DIRECTORY)
  file(MAKE_DIRECTORY "${SWIFT_OUTPUT_DIR}")

  add_custom_command(
    OUTPUT "${ARG_OUTPUT_OBJECT}"
    COMMAND "${SWIFT_EXECUTABLE}"
      -target armv6m-none-none-eabi
      -enable-experimental-feature Embedded
      -parse-as-library
      -wmo
      -Osize
      -emit-object
      -module-name PicoBlink
      ${ARG_SOURCES}
      -o "${ARG_OUTPUT_OBJECT}"
    DEPENDS ${ARG_SOURCES}
    VERBATIM
    COMMENT "Compiling Swift Embedded object: ${ARG_OUTPUT_OBJECT}"
  )

  add_custom_target(${ARG_TARGET_NAME} DEPENDS "${ARG_OUTPUT_OBJECT}")
endfunction()
EOF

  emit_template "${OUTPUT_DIR}/CMake/arm-none-eabi-toolchain.cmake" <<'EOF'
# Cross-compilation toolchain for RP2040 firmware builds on macOS/Linux hosts.

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR cortex-m0plus)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

find_program(ARM_NONE_EABI_GCC arm-none-eabi-gcc REQUIRED)
find_program(ARM_NONE_EABI_GXX arm-none-eabi-g++ REQUIRED)

set(CMAKE_C_COMPILER "${ARM_NONE_EABI_GCC}")
set(CMAKE_CXX_COMPILER "${ARM_NONE_EABI_GXX}")
set(CMAKE_ASM_COMPILER "${ARM_NONE_EABI_GCC}")

set(CMAKE_C_FLAGS_INIT "-mcpu=cortex-m0plus -mthumb")
set(CMAKE_CXX_FLAGS_INIT "-mcpu=cortex-m0plus -mthumb")
set(CMAKE_ASM_FLAGS_INIT "-mcpu=cortex-m0plus -mthumb")
EOF

  emit_template "${OUTPUT_DIR}/CMake/bootstrap.c" <<'EOF'
// C bootstrap for RP2040 startup.

#include "pico/stdlib.h"
#include <errno.h>
#include <malloc.h>
#include <stddef.h>
#include <stdint.h>

extern void swift_main(void);

int posix_memalign(void **memptr, size_t alignment, size_t size) {
  if ((alignment < sizeof(void *)) || ((alignment & (alignment - 1)) != 0)) {
    return EINVAL;
  }
  void *ptr = memalign(alignment, size);
  if (!ptr) {
    return ENOMEM;
  }
  *memptr = ptr;
  return 0;
}

void pico_delay_ms(uint32_t ms) {
  sleep_ms(ms);
}

uint32_t rp2040_mmio_read(uint32_t address) {
  return *(volatile const uint32_t *)(uintptr_t)address;
}

void rp2040_mmio_write(uint32_t address, uint32_t value) {
  *(volatile uint32_t *)(uintptr_t)address = value;
}

int main(void) {
  swift_main();
  for (;;) {
    tight_loop_contents();
  }
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Application/Main.swift" <<'EOF'
// Minimal Swift Embedded firmware entry point.

@_cdecl("swift_main")
public func swift_main() -> Never {
  let ledPin: UInt32 = 25
  RP2040GPIO.configureAsSIOOutput(pin: ledPin)

  while true {
    RP2040GPIO.setHigh(pin: ledPin)
    pico_delay_ms(250)
    RP2040GPIO.setLow(pin: ledPin)
    pico_delay_ms(250)
  }
}

@_silgen_name("pico_delay_ms")
func pico_delay_ms(_ ms: UInt32)
EOF

  emit_template "${OUTPUT_DIR}/Sources/BoardSupport/PicoSSD1306.swift" <<'EOF'
/// Board-level wiring defaults for a four-pin 128x64 SSD1306 OLED.
///
/// Connect VCC to Pico 3V3(OUT), GND to GND, SDA to GP4, and SCL to GP5.
struct PicoSSD1306Configuration {
  let i2cAddress: UInt8
  let sdaPin: UInt32
  let sclPin: UInt32
  let i2cClockHz: UInt32

  init(
    i2cAddress: UInt8 = 0x3c,
    sdaPin: UInt32 = 4,
    sclPin: UInt32 = 5,
    i2cClockHz: UInt32 = 400_000
  ) {
    self.i2cAddress = i2cAddress
    self.sdaPin = sdaPin
    self.sclPin = sclPin
    self.i2cClockHz = i2cClockHz
  }
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Hardware/MMIO.swift" <<'EOF'
/// Minimal volatile MMIO bridge for Swift Embedded.

@_silgen_name("rp2040_mmio_read")
private func rp2040MMIORead(_ address: UInt32) -> UInt32

@_silgen_name("rp2040_mmio_write")
private func rp2040MMIOWrite(_ address: UInt32, _ value: UInt32)

@inline(__always)
func mmioRead(_ address: UInt32) -> UInt32 {
  rp2040MMIORead(address)
}

@inline(__always)
func mmioWrite(_ address: UInt32, _ value: UInt32) {
  rp2040MMIOWrite(address, value)
}

@inline(__always)
func mmioSetBits(_ address: UInt32, _ mask: UInt32) {
    let current = mmioRead(address)
    mmioWrite(address, current | mask)
}

@inline(__always)
func mmioClearBits(_ address: UInt32, _ mask: UInt32) {
    let current = mmioRead(address)
    mmioWrite(address, current & ~mask)
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Application/Samples/DisplaySample.swift" <<'EOF'
/// Demonstrates a 128x64 SSD1306 OLED on I2C0 (GP4 SDA, GP5 SCL).
struct DisplaySample {
  func run() -> Never {
    var display = SSD1306Driver()
    if case .failure = display.initialize() {
      var alternateAddressDisplay = SSD1306Driver(
        configuration: PicoSSD1306Configuration(i2cAddress: 0x3d)
      )
      guard case .success = alternateAddressDisplay.initialize() else {
        displayFaultLoop(blinks: 1)
      }
      display = alternateAddressDisplay
    }

    pico_delay_ms(2_000)
    display.clear()
    display.setCursor(x: 4, y: 4)
    display.drawText("Hello Swift Embedded")
    display.drawLine(x0: 0, y0: 16, x1: 127, y1: 16)
    display.drawRect(x: 4, y: 24, width: 34, height: 28)
    display.fillRect(x: 44, y: 30, width: 24, height: 18)
    display.drawCircle(x: 93, y: 38, radius: 13)
    display.fillCircle(x: 116, y: 51, radius: 8)

    guard case .success = display.flush() else { displayFaultLoop(blinks: 2) }
    while true {}
  }

  private func displayFaultLoop(blinks: UInt32) -> Never {
    let ledPin: UInt32 = 25
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)
    while true {
      for _ in 0..<blinks {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(120)
        RP2040GPIO.setLow(pin: ledPin)
        pico_delay_ms(180)
      }
      pico_delay_ms(1_000)
    }
  }
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Display/SSD1306Driver.swift" <<'EOF'
/// SSD1306 128x64 I2C display driver backed by a SwiftGFX canvas.
struct SSD1306Driver {
  private static let commandControl: UInt8 = 0x00
  private static let dataControl: UInt8 = 0x40
  private static let transferPayloadSize = 15

  private let configuration: PicoSSD1306Configuration
  private(set) var graphics = SwiftGFX()

  init(configuration: PicoSSD1306Configuration = PicoSSD1306Configuration()) {
    self.configuration = configuration
  }

  mutating func initialize() -> Result<Void, RP2040I2C.Error> {
    switch RP2040I2C.initialize(
      sdaPin: configuration.sdaPin,
      sclPin: configuration.sclPin,
      clockHz: configuration.i2cClockHz,
      targetAddress: configuration.i2cAddress
    ) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    return sendCommands([
      0xae, 0xd5, 0x80, 0xa8, 0x3f, 0xd3, 0x00, 0x40,
      0x8d, 0x14, 0x20, 0x00, 0xa1, 0xc8, 0xda, 0x12,
      0x81, 0xcf, 0xd9, 0xf1, 0xdb, 0x40, 0xa4, 0xa6,
      0x2e, 0xaf
    ])
  }

  mutating func clear() { graphics.clear() }
  mutating func setCursor(x: Int, y: Int) { graphics.setCursor(x: x, y: y) }
  mutating func drawText(_ text: String, color: SwiftGFX.Color = .on) { graphics.drawText(text, color: color) }
  mutating func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, color: SwiftGFX.Color = .on) { graphics.drawLine(x0: x0, y0: y0, x1: x1, y1: y1, color: color) }
  mutating func drawRect(x: Int, y: Int, width: Int, height: Int, color: SwiftGFX.Color = .on) { graphics.drawRect(x: x, y: y, width: width, height: height, color: color) }
  mutating func fillRect(x: Int, y: Int, width: Int, height: Int, color: SwiftGFX.Color = .on) { graphics.fillRect(x: x, y: y, width: width, height: height, color: color) }
  mutating func drawCircle(x: Int, y: Int, radius: Int, color: SwiftGFX.Color = .on) { graphics.drawCircle(x: x, y: y, radius: radius, color: color) }
  mutating func fillCircle(x: Int, y: Int, radius: Int, color: SwiftGFX.Color = .on) { graphics.fillCircle(x: x, y: y, radius: radius, color: color) }

  mutating func flush() -> Result<Void, RP2040I2C.Error> {
    switch sendCommands([0x21, 0, 127, 0x22, 0, 7]) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    var start = 0
    while start < graphics.buffer.count {
      let end = min(start + Self.transferPayloadSize, graphics.buffer.count)
      let chunk = Array(graphics.buffer[start..<end])
      switch RP2040I2C.write(address: configuration.i2cAddress, control: Self.dataControl, bytes: chunk) {
      case .success: start = end
      case .failure(let error): return .failure(error)
      }
    }
    return .success(())
  }

  private func sendCommands(_ commands: [UInt8]) -> Result<Void, RP2040I2C.Error> {
    RP2040I2C.write(address: configuration.i2cAddress, control: Self.commandControl, bytes: commands)
  }
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Graphics/SwiftGFX.swift" <<'EOF'
/// A compact, page-addressed 128x64 one-bit graphics canvas.
struct SwiftGFX {
  enum Color { case off, on, invert }

  static let width = 128
  static let height = 64
  static let bufferSize = width * height / 8

  private(set) var buffer = [UInt8](repeating: 0, count: bufferSize)
  private var cursorX = 0
  private var cursorY = 0
  private var textScale = 1

  mutating func clear(_ color: Color = .off) {
    let fill: UInt8 = color == .on ? 0xff : 0
    for index in buffer.indices { buffer[index] = fill }
  }

  mutating func drawPixel(x: Int, y: Int, color: Color = .on) {
    guard x >= 0, x < Self.width, y >= 0, y < Self.height else { return }
    let index = x + (y >> 3) * Self.width
    let mask = UInt8(1 << (y & 7))
    switch color {
    case .off: buffer[index] &= ~mask
    case .on: buffer[index] |= mask
    case .invert: buffer[index] ^= mask
    }
  }

  mutating func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, color: Color = .on) {
    var currentX = x0
    var currentY = y0
    let deltaX = abs(x1 - x0)
    let stepX = x0 < x1 ? 1 : -1
    let deltaY = -abs(y1 - y0)
    let stepY = y0 < y1 ? 1 : -1
    var error = deltaX + deltaY
    while true {
      drawPixel(x: currentX, y: currentY, color: color)
      if currentX == x1 && currentY == y1 { return }
      let twiceError = error * 2
      if twiceError >= deltaY { error += deltaY; currentX += stepX }
      if twiceError <= deltaX { error += deltaX; currentY += stepY }
    }
  }

  mutating func drawRect(x: Int, y: Int, width: Int, height: Int, color: Color = .on) {
    guard width > 0, height > 0 else { return }
    drawLine(x0: x, y0: y, x1: x + width - 1, y1: y, color: color)
    drawLine(x0: x, y0: y + height - 1, x1: x + width - 1, y1: y + height - 1, color: color)
    drawLine(x0: x, y0: y, x1: x, y1: y + height - 1, color: color)
    drawLine(x0: x + width - 1, y0: y, x1: x + width - 1, y1: y + height - 1, color: color)
  }

  mutating func fillRect(x: Int, y: Int, width: Int, height: Int, color: Color = .on) {
    guard width > 0, height > 0 else { return }
    for row in 0..<height { drawLine(x0: x, y0: y + row, x1: x + width - 1, y1: y + row, color: color) }
  }

  mutating func drawCircle(x: Int, y: Int, radius: Int, color: Color = .on) {
    guard radius >= 0 else { return }
    var offsetX = radius
    var offsetY = 0
    var error = 1 - radius
    while offsetX >= offsetY {
      drawPixel(x: x + offsetX, y: y + offsetY, color: color)
      drawPixel(x: x + offsetY, y: y + offsetX, color: color)
      drawPixel(x: x - offsetY, y: y + offsetX, color: color)
      drawPixel(x: x - offsetX, y: y + offsetY, color: color)
      drawPixel(x: x - offsetX, y: y - offsetY, color: color)
      drawPixel(x: x - offsetY, y: y - offsetX, color: color)
      drawPixel(x: x + offsetY, y: y - offsetX, color: color)
      drawPixel(x: x + offsetX, y: y - offsetY, color: color)
      offsetY += 1
      if error < 0 { error += 2 * offsetY + 1 } else { offsetX -= 1; error += 2 * (offsetY - offsetX) + 1 }
    }
  }

  mutating func fillCircle(x: Int, y: Int, radius: Int, color: Color = .on) {
    guard radius >= 0 else { return }
    for offsetY in -radius...radius {
      let squared = radius * radius - offsetY * offsetY
      var offsetX = 0
      while (offsetX + 1) * (offsetX + 1) <= squared { offsetX += 1 }
      drawLine(x0: x - offsetX, y0: y + offsetY, x1: x + offsetX, y1: y + offsetY, color: color)
    }
  }

  mutating func setCursor(x: Int, y: Int) { cursorX = x; cursorY = y }
  mutating func setTextScale(_ scale: Int) { textScale = max(scale, 1) }

  mutating func drawText(_ text: String, color: Color = .on) {
    for character in text.utf8 {
      if character == 10 {
        cursorX = 0
        cursorY += 8 * textScale
      } else {
        drawCharacter(character, x: cursorX, y: cursorY, color: color)
        cursorX += 6 * textScale
      }
    }
  }

  private mutating func drawCharacter(_ character: UInt8, x: Int, y: Int, color: Color) {
    let columns = glyphColumns(for: character)
    for column in 0..<5 {
      for row in 0..<7 where (columns[column] & UInt8(1 << row)) != 0 {
        fillRect(x: x + column * textScale, y: y + row * textScale, width: textScale, height: textScale, color: color)
      }
    }
  }

  private func glyphColumns(for character: UInt8) -> [UInt8] {
    let uppercase = character >= 97 && character <= 122 ? character - 32 : character
    switch uppercase {
    case 32: return [0, 0, 0, 0, 0]
    case 45: return [8, 8, 8, 8, 8]
    case 48: return [62, 81, 73, 69, 62]
    case 49: return [0, 66, 127, 64, 0]
    case 50: return [66, 97, 81, 73, 70]
    case 51: return [33, 65, 69, 75, 49]
    case 52: return [24, 20, 18, 127, 16]
    case 53: return [39, 69, 69, 69, 57]
    case 54: return [60, 74, 73, 73, 48]
    case 55: return [1, 113, 9, 5, 3]
    case 56: return [54, 73, 73, 73, 54]
    case 57: return [6, 73, 73, 41, 30]
    case 65: return [126, 17, 17, 17, 126]
    case 66: return [127, 73, 73, 73, 54]
    case 67: return [62, 65, 65, 65, 34]
    case 68: return [127, 65, 65, 34, 28]
    case 69: return [127, 73, 73, 73, 65]
    case 70: return [127, 9, 9, 9, 1]
    case 71: return [62, 65, 73, 73, 122]
    case 72: return [127, 8, 8, 8, 127]
    case 73: return [0, 65, 127, 65, 0]
    case 74: return [32, 64, 65, 63, 1]
    case 75: return [127, 8, 20, 34, 65]
    case 76: return [127, 64, 64, 64, 64]
    case 77: return [127, 2, 12, 2, 127]
    case 78: return [127, 4, 8, 16, 127]
    case 79: return [62, 65, 65, 65, 62]
    case 80: return [127, 9, 9, 9, 6]
    case 81: return [62, 65, 81, 33, 94]
    case 82: return [127, 9, 25, 41, 70]
    case 83: return [70, 73, 73, 73, 49]
    case 84: return [1, 1, 127, 1, 1]
    case 85: return [63, 64, 64, 64, 63]
    case 86: return [31, 32, 64, 32, 31]
    case 87: return [127, 32, 24, 32, 127]
    case 88: return [99, 20, 8, 20, 99]
    case 89: return [3, 4, 120, 4, 3]
    case 90: return [97, 81, 73, 69, 67]
    default: return [2, 1, 89, 9, 6]
    }
  }
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Hardware/RP2040I2C.swift" <<'EOF'
/// RP2040 I2C0 master transport for I2C devices such as an SSD1306 OLED.
enum RP2040I2C {
  enum Error: Swift.Error {
    case invalidPins
    case invalidClock
    case timeout
    case aborted(UInt32)
  }

  private static let base: UInt32 = 0x4004_4000
  private static let resetsBase: UInt32 = 0x4000_c000
  private static let resetOffset: UInt32 = 0x00
  private static let resetDoneOffset: UInt32 = 0x08
  private static let resetBit: UInt32 = 1 << 3
  private static let conOffset: UInt32 = 0x00
  private static let tarOffset: UInt32 = 0x04
  private static let dataCmdOffset: UInt32 = 0x10
  private static let fsSclHcntOffset: UInt32 = 0x1c
  private static let fsSclLcntOffset: UInt32 = 0x20
  private static let rawIntrStatOffset: UInt32 = 0x34
  private static let rxTlOffset: UInt32 = 0x38
  private static let txTlOffset: UInt32 = 0x3c
  private static let clrTxAbrtOffset: UInt32 = 0x54
  private static let clrStopDetOffset: UInt32 = 0x60
  private static let enableOffset: UInt32 = 0x6c
  private static let txFlrOffset: UInt32 = 0x74
  private static let sdaHoldOffset: UInt32 = 0x7c
  private static let txAbrtSourceOffset: UInt32 = 0x80
  private static let dmaCrOffset: UInt32 = 0x88
  private static let enableStatusOffset: UInt32 = 0x9c
  private static let fsSpklenOffset: UInt32 = 0xa0

  private static let conMasterMode: UInt32 = 1 << 0
  private static let conSpeedFast: UInt32 = 2 << 1
  private static let conRestartEnable: UInt32 = 1 << 5
  private static let conSlaveDisable: UInt32 = 1 << 6
  private static let conTransmitEmptyControl: UInt32 = 1 << 8
  private static let dataCmdStop: UInt32 = 1 << 9
  private static let rawInterruptStopDetected: UInt32 = 1 << 9
  private static let rawInterruptTransmitAbort: UInt32 = 1 << 6
  private static let rawInterruptTransmitEmpty: UInt32 = 1 << 4
  private static let i2cFunction: UInt32 = 3
  private static let systemClockHz: UInt32 = 125_000_000
  private static let pollLimit = 1_000_000

  static func initialize(
    sdaPin: UInt32,
    sclPin: UInt32,
    clockHz: UInt32,
    targetAddress: UInt8
  ) -> Result<Void, Error> {
    guard isI2C0Pair(sda: sdaPin, scl: sclPin) else { return .failure(.invalidPins) }
    guard clockHz > 0, clockHz <= 400_000, targetAddress <= 0x7f else {
      return .failure(.invalidClock)
    }

    mmioSetBits(resetsBase + resetOffset, resetBit)
    mmioClearBits(resetsBase + resetOffset, resetBit)
    while (mmioRead(resetsBase + resetDoneOffset) & resetBit) == 0 {}

    RP2040GPIO.enablePadPullUp(pin: sdaPin)
    RP2040GPIO.enablePadPullUp(pin: sclPin)
    RP2040GPIO.setFunction(pin: sdaPin, funcSel: i2cFunction)
    RP2040GPIO.setFunction(pin: sclPin, funcSel: i2cFunction)

    mmioWrite(base + enableOffset, 0)
    guard waitForDisabled() else { return .failure(.timeout) }

    let periodTicks = (systemClockHz + clockHz / 2) / clockHz
    let lowCount = periodTicks * 3 / 5
    let highCount = periodTicks - lowCount
    let sdaHoldCount = ((systemClockHz * 3) / 10_000_000) + 1
    mmioWrite(base + fsSclHcntOffset, highCount)
    mmioWrite(base + fsSclLcntOffset, lowCount)
    mmioWrite(base + fsSpklenOffset, max(lowCount / 16, 1))
    mmioWrite(base + sdaHoldOffset, sdaHoldCount)
    mmioWrite(base + rxTlOffset, 0)
    mmioWrite(base + txTlOffset, 0)
    mmioWrite(base + dmaCrOffset, 0x3)
    mmioWrite(base + conOffset, conMasterMode | conSpeedFast | conRestartEnable | conSlaveDisable | conTransmitEmptyControl)
    mmioWrite(base + tarOffset, UInt32(targetAddress))
    mmioWrite(base + enableOffset, 1)
    clearInterruptState()
    return .success(())
  }

  static func write(address: UInt8, control: UInt8, bytes: [UInt8]) -> Result<Void, Error> {
    guard address <= 0x7f else { return .failure(.invalidClock) }
    guard selectTarget(address) else { return .failure(.timeout) }
    clearInterruptState()

    let totalCount = bytes.count + 1
    for index in 0..<totalCount {
      let value = index == 0 ? control : bytes[index - 1]
      let stop = index == totalCount - 1 ? dataCmdStop : 0
      mmioWrite(base + dataCmdOffset, UInt32(value) | stop)
      switch waitForTransmitComplete() {
      case .success: break
      case .failure(let error): return .failure(error)
      }
    }

    guard waitForStop() else { return .failure(.timeout) }
    _ = mmioRead(base + clrStopDetOffset)
    return .success(())
  }

  private static func isI2C0Pair(sda: UInt32, scl: UInt32) -> Bool {
    (sda == 0 && scl == 1) || (sda == 4 && scl == 5) ||
      (sda == 8 && scl == 9) || (sda == 12 && scl == 13) ||
      (sda == 16 && scl == 17) || (sda == 20 && scl == 21)
  }

  private static func waitForDisabled() -> Bool {
    for _ in 0..<pollLimit where (mmioRead(base + enableStatusOffset) & 1) == 0 { return true }
    return false
  }

  private static func selectTarget(_ address: UInt8) -> Bool {
    mmioWrite(base + enableOffset, 0)
    guard waitForDisabled() else { return false }
    mmioWrite(base + tarOffset, UInt32(address))
    mmioWrite(base + enableOffset, 1)
    return true
  }

  private static func waitForTransmitComplete() -> Result<Void, Error> {
    for _ in 0..<pollLimit {
      let interrupts = mmioRead(base + rawIntrStatOffset)
      if (interrupts & rawInterruptTransmitAbort) != 0 { return .failure(readAndClearAbort()) }
      if (interrupts & rawInterruptTransmitEmpty) != 0 { return .success(()) }
    }
    return .failure(.timeout)
  }

  private static func waitForStop() -> Bool {
    for _ in 0..<pollLimit {
      let interrupts = mmioRead(base + rawIntrStatOffset)
      if (interrupts & rawInterruptTransmitAbort) != 0 { return false }
      if (interrupts & rawInterruptStopDetected) != 0 { return true }
    }
    return false
  }

  private static func readAndClearAbort() -> Error {
    let abortSource = mmioRead(base + txAbrtSourceOffset)
    _ = mmioRead(base + clrTxAbrtOffset)
    return .aborted(abortSource)
  }

  private static func clearInterruptState() {
    _ = mmioRead(base + clrTxAbrtOffset)
    _ = mmioRead(base + clrStopDetOffset)
    while mmioRead(base + txFlrOffset) != 0 {}
  }
}
EOF

  emit_template "${OUTPUT_DIR}/Sources/Hardware/RP2040GPIO.swift" <<'EOF'
// RP2040 GPIO driver using direct MMIO.
// Extension point: add UART/I2C/SPI setup routines in this layer.

enum RP2040GPIO {
    private static let resetsBase: UInt32 = 0x4000_c000
    private static let ioBank0Base: UInt32 = 0x4001_4000
    private static let padsBank0Base: UInt32 = 0x4001_c000
    private static let sioBase: UInt32 = 0xd000_0000

    private static let resetsResetOffset: UInt32 = 0x00
    private static let resetsResetDoneOffset: UInt32 = 0x08

    private static let sioGPIOOutSetOffset: UInt32 = 0x14
    private static let sioGPIOOutClrOffset: UInt32 = 0x18
    private static let sioGPIOOESetOffset: UInt32 = 0x24

    private static let funcSelSIO: UInt32 = 0x5

    private static let resetIOBank0Bit: UInt32 = 1 << 5
    private static let resetPadsBank0Bit: UInt32 = 1 << 8
    private static let padPUEBit: UInt32 = 1 << 3
    private static let padPDEBit: UInt32 = 1 << 2

    @inline(__always)
    private static func ioGPIOCtrlAddress(pin: UInt32) -> UInt32 {
        ioBank0Base + 0x004 + (pin * 8)
    }

    @inline(__always)
    private static func padsGPIOAddress(pin: UInt32) -> UInt32 {
        padsBank0Base + 0x004 + (pin * 4)
    }

    static func setFunction(pin: UInt32, funcSel: UInt32) {
      mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSel)
    }

    static func enablePadPullUp(pin: UInt32) {
      let resetMask = resetIOBank0Bit | resetPadsBank0Bit
      mmioClearBits(resetsBase + resetsResetOffset, resetMask)
      while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

      let padAddress = padsGPIOAddress(pin: pin)
      var value = mmioRead(padAddress)
      value |= padPUEBit
      value &= ~padPDEBit
      mmioWrite(padAddress, value)
    }

    static func configureAsSIOOutput(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)

        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

        let padAddress = padsGPIOAddress(pin: pin)
        mmioWrite(padAddress, mmioRead(padAddress))

        mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
        mmioWrite(sioBase + sioGPIOOESetOffset, 1 << pin)
    }

    @inline(__always)
    static func setHigh(pin: UInt32) {
        mmioWrite(sioBase + sioGPIOOutSetOffset, 1 << pin)
    }

    @inline(__always)
    static func setLow(pin: UInt32) {
        mmioWrite(sioBase + sioGPIOOutClrOffset, 1 << pin)
    }
}
EOF

  emit_template "${OUTPUT_DIR}/Scripts/init.sh" <<'EOF'
#!/usr/bin/env bash
# One-time macOS project bootstrap for Swift Embedded + Raspberry Pi Pico SDK.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_ROOT}/.tools"
PICO_SDK_PATH_DEFAULT="${PROJECT_ROOT}/.deps/pico-sdk"
PICO_SDK_PATH="${PICO_SDK_PATH:-$PICO_SDK_PATH_DEFAULT}"
PICO_SDK_REF="${PICO_SDK_REF:-__PICO_SDK_REF__}"
SWIFTLY_CHANNEL="${SWIFTLY_CHANNEL:-__SWIFTLY_CHANNEL__}"

log() { printf "==> %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }
fail() { printf "❌ %s\n" "$*"; exit 1; }

print_usage() {
  cat <<'USAGE'
Usage: Scripts/init.sh [--sdk-ref <ref>] [--help]

Options:
  --sdk-ref <ref>  Pico SDK branch/tag/commit-ish (default from generator).
  --help           Show this help text and exit.
USAGE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --sdk-ref)
        shift
        [ "$#" -gt 0 ] || fail "--sdk-ref requires a value"
        PICO_SDK_REF="$1"
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1 (use --help)"
        ;;
    esac
    shift
  done
}

ensure_brew() {
  command -v brew >/dev/null 2>&1 || fail "Homebrew is required. Install from https://brew.sh and re-run."
}

ensure_brew_pkg() {
  local pkg="$1"
  if brew list --versions "$pkg" >/dev/null 2>&1; then
    log "Homebrew package already present: $pkg"
  else
    log "Installing Homebrew package: $pkg"
    brew install "$pkg"
  fi
}

ensure_arm_toolchain() {
  if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
    log "ARM GNU toolchain already present: $(command -v arm-none-eabi-gcc)"
    return
  fi
  ensure_brew_pkg arm-none-eabi-gcc
}

ensure_swift_toolchain() {
  if command -v swiftc >/dev/null 2>&1; then
    if swiftc --version | grep -q "Swift version 6"; then
      log "Swift 6 toolchain detected: $(swiftc --version | head -n1)"
      return
    fi
    warn "swiftc exists but is not Swift 6; provisioning via swiftly."
  else
    warn "swiftc not found; provisioning via swiftly."
  fi

  ensure_brew_pkg swiftly

  if ! swiftly list >/dev/null 2>&1; then
    log "Initializing swiftly for the current user"
    swiftly init --assume-yes --no-modify-profile --quiet-shell-followup >/dev/null
  fi

  if ! swiftly list 2>/dev/null | grep -q "${SWIFTLY_CHANNEL}"; then
    log "Installing Swift toolchain with swiftly channel: ${SWIFTLY_CHANNEL}"
    swiftly install "${SWIFTLY_CHANNEL}" --assume-yes || fail "swiftly install failed."
  else
    log "swiftly channel already installed: ${SWIFTLY_CHANNEL}"
  fi

  log "Selecting swiftly channel: ${SWIFTLY_CHANNEL}"
  swiftly use "${SWIFTLY_CHANNEL}" || fail "swiftly use failed."

  command -v swiftc >/dev/null 2>&1 || fail "swiftc still unavailable after swiftly setup."
  swiftc --version | grep -q "Swift version 6" || fail "Active swiftc is not Swift 6 after swiftly setup."
  log "Active Swift toolchain: $(swiftc --version | head -n1)"
}

ensure_pico_sdk() {
  mkdir -p "$(dirname "${PICO_SDK_PATH}")"
  if [ -d "${PICO_SDK_PATH}/.git" ]; then
    log "Updating pico-sdk in ${PICO_SDK_PATH}"
    git -C "${PICO_SDK_PATH}" fetch --quiet origin
    git -C "${PICO_SDK_PATH}" checkout --quiet "${PICO_SDK_REF}"
    git -C "${PICO_SDK_PATH}" pull --ff-only --quiet origin "${PICO_SDK_REF}"
    git -C "${PICO_SDK_PATH}" submodule update --init --recursive --quiet
  else
    log "Cloning pico-sdk (${PICO_SDK_REF}) to ${PICO_SDK_PATH}"
    git clone --depth 1 --branch "${PICO_SDK_REF}" https://github.com/raspberrypi/pico-sdk.git "${PICO_SDK_PATH}"
    git -C "${PICO_SDK_PATH}" submodule update --init --recursive --quiet
  fi
}

ensure_elf2uf2() {
  mkdir -p "${TOOLS_DIR}"
  local output="${TOOLS_DIR}/elf2uf2"
  ensure_brew_pkg picotool

  cat > "${output}" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  printf "Usage: elf2uf2 <input.elf> <output.uf2>\n" >&2
  exit 2
fi
exec picotool uf2 convert "$1" "$2"
WRAP
  chmod +x "${output}"
}

write_env_file() {
  cat > "${PROJECT_ROOT}/Scripts/env.sh" <<ENVVARS
#!/usr/bin/env bash
# Auto-generated by Scripts/init.sh.
export PICO_SDK_PATH="${PICO_SDK_PATH}"
export ELF2UF2_PATH="${TOOLS_DIR}/elf2uf2"
ENVVARS
  chmod +x "${PROJECT_ROOT}/Scripts/env.sh"
}

main() {
  parse_args "$@"
  ensure_brew
  ensure_brew_pkg cmake
  ensure_brew_pkg ninja
  ensure_brew_pkg git
  ensure_arm_toolchain
  ensure_swift_toolchain
  ensure_pico_sdk
  ensure_elf2uf2
  write_env_file

  log "Initialization complete."
  log "Run: source Scripts/env.sh"
  log "Then: Scripts/run.sh"
}

main "$@"
EOF

  emit_template "${OUTPUT_DIR}/Scripts/run.sh" <<'RUN_TEMPLATE'
#!/usr/bin/env bash
# Build + package + flash workflow for Raspberry Pi Pico on macOS.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
TARGET_NAME="__TARGET_NAME__"
ELF_PATH="${BUILD_DIR}/${TARGET_NAME}.elf"
UF2_PATH="${BUILD_DIR}/${TARGET_NAME}.uf2"
SKIP_FLASH=0
FLASH_ROOT="${FLASH_ROOT:-__FLASH_VOLUME_HINT__}"
TEMP_FILES=()

print_usage() {
  cat <<'EOF_USAGE'
Usage: Scripts/run.sh [--no-flash] [--help]

Options:
  --no-flash  Build and create UF2, but do not copy to a Pico board.
  --help      Show this help text and exit.
EOF_USAGE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-flash) SKIP_FLASH=1 ;;
      -h|--help) print_usage; exit 0 ;;
      *) printf "❌ Unknown option: %s (use --help)\n" "$1"; exit 1 ;;
    esac
    shift
  done
}

if [ -f "${PROJECT_ROOT}/Scripts/env.sh" ]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/Scripts/env.sh"
fi

PICO_SDK_PATH="${PICO_SDK_PATH:-${PROJECT_ROOT}/.deps/pico-sdk}"
ELF2UF2_PATH="${ELF2UF2_PATH:-${PROJECT_ROOT}/.tools/elf2uf2}"

show_header() {
  cat <<'EOF'

   _____           _  __ _     _
  / ____|         (_)/ _| |   | |
 | (___  __      ___| |_| |_  | | _____   _____  ___
  \___ \ \ \ /\ / / |  _| __| | |/ _ \ \ / / _ \/ __|
  ____) | \ V  V /| | | | |_  | | (_) \ V /  __/\__ \
 |_____/   \_/\_/ |_|_|  \__| |_|\___/ \_/ \___||___/

  _____  _
 |  __ \(_)
 | |__) |_  ___ ___
 |  ___/| |/ __/ _ \
 | |    | | (_| (_) |
 |_|    |_|\___\___/

EOF
}

log() { printf "==> %s\n" "$*"; }
fail() { printf "❌ %s\n" "$*"; exit 1; }

cleanup_temp_files() {
  local temp_file
  for temp_file in "${TEMP_FILES[@]-}"; do
    [ -n "${temp_file}" ] && rm -f "${temp_file}"
  done
}
trap cleanup_temp_files EXIT INT TERM

run_quiet() {
  local log_file
  log_file="$(mktemp)"
  TEMP_FILES+=("${log_file}")
  if "$@" >"${log_file}" 2>&1; then
    rm -f "${log_file}"
    return 0
  fi
  cat "${log_file}" >&2
  rm -f "${log_file}"
  return 1
}

detect_pico_mount() {
  local volume
  for volume in "${FLASH_ROOT}"/*; do
    [ -d "${volume}" ] || continue
    if [ -f "${volume}/INFO_UF2.TXT" ]; then
      printf "%s" "${volume}"
      return 0
    fi
  done
  return 1
}

ensure_prerequisites() {
  command -v cmake >/dev/null 2>&1 || fail "cmake not found. Run Scripts/init.sh."
  command -v ninja >/dev/null 2>&1 || fail "ninja not found. Run Scripts/init.sh."
  command -v swiftc >/dev/null 2>&1 || fail "swiftc not found. Run Scripts/init.sh."
  [ -d "${PICO_SDK_PATH}" ] || fail "Pico SDK missing at ${PICO_SDK_PATH}. Run Scripts/init.sh."
  [ -x "${ELF2UF2_PATH}" ] || fail "elf2uf2 missing at ${ELF2UF2_PATH}. Run Scripts/init.sh."
}

build_firmware() {
  log "Cleaning prior build output"
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}"

  log "Configuring CMake build"
  run_quiet cmake -S "${PROJECT_ROOT}" -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${PROJECT_ROOT}/CMake/arm-none-eabi-toolchain.cmake" \
    -DPICO_SDK_PATH="${PICO_SDK_PATH}" \
    -DSWIFT_EXECUTABLE="$(command -v swiftc)"

  log "Building firmware"
  run_quiet cmake --build "${BUILD_DIR}" --target "${TARGET_NAME}"
}

convert_to_uf2() {
  [ -f "${ELF_PATH}" ] || fail "ELF not found: ${ELF_PATH}"
  log "Converting ELF to UF2"
  run_quiet "${ELF2UF2_PATH}" "${ELF_PATH}" "${UF2_PATH}"
  [ -f "${UF2_PATH}" ] || fail "UF2 conversion failed."
}

flash_uf2() {
  local mount_point
  if ! mount_point="$(detect_pico_mount)"; then
    fail "No Pico UF2 mount found under ${FLASH_ROOT}. Hold BOOTSEL while connecting the board."
  fi
  log "Copying UF2 to ${mount_point}"
  cp -X "${UF2_PATH}" "${mount_point}/"
  sync
  log "Flash complete: ${UF2_PATH} -> ${mount_point}"
}

main() {
  parse_args "$@"
  show_header
  printf '\n\n'
  ensure_prerequisites
  build_firmware
  convert_to_uf2

  if [ "${SKIP_FLASH}" -eq 0 ]; then
    flash_uf2
    log "Success. The Pico should now run the Swift blink firmware."
  else
    log "Build finished. Flash was skipped because --no-flash was used."
    log "The UF2 file is ready at ${UF2_PATH}."
  fi
}

main "$@"
RUN_TEMPLATE

  emit_template "${OUTPUT_DIR}/README.md" <<'EOF'
# __PROJECT_NAME__

Generated Swift 6 Embedded starter for Raspberry Pi Pico (RP2040).

## Included

- Modular source layout (`Sources/Application`, `Sources/BoardSupport`, `Sources/Display`, `Sources/Graphics`, `Sources/Hardware`)
- Pico C-SDK integration through CMake
- SSD1306 128x64 OLED demonstration with an I2C0 transport and one-bit graphics canvas
- `Scripts/init.sh` for toolchain + SDK setup
- `Scripts/run.sh` for build, UF2 conversion, and optional flashing

## Quick start (macOS)

1. Run setup:

   ```bash
   Scripts/init.sh
   ```

2. (Optional) load local environment:

   ```bash
   source Scripts/env.sh
   ```

3. Build and flash:

   ```bash
   Scripts/run.sh
   ```

4. Build only (no board required):

   ```bash
   Scripts/run.sh --no-flash
   ```

  ## SSD1306 OLED

  The generated firmware displays a basic graphics demonstration on a four-pin
  128x64 SSD1306 module. Connect the display as follows:

  | OLED pin | Raspberry Pi Pico pin |
  | --- | --- |
  | VCC | 3V3(OUT) |
  | GND | GND |
  | SDA | GP4 |
  | SCL | GP5 |

  The driver tries I2C addresses `0x3C` and `0x3D`. Its defaults are in
  `Sources/BoardSupport/PicoSSD1306.swift`. The generated I2C transport uses
  I2C0, so valid alternate pairs are GP0/GP1, GP4/GP5, GP8/GP9, GP12/GP13,
  GP16/GP17, and GP20/GP21.

## Customization points

- Change target binary name in `CMakeLists.txt` and `Scripts/run.sh`.
  - Keep display address and I2C0 wiring in `Sources/BoardSupport/PicoSSD1306.swift`.
  - Extend `Sources/Graphics/SwiftGFX.swift` or add display drivers in `Sources/Display`.
  - Add drivers in `Sources/Hardware` (`UART`, additional I2C buses, `SPI`).
- Add future Swift Embedded dependencies in `Package.swift`.

## Notes

- Default Pico SDK ref: `__PICO_SDK_REF__`
- Default swiftly channel: `__SWIFTLY_CHANNEL__`
- Default flash volume root used by `run.sh`: `__FLASH_VOLUME_HINT__`
EOF

  if [ "${INCLUDE_CI}" -eq 1 ]; then
    emit_template "${OUTPUT_DIR}/.github/workflows/linux-build-no-flash.yml" <<'EOF'
name: Linux build (no flash)

on:
  push:
    branches:
      - main

jobs:
  build-no-flash:
    runs-on: ubuntu-latest
    env:
      PICO_SDK_PATH: ${{ github.workspace }}/.deps/pico-sdk
      ELF2UF2_PATH: ${{ github.workspace }}/.tools/elf2uf2

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Swift 6
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.0"

      - name: Install Linux build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            cmake \
            ninja-build \
            git \
            gcc-arm-none-eabi \
            libnewlib-arm-none-eabi \
            pkg-config \
            libusb-1.0-0-dev

      - name: Fetch Pico SDK
        run: |
          mkdir -p .deps
          if [ -d ".deps/pico-sdk/.git" ]; then
            git -C .deps/pico-sdk fetch --quiet origin
            git -C .deps/pico-sdk checkout --quiet master
            git -C .deps/pico-sdk pull --ff-only --quiet origin master
          else
            git clone --depth 1 --branch master https://github.com/raspberrypi/pico-sdk.git .deps/pico-sdk
          fi
          git -C .deps/pico-sdk submodule update --init --recursive --quiet

      - name: Build picotool and create elf2uf2 wrapper
        run: |
          git clone --depth 1 https://github.com/raspberrypi/picotool.git /tmp/picotool
          cmake -S /tmp/picotool -B /tmp/picotool/build -G Ninja
          cmake --build /tmp/picotool/build --target picotool
          mkdir -p .tools
          cat > .tools/elf2uf2 <<'WRAP'
          #!/usr/bin/env bash
          set -euo pipefail
          if [ "$#" -ne 2 ]; then
            printf "Usage: elf2uf2 <input.elf> <output.uf2>\n" >&2
            exit 2
          fi
          exec /tmp/picotool/build/picotool uf2 convert "$1" "$2"
          WRAP
          chmod +x .tools/elf2uf2

      - name: Build firmware in no-flash mode
        run: |
          chmod +x Scripts/run.sh
          Scripts/run.sh --no-flash
EOF
  fi

  chmod +x "${OUTPUT_DIR}/Scripts/init.sh"
  chmod +x "${OUTPUT_DIR}/Scripts/run.sh"
}

# Executes optional post-generation actions (none, setup, or setup+build).
run_post_action() {
  local action="${POST_ACTION}"

  if [ "${action}" = "ask" ]; then
    if [ "${NON_INTERACTIVE}" -eq 1 ]; then
      action="none"
    else
      printf "\n%sPost-generation action%s\n" "${C_BOLD}" "${C_RESET}"
      printf "1) Do nothing now\n"
      printf "2) Run setup (Scripts/init.sh)\n"
      printf "3) Run setup + build (Scripts/run.sh --no-flash)\n"
      local choice
      read -r -p "Choose [1-3, default 1]: " choice || true
      case "${choice:-1}" in
        2) action="init" ;;
        3) action="build" ;;
        *) action="none" ;;
      esac
    fi
  fi

  case "${action}" in
    none)
      ok "Project generated. No post-action selected."
      ;;
    init)
      log "Running generated setup script..."
      (cd "${OUTPUT_DIR}" && ./Scripts/init.sh)
      ok "Setup completed."
      ;;
    build)
      log "Running generated setup script..."
      (cd "${OUTPUT_DIR}" && ./Scripts/init.sh)
      log "Running generated no-flash build..."
      (cd "${OUTPUT_DIR}" && ./Scripts/run.sh --no-flash)
      ok "Setup and no-flash build completed."
      ;;
    *)
      fail "Invalid post action: ${action}"
      ;;
  esac
}

# Prints a human-readable summary of the chosen generator configuration.
print_summary() {
  printf "\n%sConfiguration summary%s\n" "${C_BOLD}" "${C_RESET}"
  printf "  Project name     : %s\n" "${PROJECT_NAME}"
  printf "  Package name     : %s\n" "${PACKAGE_NAME}"
  printf "  Output directory : %s\n" "${OUTPUT_DIR}"
  printf "  Target name      : %s\n" "${TARGET_NAME}"
  printf "  Pico SDK ref     : %s\n" "${PICO_SDK_REF}"
  printf "  swiftly channel  : %s\n" "${SWIFTLY_CHANNEL}"
  printf "  Flash root hint  : %s\n" "${FLASH_VOLUME_HINT}"
  printf "  Include CI       : %s\n" "$([ "${INCLUDE_CI}" -eq 1 ] && echo "yes" || echo "no")"
  printf "  Post action      : %s\n" "${POST_ACTION}"
}

# Entry point: orchestrates parsing, prompting, generation, and optional follow-up actions.
main() {
  show_header
  parse_args "$@"
  interactive_prompts
  validate_config
  PACKAGE_NAME="$(sanitize_package_name "${PROJECT_NAME}")"
  OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"

  print_summary
  if ! confirm "Proceed with generation?" 1; then
    fail "Aborted by user."
  fi

  prepare_output_dir
  write_project_files
  run_post_action

  printf "\n"
  ok "Done. Your project is ready at: ${OUTPUT_DIR}"
  printf "Next step: cd \"%s\" && Scripts/run.sh --no-flash\n" "${OUTPUT_DIR}"
}

main "$@"
