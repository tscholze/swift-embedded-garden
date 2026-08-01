#!/usr/bin/env bash
#
# Standalone project generator for Swift Embedded + Raspberry Pi Pico.
# This script creates a complete starter project with the current scaffold.
#
set -euo pipefail

PROJECT_NAME="SwiftPicoEmbeddedGarden"
OUTPUT_DIR=""
TARGET_NAME="swift-pico-blink"
PICO_SDK_REF="master"
SWIFTLY_CHANNEL="main-snapshot"
FLASH_VOLUME_HINT="/Volumes"
INCLUDE_CI=1
FORCE_OVERWRITE=0
NON_INTERACTIVE=0
POST_ACTION="ask"

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

log() { printf "%s==>%s %s\n" "${C_CYAN}" "${C_RESET}" "$*"; }
warn() { printf "%s⚠%s %s\n" "${C_YELLOW}" "${C_RESET}" "$*"; }
ok() { printf "%s✅%s %s\n" "${C_GREEN}" "${C_RESET}" "$*"; }
fail() { printf "%s❌%s %s\n" "${C_RED}" "${C_RESET}" "$*"; exit 1; }

show_header() {
  cat <<'HEADER'

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

HEADER
}

print_usage() {
  cat <<'USAGE'
Usage: ./generate-swift-pico-project.sh [options]

Options:
  --project-name <name>        Project folder/package display name
  --output-dir <path>          Output directory for generated project
  --target-name <name>         Firmware target/binary name
  --pico-sdk-ref <ref>         Pico SDK branch/tag/commit-ish
  --swiftly-channel <name>     swiftly channel for init.sh
  --flash-volume-hint <path>   Default mount root used by run.sh
  --include-ci                 Include CI workflow (default)
  --no-include-ci              Skip CI workflow generation
  --post-action <mode>         none | init | build | ask
  --non-interactive            Disable prompts
  --force                      Allow generation into a non-empty dir
  --help                       Show this help
USAGE
}

sanitize_target_name() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-_'
}

sanitize_package_name() {
  local value
  value="$(printf "%s" "$1" | tr -cd '[:alnum:]')"
  [ -n "$value" ] || value="SwiftPicoEmbeddedGarden"
  printf "%s" "$value"
}

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

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-name)
        shift
        [ "$#" -gt 0 ] || fail "--project-name requires a value"
        PROJECT_NAME="$1"
        ;;
      --output-dir)
        shift
        [ "$#" -gt 0 ] || fail "--output-dir requires a value"
        OUTPUT_DIR="$1"
        ;;
      --target-name)
        shift
        [ "$#" -gt 0 ] || fail "--target-name requires a value"
        TARGET_NAME="$1"
        ;;
      --pico-sdk-ref)
        shift
        [ "$#" -gt 0 ] || fail "--pico-sdk-ref requires a value"
        PICO_SDK_REF="$1"
        ;;
      --swiftly-channel)
        shift
        [ "$#" -gt 0 ] || fail "--swiftly-channel requires a value"
        SWIFTLY_CHANNEL="$1"
        ;;
      --flash-volume-hint)
        shift
        [ "$#" -gt 0 ] || fail "--flash-volume-hint requires a value"
        FLASH_VOLUME_HINT="$1"
        ;;
      --include-ci) INCLUDE_CI=1 ;;
      --no-include-ci) INCLUDE_CI=0 ;;
      --post-action)
        shift
        [ "$#" -gt 0 ] || fail "--post-action requires a value"
        POST_ACTION="$1"
        ;;
      --non-interactive) NON_INTERACTIVE=1 ;;
      --force) FORCE_OVERWRITE=1 ;;
      -h|--help) print_usage; exit 0 ;;
      *) fail "Unknown option: $1 (use --help)" ;;
    esac
    shift
  done
}

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

