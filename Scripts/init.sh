#!/usr/bin/env bash
# One-time macOS project bootstrap for Swift Embedded + Raspberry Pi Pico SDK.
# It installs/verifies host dependencies, provisions Swift via swiftly, clones
# or updates pico-sdk, and prepares an elf2uf2-compatible converter wrapper.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_ROOT}/.tools"
PICO_SDK_PATH_DEFAULT="${PROJECT_ROOT}/.deps/pico-sdk"
PICO_SDK_PATH="${PICO_SDK_PATH:-$PICO_SDK_PATH_DEFAULT}"
PICO_SDK_REF="${PICO_SDK_REF:-master}"
SWIFTLY_CHANNEL="${SWIFTLY_CHANNEL:-main-snapshot}"

# Prints a standard progress message.
log() { printf "==> %s\n" "$*"; }
# Prints a warning message.
warn() { printf "⚠️  %s\n" "$*"; }
# Prints an error message and exits with failure.
fail() { printf "❌ %s\n" "$*"; exit 1; }

# Shows command-line usage and available options.
print_usage() {
  cat <<'EOF'
Usage: Scripts/init.sh [--sdk-ref <ref>] [--help]

Options:
  --sdk-ref <ref>  Pico SDK git branch, tag, or commit-ish (default: master).
  --help           Show this help text and exit.
EOF
}

# Parses supported flags and updates configuration variables.
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

# Ensures Homebrew is installed because the script depends on it.
ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    fail "Homebrew is required. Install from https://brew.sh and re-run."
  fi
}

# Installs a Homebrew package only when it is not already installed.
ensure_brew_pkg() {
  local pkg="$1"
  if brew list --versions "$pkg" >/dev/null 2>&1; then
    log "Homebrew package already present: $pkg"
  else
    log "Installing Homebrew package: $pkg"
    brew install "$pkg"
  fi
}

# Ensures ARM cross-compiler tools for RP2040 are available.
ensure_arm_toolchain() {
  if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
    log "ARM GNU toolchain already present: $(command -v arm-none-eabi-gcc)"
    return
  fi
  ensure_brew_pkg arm-none-eabi-gcc
}

# Ensures a Swift 6 compiler is available, provisioning via swiftly if needed.
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

  if ! command -v swiftc >/dev/null 2>&1; then
    fail "swiftc still unavailable after swiftly setup."
  fi

  if ! swiftc --version | grep -q "Swift version 6"; then
    fail "Active swiftc is not Swift 6 after swiftly setup."
  fi

  log "Active Swift toolchain: $(swiftc --version | head -n1)"
}

# Clones or updates pico-sdk to the configured path and ref.
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

# Creates an elf2uf2-compatible wrapper command backed by picotool.
ensure_elf2uf2() {
  mkdir -p "${TOOLS_DIR}"
  local output="${TOOLS_DIR}/elf2uf2"

  # Newer pico-sdk releases use picotool for UF2 conversion. We provide an
  # elf2uf2-compatible command wrapper so the rest of the workflow stays stable.
  ensure_brew_pkg picotool

  cat > "${output}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  printf "Usage: elf2uf2 <input.elf> <output.uf2>\n" >&2
  exit 2
fi
exec picotool uf2 convert "$1" "$2"
EOF
  chmod +x "${output}"
}

# Writes Scripts/env.sh so build scripts can load generated paths.
write_env_file() {
  cat > "${PROJECT_ROOT}/Scripts/env.sh" <<EOF
#!/usr/bin/env bash
# Auto-generated by Scripts/init.sh.
# Source this file before running Scripts/run.sh if your shell session does
# not already export these variables.
export PICO_SDK_PATH="${PICO_SDK_PATH}"
export ELF2UF2_PATH="${TOOLS_DIR}/elf2uf2"
EOF
  chmod +x "${PROJECT_ROOT}/Scripts/env.sh"
}

# Runs the complete initialization workflow in the required order.
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
