// RP2040 GPIO driver using direct MMIO.
// Extension point: add UART/I2C/SPI setup routines in this layer so the
// application remains hardware-intent focused and board support stays clean.

enum RP2040GPIO {
    // RP2040 register base addresses.
    private static let resetsBase: UInt32 = 0x4000_c000
    private static let ioBank0Base: UInt32 = 0x4001_4000
    private static let padsBank0Base: UInt32 = 0x4001_c000
    private static let sioBase: UInt32 = 0xd000_0000

    // Reset control offsets.
    private static let resetsResetOffset: UInt32 = 0x00
    private static let resetsResetDoneOffset: UInt32 = 0x08

    // SIO GPIO offsets.
    private static let sioGPIOOutSetOffset: UInt32 = 0x14
    private static let sioGPIOOutClrOffset: UInt32 = 0x18
    private static let sioGPIOOESetOffset: UInt32 = 0x24
    private static let sioGPIOOEClrOffset: UInt32 = 0x28

    // Function select value for SIO on RP2040.
    private static let funcSelSIO: UInt32 = 0x5

    // Peripheral reset bits for IO_BANK0 and PADS_BANK0.
    private static let resetIOBank0Bit: UInt32 = 1 << 5
    private static let resetPadsBank0Bit: UInt32 = 1 << 8

    @inline(__always)
    private static func ioGPIOCtrlAddress(pin: UInt32) -> UInt32 {
        // For each pin: STATUS at +0, CTRL at +4, stride 8 bytes.
        ioBank0Base + 0x004 + (pin * 8)
    }

    @inline(__always)
    private static func padsGPIOAddress(pin: UInt32) -> UInt32 {
        // GPIO0 starts at +0x04, one 32-bit register per pin.
        padsBank0Base + 0x004 + (pin * 4)
    }

    static func configureAsSIOOutput(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)

        // Wait until reset-done shows both peripherals are released.
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

        // Keep default pull/drive settings but explicitly write back current value
        // so this is a clear customization point for future board tuning.
        let padAddress = padsGPIOAddress(pin: pin)
        mmioWrite(padAddress, mmioRead(padAddress))

        // Route GPIO function mux to SIO and enable output.
        mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
        mmioWrite(sioBase + sioGPIOOESetOffset, 1 << pin)
    }

    static func configureAsSIOInput(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)

        // Wait until reset-done shows both peripherals are released.
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

        // Preserve current pad configuration (pull/drive) as a customization point.
        let padAddress = padsGPIOAddress(pin: pin)
        mmioWrite(padAddress, mmioRead(padAddress))

        // Route GPIO function mux to SIO and disable output (make it an input).
        mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
        mmioWrite(sioBase + sioGPIOOEClrOffset, 1 << pin)
    }

    // Typo-tolerant alias: some callers may request `configureAsSIInput`.
    static func configureAsSIInput(pin: UInt32) {
        configureAsSIOInput(pin: pin)
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
