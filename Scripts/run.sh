#!/usr/bin/env bash
# Build + package + flash workflow for Raspberry Pi Pico on macOS.
# This file is intentionally heavily documented so it is easier to learn.
#
# What this script does, in order:
# 1) Remove old build output for a fresh start
# 2) Build Swift firmware with CMake + Ninja
# 3) Convert the ELF firmware into UF2 format
# 4) Optionally copy UF2 to the Pico USB drive

# Safety flags:
# -e: stop immediately when any command fails
# -u: stop when using an undefined variable
# -o pipefail: fail a pipeline when any part fails
set -euo pipefail

# ------------------------------------------------------------
# Section: constant definitions
# ------------------------------------------------------------

# Absolute path to the project root folder (one level above Scripts/).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Build output folder used by CMake.
BUILD_DIR="${PROJECT_ROOT}/build"
# Firmware target name as declared in CMake.
TARGET_NAME="swift-pico-blink"
# Final ELF firmware path produced by the build.
ELF_PATH="${BUILD_DIR}/${TARGET_NAME}.elf"
# Final UF2 firmware path produced by conversion.
UF2_PATH="${BUILD_DIR}/${TARGET_NAME}.uf2"
# Flag for optional flashing: 0 = flash, 1 = skip flash.
SKIP_FLASH=0
# List of temporary files created during this script run.
TEMP_FILES=()

# ------------------------------------------------------------
# Section: argument handling
# ------------------------------------------------------------

# Prints usage help for script options.
print_usage() {
  cat <<'EOF'
Usage: Scripts/run.sh [--no-flash] [--help]

Options:
  --no-flash  Build and create UF2, but do not copy to a Pico board.
  --help      Show this help text and exit.
EOF
}

# Reads command-line options and updates script flags.
parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --no-flash)
        SKIP_FLASH=1
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

# ------------------------------------------------------------
# Section: optional local environment overrides
# ------------------------------------------------------------

# Load custom local variables if Scripts/env.sh exists.
# This allows users to override paths without editing this script.
if [ -f "${PROJECT_ROOT}/Scripts/env.sh" ]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/Scripts/env.sh"
fi

# Path to the Pico SDK folder (override via environment if needed).
PICO_SDK_PATH="${PICO_SDK_PATH:-${PROJECT_ROOT}/.deps/pico-sdk}"
# Path to the elf2uf2 converter binary (override via environment if needed).
ELF2UF2_PATH="${ELF2UF2_PATH:-${PROJECT_ROOT}/.tools/elf2uf2}"

# ------------------------------------------------------------
# Section: user-facing banner
# ------------------------------------------------------------

# Prints a small header so users immediately see what script they ran.
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

# ------------------------------------------------------------
# Section: general helpers
# ------------------------------------------------------------

# Prints a normal progress line in a consistent format.
log() { printf "==> %s\n" "$*"; }
# Prints an error and exits with status code 1.
fail() { printf "❌ %s\n" "$*"; exit 1; }

# Deletes any known temporary files on script exit or interruption.
cleanup_temp_files() {
  local temp_file
  for temp_file in "${TEMP_FILES[@]-}"; do
    if [ -n "${temp_file}" ]; then
      rm -f "${temp_file}"
    fi
  done
  return 0
}

# Register cleanup for normal exit and Ctrl+C/termination scenarios.
trap cleanup_temp_files EXIT INT TERM

# Runs a command quietly:
# - success: hide command output to keep the terminal clean
# - failure: show captured output so the error is understandable
run_quiet() {
  # Temporary file path used to capture stdout/stderr of the command.
  local log_file
  log_file="$(mktemp)"
  TEMP_FILES+=("${log_file}")

  # Execute the incoming command ("$@") and redirect all output to file.
  if "$@" >"${log_file}" 2>&1; then
    # Command succeeded: remove temporary file and return success.
    rm -f "${log_file}"
    return 0
  fi

  # Command failed: print captured output to stderr for diagnosis.
  cat "${log_file}" >&2
  # Remove temporary file to avoid stale files in /tmp.
  rm -f "${log_file}"
  # Return non-zero so caller still fails properly.
  return 1
}

# ------------------------------------------------------------
# Section: environment checks
# ------------------------------------------------------------

