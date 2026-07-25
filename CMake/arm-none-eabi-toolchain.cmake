# Cross-compilation toolchain for RP2040 firmware builds on macOS/Linux hosts.
# This ensures Pico SDK assembly/C runtime are compiled for Cortex-M0+ instead
# of accidentally using the host compiler.

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