write_project_files() {
  log "Generating project in: ${OUTPUT_DIR}"

  mkdir -p "${OUTPUT_DIR}/Sources/Application/Samples" "${OUTPUT_DIR}/Sources/Board/RP2040" "${OUTPUT_DIR}/Sources/Devices/SSD1306" "${OUTPUT_DIR}/Sources/Devices/RotaryButton" "${OUTPUT_DIR}/Scripts/hooks" "${OUTPUT_DIR}/.github/workflows" "${OUTPUT_DIR}/CMake"

  emit_template "${OUTPUT_DIR}/.gitignore" <<'TEMPLATE_GITIGNORE'
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
TEMPLATE_GITIGNORE

  emit_template "${OUTPUT_DIR}/Package.swift" <<'TEMPLATE_PACKAGE'
// swift-tools-version: 6.0
// Generated by generate-swift-pico-project.sh.
import PackageDescription

let package = Package(
  name: "__PACKAGE_NAME__",
  products: [
    .executable(name: "PicoBlink", targets: ["PicoBlink"])
  ],
  dependencies: [],
  targets: [
    .executableTarget(
      name: "PicoBlink",
      dependencies: [],
      path: "Sources",
      sources: [
        "Application",
        "Board",
        "Devices",
      ],
      swiftSettings: [
        .unsafeFlags(["-enable-experimental-feature", "Embedded"], .when(configuration: .release))
      ]
    )
  ]
)
TEMPLATE_PACKAGE

  emit_template "${OUTPUT_DIR}/CMakeLists.txt" <<'TEMPLATE_CMAKELISTS'
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
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/Sample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/TrafficLight.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/GPIOExample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/PWMDemo.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Application/Samples/DisplaySample.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SSD1306Driver.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SSD1306Renderer.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SSD1306Configuration.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/SSD1306/SwiftGFX.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/RotaryButton/RotaryButton.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/RotaryButton/RotaryButtonController.swift"
  "${CMAKE_CURRENT_LIST_DIR}/Sources/Devices/RotaryButton/RotaryButtonConfiguration.swift"
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

add_executable(__TARGET_NAME__
  CMake/bootstrap.c
  "${CMAKE_BINARY_DIR}/swift/PicoBlink.o"
)

target_link_libraries(__TARGET_NAME__
  pico_stdlib
  hardware_gpio
)

add_dependencies(__TARGET_NAME__ swift_embedded_object)
set_target_properties(__TARGET_NAME__ PROPERTIES SUFFIX ".elf")
pico_enable_stdio_uart(__TARGET_NAME__ 0)
pico_enable_stdio_usb(__TARGET_NAME__ 0)
pico_add_extra_outputs(__TARGET_NAME__)
TEMPLATE_CMAKELISTS

  emit_template "${OUTPUT_DIR}/CMake/SwiftEmbedded.cmake" <<'TEMPLATE_SWIFTEMBEDDED'
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
TEMPLATE_SWIFTEMBEDDED

  emit_template "${OUTPUT_DIR}/CMake/arm-none-eabi-toolchain.cmake" <<'TEMPLATE_TOOLCHAIN'
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
TEMPLATE_TOOLCHAIN

  emit_template "${OUTPUT_DIR}/CMake/bootstrap.c" <<'TEMPLATE_BOOTSTRAP'
#include "pico/stdlib.h"
#include <errno.h>
#include <malloc.h>
#include <stddef.h>
#include <stdint.h>

extern void swift_main(void);

int memalign_alloc(size_t alignment, size_t size, void **memptr) {
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

int main(void) {
  swift_main();
  for (;;) {
    tight_loop_contents();
  }
}
TEMPLATE_BOOTSTRAP

  emit_template "${OUTPUT_DIR}/Sources/Application/Main.swift" <<'TEMPLATE_MAIN'
@_cdecl("swift_main")
public func swift_main() -> Never {
  Sample().run()
  while true {
    // Add firmware logic here.
    _ = 0
  }
}
TEMPLATE_MAIN

  emit_template "${OUTPUT_DIR}/Sources/Application/Samples/Sample.swift" <<'TEMPLATE_SAMPLE'
struct Sample {
  func run() {
    print("Sample runtime")
  }
}
TEMPLATE_SAMPLE

  emit_template "${OUTPUT_DIR}/Sources/Application/Samples/GPIOExample.swift" <<'TEMPLATE_GPIO_SAMPLE'
struct GPIOExample {
  func run() {
    print("GPIO example")
  }
}
TEMPLATE_GPIO_SAMPLE

  emit_template "${OUTPUT_DIR}/Sources/Application/Samples/PWMDemo.swift" <<'TEMPLATE_PWM_SAMPLE'
struct PWMDemo {
  func run() {
    print("PWM demo")
  }
}
TEMPLATE_PWM_SAMPLE

  emit_template "${OUTPUT_DIR}/Sources/Application/Samples/TrafficLight.swift" <<'TEMPLATE_TRAFFIC_LIGHT'
struct TrafficLight {
  func run() {
    print("Traffic light example")
  }
}
TEMPLATE_TRAFFIC_LIGHT

  emit_template "${OUTPUT_DIR}/Sources/Application/Samples/DisplaySample.swift" <<'TEMPLATE_DISPLAY_SAMPLE'
struct DisplaySample {
  func run() {
    print("SSD1306 display example")
  }
}
TEMPLATE_DISPLAY_SAMPLE

  emit_template "${OUTPUT_DIR}/Sources/Board/RP2040/MMIO.swift" <<'TEMPLATE_MMIO'
import Swift

public enum RP2040MMIO {
  public static func read(_ address: UInt32) -> UInt32 {
    return address
  }

  public static func write(_ address: UInt32, value: UInt32) {
    _ = (address, value)
  }
}
TEMPLATE_MMIO

  emit_template "${OUTPUT_DIR}/Sources/Board/RP2040/GPIO.swift" <<'TEMPLATE_GPIO'
import Swift

public enum RP2040GPIO {
  public static func set(_ pin: UInt32, value: Bool) {
    _ = (pin, value)
  }
}
TEMPLATE_GPIO

  emit_template "${OUTPUT_DIR}/Sources/Board/RP2040/I2C.swift" <<'TEMPLATE_I2C'
import Swift

public enum RP2040I2C {
  public static func write(_ bytes: [UInt8]) {
    _ = bytes
  }
}
TEMPLATE_I2C

  emit_template "${OUTPUT_DIR}/Sources/Board/RP2040/PWM.swift" <<'TEMPLATE_PWM'
import Swift

public enum RP2040PWM {
  public static func configure(_ pin: UInt32, duty: Double) {
    _ = (pin, duty)
  }
}
TEMPLATE_PWM

  emit_template "${OUTPUT_DIR}/Sources/Devices/RotaryButton/RotaryButton.swift" <<'TEMPLATE_ROTARY_BUTTON'
struct RotaryButton {
  func run() {
    print("Rotary button")
  }
}
TEMPLATE_ROTARY_BUTTON

  emit_template "${OUTPUT_DIR}/Sources/Devices/RotaryButton/RotaryButtonController.swift" <<'TEMPLATE_ROTARY_CONTROLLER'
struct RotaryButtonController {
  func run() {
    print("Rotary button controller")
  }
}
TEMPLATE_ROTARY_CONTROLLER

  emit_template "${OUTPUT_DIR}/Sources/Devices/RotaryButton/RotaryButtonConfiguration.swift" <<'TEMPLATE_ROTARY_CONFIG'
struct RotaryButtonConfiguration {
  let pin: UInt32
}
TEMPLATE_ROTARY_CONFIG

  emit_template "${OUTPUT_DIR}/Sources/Devices/SSD1306/SSD1306Configuration.swift" <<'TEMPLATE_SSD1306_CONFIG'
struct SSD1306Configuration {
  let width: UInt32 = 128
  let height: UInt32 = 64
}
TEMPLATE_SSD1306_CONFIG

  emit_template "${OUTPUT_DIR}/Sources/Devices/SSD1306/SSD1306Driver.swift" <<'TEMPLATE_SSD1306_DRIVER'
struct SSD1306Driver {
  func run() {
    print("SSD1306 driver")
  }
}
TEMPLATE_SSD1306_DRIVER

  emit_template "${OUTPUT_DIR}/Sources/Devices/SSD1306/SSD1306Renderer.swift" <<'TEMPLATE_SSD1306_RENDERER'
struct SSD1306Renderer {
  func run() {
    print("SSD1306 renderer")
  }
}
TEMPLATE_SSD1306_RENDERER

  emit_template "${OUTPUT_DIR}/Sources/Devices/SSD1306/SwiftGFX.swift" <<'TEMPLATE_SSD1306_SWIFTGFX'
struct SwiftGFX {
  func run() {
    print("SwiftGFX example")
  }
}
TEMPLATE_SSD1306_SWIFTGFX

  emit_template "${OUTPUT_DIR}/Scripts/init.sh" <<'TEMPLATE_INIT'
#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_ROOT}/.tools"
PICO_SDK_PATH_DEFAULT="${PROJECT_ROOT}/.deps/pico-sdk"
PICO_SDK_PATH="${PICO_SDK_PATH:-$PICO_SDK_PATH_DEFAULT}"
PICO_SDK_REF="${PICO_SDK_REF:-__PICO_SDK_REF__}"
SWIFTLY_CHANNEL="${SWIFTLY_CHANNEL:-__SWIFTLY_CHANNEL__}"

log() { printf "==> %s\n" "$*"; }
fail() { printf "❌ %s\n" "$*"; exit 1; }

print_usage() {
  cat <<'EOF_USAGE'
Usage: Scripts/init.sh [--sdk-ref <ref>] [--help]

Options:
  --sdk-ref <ref>  Pico SDK git branch, tag, or commit-ish (default: __PICO_SDK_REF__).
  --help           Show this help text and exit.
EOF_USAGE
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
        fail "Unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  log "Initialization complete."
}

main "$@"
TEMPLATE_INIT

  emit_template "${OUTPUT_DIR}/Scripts/run.sh" <<'TEMPLATE_RUN'
#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
TARGET_NAME="__TARGET_NAME__"
ELF_PATH="${BUILD_DIR}/${TARGET_NAME}.elf"
UF2_PATH="${BUILD_DIR}/${TARGET_NAME}.uf2"
SKIP_FLASH=0

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
      *) fail "Unknown option: $1" ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  echo "Build finished."
}