# Detects the mounted Pico BOOTSEL drive by checking for INFO_UF2.TXT.
# Returns the mount path via stdout when found.
detect_pico_mount() {
  # Local loop variable containing one /Volumes/* path per iteration.
  local volume

  # Inspect each mounted macOS volume.
  for volume in /Volumes/*; do
    # Skip entries that are not directories.
    [ -d "${volume}" ] || continue
    # Pico BOOTSEL volumes include INFO_UF2.TXT at their root.
    if [ -f "${volume}/INFO_UF2.TXT" ]; then
      # Print found mount path for caller usage.
      printf "%s" "${volume}"
      return 0
    fi
  done

  # Return failure if no Pico mount was detected.
  return 1
}

# Verifies all required tools and paths are present before building.
ensure_prerequisites() {
  # Check CMake is installed and available in PATH.
  command -v cmake >/dev/null 2>&1 || fail "cmake not found. Run Scripts/init.sh."
  # Check Ninja is installed and available in PATH.
  command -v ninja >/dev/null 2>&1 || fail "ninja not found. Run Scripts/init.sh."
  # Check Swift compiler is installed and available in PATH.
  command -v swiftc >/dev/null 2>&1 || fail "swiftc not found. Run Scripts/init.sh."
  # Check Pico SDK folder exists.
  [ -d "${PICO_SDK_PATH}" ] || fail "Pico SDK missing at ${PICO_SDK_PATH}. Run Scripts/init.sh."
  # Check elf2uf2 executable exists and can run.
  [ -x "${ELF2UF2_PATH}" ] || fail "elf2uf2 missing at ${ELF2UF2_PATH}. Run Scripts/init.sh."
}

# ------------------------------------------------------------
# Section: build steps
# ------------------------------------------------------------

# Performs a full clean rebuild so results are always fresh and reproducible.
build_firmware() {
  # Tell the user we are cleaning old build output.
  log "Cleaning prior build output"
  # Remove the full build folder, including old CMake cache and objects.
  rm -rf "${BUILD_DIR}"
  # Recreate an empty build folder.
  mkdir -p "${BUILD_DIR}"

  # Tell the user we are generating build files.
  log "Configuring CMake build"
  # Configure CMake for RP2040 cross-compilation and Swift compiler usage.
  run_quiet cmake -S "${PROJECT_ROOT}" -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${PROJECT_ROOT}/CMake/arm-none-eabi-toolchain.cmake" \
    -DPICO_SDK_PATH="${PICO_SDK_PATH}" \
    -DSWIFT_EXECUTABLE="$(command -v swiftc)"

  # Tell the user we are compiling firmware.
  log "Building firmware"
  # Build only the selected firmware target.
  run_quiet cmake --build "${BUILD_DIR}" --target "${TARGET_NAME}"
}

# ------------------------------------------------------------
# Section: packaging steps
# ------------------------------------------------------------

# Converts the built ELF firmware into UF2 for drag-and-drop flashing.
convert_to_uf2() {
  # Stop immediately if the ELF file was not produced by the build.
  [ -f "${ELF_PATH}" ] || fail "ELF not found: ${ELF_PATH}"
  # Tell the user conversion has started.
  log "Converting ELF to UF2"
  # Run elf2uf2 quietly (only errors become visible).
  run_quiet "${ELF2UF2_PATH}" "${ELF_PATH}" "${UF2_PATH}"
  # Confirm UF2 output file exists after conversion.
  [ -f "${UF2_PATH}" ] || fail "UF2 conversion failed."
}

# ------------------------------------------------------------
# Section: flash steps
# ------------------------------------------------------------

# Copies the UF2 file to the Pico BOOTSEL USB drive.
flash_uf2() {
  # Local variable that will store the detected Pico mount path.
  local mount_point
  # Try to detect the Pico mount and store it in mount_point.
  if ! mount_point="$(detect_pico_mount)"; then
    # Stop with guidance when board is not in BOOTSEL mode.
    fail "No Pico UF2 mount found. Hold BOOTSEL while connecting the board."
  fi

  # Tell the user where the UF2 is being copied.
  log "Copying UF2 to ${mount_point}"
  # Copy without macOS extended attributes (UF2 volumes do not support them).
  cp -X "${UF2_PATH}" "${mount_point}/"
  # Flush file system buffers to reduce partial-copy risk.
  sync
  # Confirm copy stage has completed.
  log "Flash complete: ${UF2_PATH} -> ${mount_point}"
}

# ------------------------------------------------------------
# Section: main program flow
# ------------------------------------------------------------

# Orchestrates full workflow from checks to build, package, and optional flash.
main() {
  # Parse user-provided flags before doing any build work.
  parse_args "$@"
  # Show banner at start.
  show_header
  # Add visible spacing before progress logs begin.
  printf '\n\n'
  # Ensure required tools and files are available.
  ensure_prerequisites
  # Build the firmware from clean state.
  build_firmware
  # Convert build output into UF2 file.
  convert_to_uf2

  # Flash only when no --no-flash flag was passed.
  if [ "${SKIP_FLASH}" -eq 0 ]; then
    # Copy UF2 to the Pico.
    flash_uf2
    # Success message for build + flash path.
    log "Success. The Pico should now run the Swift blink firmware."
  else
    # Success message for build-only path.
    log "Build finished. Flash was skipped because --no-flash was used."
    # Tell user where the UF2 file can be found.
    log "The UF2 file is ready at ${UF2_PATH}."
  fi
}

# Start the program and forward all command-line arguments.
main "$@"
