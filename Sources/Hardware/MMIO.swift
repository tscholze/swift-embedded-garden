/// Minimal MMIO helper layer for Swift Embedded.
///
/// This file centralizes common 32-bit memory-mapped IO (MMIO) access
/// patterns used across low-level peripheral drivers. The functions are
/// intentionally tiny and annotated with `@inline(__always)` to keep call
/// overhead minimal for embedded use.

@inline(__always)
/// Read a 32-bit value from a memory-mapped register.
///
/// - Parameter address: The 32-bit memory address of the register to read.
/// - Returns: The 32-bit value read from `address`.
func mmioRead(_ address: UInt32) -> UInt32 {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!.pointee
}

@inline(__always)
/// Write a 32-bit value to a memory-mapped register.
///
/// - Parameters:
///   - address: The 32-bit memory address of the register to write.
///   - value: The 32-bit value to write to `address`.
func mmioWrite(_ address: UInt32, _ value: UInt32) {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!.pointee = value
}

@inline(__always)
/// Atomically set bits in a 32-bit MMIO register.
///
/// - Parameters:
///   - address: The 32-bit memory address of the register.
///   - mask: Bitmask of bits to set to 1. Bits set in `mask` will be set in the register.
func mmioSetBits(_ address: UInt32, _ mask: UInt32) {
    let current = mmioRead(address)
    mmioWrite(address, current | mask)
}

@inline(__always)
/// Atomically clear bits in a 32-bit MMIO register.
///
/// - Parameters:
///   - address: The 32-bit memory address of the register.
///   - mask: Bitmask of bits to clear (set to 0). Bits set in `mask` will be cleared in the register.
func mmioClearBits(_ address: UInt32, _ mask: UInt32) {
    let current = mmioRead(address)
    mmioWrite(address, current & ~mask)
}
