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
  shift || true

  if brew list --versions "$pkg" >/dev/null 2>&1; then
    log "Homebrew package already present: $pkg"
  else
    log "Installing Homebrew package: $pkg"
    brew install "$pkg" "$@"
  fi
}

# Checks whether a candidate toolchain contains the core newlib/libc runtime that
# Pico SDK projects need for bare-metal linking. The Homebrew arm-none-eabi-gcc
# package is intentionally incomplete on macOS and misses that runtime.
has_full_arm_toolchain_runtime() {
  local candidate="$1"
  local lib_dir runtime_library runtime_path

  if [ -x "${candidate}/arm-none-eabi-gcc" ]; then
    for runtime_library in libc.a libc_nano.a; do
      runtime_path="$("${candidate}/arm-none-eabi-gcc" "-print-file-name=${runtime_library}" 2>/dev/null || true)"
      if [ -f "${runtime_path}" ]; then
        return 0
      fi
    done
  fi

  for lib_dir in \
    "${candidate}/../lib" \
    "${candidate}/../lib/arm-none-eabi" \
    "${candidate}/../../lib" \
    "${candidate}/../../lib/arm-none-eabi" \
    "${candidate}/../arm-none-eabi/lib" \
    "${candidate}/../../arm-none-eabi/lib"; do
    if [ -f "${lib_dir}/libc.a" ] || [ -f "${lib_dir}/libc_nano.a" ]; then
      return 0
    fi
  done

  return 1
}

# Installs the official Arm GNU Embedded package when Homebrew only downloaded it
# to the cask cache without unpacking it into the expected toolchain directory.
install_official_arm_toolchain() {
  local official_pkg install_dir tmp_dir

  official_pkg="$(find /opt/homebrew/Caskroom/gcc-arm-embedded -name 'arm-gnu-toolchain-*.pkg' -print -quit 2>/dev/null || true)"
  if [ -z "${official_pkg}" ] && [ -d "/usr/local/Caskroom/gcc-arm-embedded" ]; then
    official_pkg="$(find /usr/local/Caskroom/gcc-arm-embedded -name 'arm-gnu-toolchain-*.pkg' -print -quit 2>/dev/null || true)"
  fi

  if [ -z "${official_pkg}" ]; then
    return 1
  fi

  install_dir="/Applications/ArmGNUToolchain/15.3.rel1/arm-none-eabi"
  mkdir -p "${install_dir}"

  if [ -x "${install_dir}/bin/arm-none-eabi-gcc" ] && has_full_arm_toolchain_runtime "${install_dir}/bin"; then
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  pkgutil --expand-full "${official_pkg}" "${tmp_dir}"

  if [ -d "${tmp_dir}/Payload/arm-none-eabi" ]; then
    mkdir -p "${install_dir}/arm-none-eabi"
    cp -a "${tmp_dir}/Payload/arm-none-eabi/." "${install_dir}/arm-none-eabi/"
  fi
  if [ -d "${tmp_dir}/Payload/bin" ]; then
    mkdir -p "${install_dir}/bin"
    cp -a "${tmp_dir}/Payload/bin/." "${install_dir}/bin/"
  fi
  if [ -d "${tmp_dir}/Payload/lib" ]; then
    mkdir -p "${install_dir}/lib"
    cp -a "${tmp_dir}/Payload/lib/." "${install_dir}/lib/"
  fi
  if [ -d "${tmp_dir}/Payload/libexec" ]; then
    mkdir -p "${install_dir}/libexec"
    cp -a "${tmp_dir}/Payload/libexec/." "${install_dir}/libexec/"
  fi
  if [ -d "${tmp_dir}/Payload/share" ]; then
    mkdir -p "${install_dir}/share"
    cp -a "${tmp_dir}/Payload/share/." "${install_dir}/share/"
  fi
  if [ -d "${tmp_dir}/Payload/include" ]; then
    mkdir -p "${install_dir}/include"
    cp -a "${tmp_dir}/Payload/include/." "${install_dir}/include/"
  fi

  rm -rf "${tmp_dir}"
  return 0
}

