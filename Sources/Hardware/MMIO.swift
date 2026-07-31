/// Minimal MMIO helper layer for Swift Embedded.
///
/// This file centralizes common 32-bit memory-mapped IO (MMIO) access
/// patterns used across low-level peripheral drivers. Swift owns the register
/// maps and all driver logic; a two-function C bridge supplies the volatile
/// load/store semantics required by RP2040 device memory.

/// Imports the volatile 32-bit MMIO read implemented in `CMake/bootstrap.c`.
@_silgen_name("rp2040_mmio_read")
private func rp2040MMIORead(_ address: UInt32) -> UInt32

/// Imports the volatile 32-bit MMIO write implemented in `CMake/bootstrap.c`.
@_silgen_name("rp2040_mmio_write")
private func rp2040MMIOWrite(_ address: UInt32, _ value: UInt32)

@inline(__always)
/// Read a 32-bit value from a memory-mapped register.
///
/// - Parameter address: The 32-bit memory address of the register to read.
/// - Returns: The 32-bit value read from `address`.
func mmioRead(_ address: UInt32) -> UInt32 {
  rp2040MMIORead(address)
}

@inline(__always)
/// Write a 32-bit value to a memory-mapped register.
///
/// - Parameters:
///   - address: The 32-bit memory address of the register to write.
///   - value: The 32-bit value to write to `address`.
func mmioWrite(_ address: UInt32, _ value: UInt32) {
  rp2040MMIOWrite(address, value)
}

@inline(__always)
/// Sets bits in a 32-bit MMIO register with a read-modify-write sequence.
///
/// This is not atomic with respect to another bus master; use the RP2040's
/// dedicated SET alias registers when a peripheral provides one.
///
/// - Parameters:
///   - address: The 32-bit memory address of the register.
///   - mask: Bitmask of bits to set to 1. Bits set in `mask` will be set in the register.
func mmioSetBits(_ address: UInt32, _ mask: UInt32) {
  let current = mmioRead(address)
  mmioWrite(address, current | mask)
}

@inline(__always)
/// Clears bits in a 32-bit MMIO register with a read-modify-write sequence.
///
/// This is not atomic with respect to another bus master; use the RP2040's
/// dedicated CLEAR alias registers when a peripheral provides one.
///
/// - Parameters:
///   - address: The 32-bit memory address of the register.
///   - mask: Bitmask of bits to clear (set to 0). Bits set in `mask` will be cleared in the register.
func mmioClearBits(_ address: UInt32, _ mask: UInt32) {
  let current = mmioRead(address)
  mmioWrite(address, current & ~mask)
}
