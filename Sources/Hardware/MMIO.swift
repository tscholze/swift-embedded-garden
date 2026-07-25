// Minimal MMIO helper layer for Swift Embedded.
// This file centralizes volatile-ish 32-bit register access patterns.

@inline(__always)
func mmioRead(_ address: UInt32) -> UInt32 {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!.pointee
}

@inline(__always)
func mmioWrite(_ address: UInt32, _ value: UInt32) {
    UnsafeMutablePointer<UInt32>(bitPattern: UInt(address))!.pointee = value
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