# Finds the active ARM GNU toolchain binary directory, preferring a full
# cross-toolchain over the incomplete `arm-none-eabi-gcc` Homebrew package.
find_arm_toolchain_bin() {
  local candidate
  for candidate in \
    /Applications/ArmGNUToolchain/*/arm-none-eabi/bin \
    /Applications/ArmGNUToolchain/*/arm-none-eabi/arm-none-eabi/bin \
    /opt/homebrew/Caskroom/gcc-arm-embedded/*/arm-gnu-toolchain-*/bin \
    /opt/homebrew/Caskroom/gcc-arm-embedded/*/arm-none-eabi/bin \
    /usr/local/Caskroom/gcc-arm-embedded/*/arm-gnu-toolchain-*/bin \
    /usr/local/Caskroom/gcc-arm-embedded/*/arm-none-eabi/bin \
    /opt/homebrew/opt/gcc-arm-embedded/bin \
    /usr/local/opt/gcc-arm-embedded/bin \
    /opt/homebrew/bin \
    /usr/local/bin; do
    [ -x "${candidate}/arm-none-eabi-gcc" ] || continue
    if has_full_arm_toolchain_runtime "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

# Ensures ARM cross-compiler tools for RP2040 are available.
# The Homebrew arm-none-eabi-gcc formula is incomplete on macOS and misses the
# standard C runtime needed by the Pico linker, so we install the full Arm GNU
# Embedded toolchain package instead.
ensure_arm_toolchain() {
  local toolchain_bin
  toolchain_bin="$(find_arm_toolchain_bin || true)"

  if [ -n "${toolchain_bin}" ] && [ -x "${toolchain_bin}/arm-none-eabi-gcc" ]; then
    log "ARM GNU toolchain already present: ${toolchain_bin}/arm-none-eabi-gcc"
    return
  fi

  if install_official_arm_toolchain; then
    toolchain_bin="$(find_arm_toolchain_bin || true)"
    if [ -n "${toolchain_bin}" ] && [ -x "${toolchain_bin}/arm-none-eabi-gcc" ]; then
      log "ARM GNU toolchain installed: ${toolchain_bin}/arm-none-eabi-gcc"
      return
    fi
  fi

  if brew list --versions gcc-arm-embedded >/dev/null 2>&1; then
    log "Full ARM GNU embedded toolchain already installed via Homebrew Cask."
    return
  fi

  warn "The active ARM GCC is missing libc/newlib. Installing the full gcc-arm-embedded toolchain."
  ensure_brew_pkg gcc-arm-embedded --cask
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

# Installs the Swift-format pre-commit hook from Scripts/hooks/pre-commit.
install_git_hooks() {
  local hooks_dir="${PROJECT_ROOT}/.git/hooks"
  local hook_src="${PROJECT_ROOT}/Scripts/hooks/pre-commit"
  local hook_dst="${hooks_dir}/pre-commit"
  mkdir -p "${hooks_dir}"
  cp "${hook_src}" "${hook_dst}"
  chmod +x "${hook_dst}"
  log "Installed pre-commit hook: .git/hooks/pre-commit"
}

# Writes Scripts/env.sh so build scripts can load generated paths.
write_env_file() {
  local swift_bin_dir="${SWIFTLY_BIN_DIR:-${HOME}/.swiftly/bin}"
  local arm_toolchain_bin
  arm_toolchain_bin="$(find_arm_toolchain_bin || true)"

  cat > "${PROJECT_ROOT}/Scripts/env.sh" <<EOF
#!/usr/bin/env bash
# Auto-generated by Scripts/init.sh.
# Source this file before running Scripts/run.sh if your shell session does
# not already export these variables.
export PICO_SDK_PATH="${PICO_SDK_PATH}"
export ELF2UF2_PATH="${TOOLS_DIR}/elf2uf2"
EOF

  if [ -n "${arm_toolchain_bin}" ]; then
    printf 'export PATH="%s:${PATH}"\n' "${arm_toolchain_bin}" >> "${PROJECT_ROOT}/Scripts/env.sh"
  fi

  if [ -d "${swift_bin_dir}" ]; then
    printf 'export PATH="%s:${PATH}"\n' "${swift_bin_dir}" >> "${PROJECT_ROOT}/Scripts/env.sh"
  fi

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
  install_git_hooks

  log "Initialization complete."
  log "Run: source Scripts/env.sh"
  log "Then: Scripts/run.sh"
}

main "$@"