main "$@"
TEMPLATE_RUN

  emit_template "${OUTPUT_DIR}/README.md" <<'TEMPLATE_README'
# __PROJECT_NAME__

Generated Swift 6 Embedded starter for Raspberry Pi Pico (RP2040).

## Quick start

1. Run setup:

   ```bash
   Scripts/init.sh
   ```

2. Build only (no board required):

   ```bash
   Scripts/run.sh --no-flash
   ```

3. Build and flash:

   ```bash
   Scripts/run.sh
   ```
TEMPLATE_README

  if [ "${INCLUDE_CI}" -eq 1 ]; then
    emit_template "${OUTPUT_DIR}/.github/workflows/linux-build-no-flash.yml" <<'TEMPLATE_CI'
name: Linux build (no flash)

on:
  push:
    branches:
      - main

jobs:
  build-no-flash:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with:
          swift-version: '6.0'
      - run: echo "Build placeholder"
TEMPLATE_CI
  fi

  emit_template "${OUTPUT_DIR}/Scripts/hooks/pre-commit" <<'TEMPLATE_HOOK'
#!/usr/bin/env bash
set -euo pipefail
if ! command -v swift &>/dev/null; then
  exit 0
fi

mapfile -t swift_files < <(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
for file in "${swift_files[@]}"; do
  swift format format --in-place "$file"
  git add "$file"
done
TEMPLATE_HOOK

  chmod +x "${OUTPUT_DIR}/Scripts/init.sh"
  chmod +x "${OUTPUT_DIR}/Scripts/run.sh"
  chmod +x "${OUTPUT_DIR}/Scripts/hooks/pre-commit"
}

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
