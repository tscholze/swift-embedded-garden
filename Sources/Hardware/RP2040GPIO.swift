/// RP2040 GPIO driver using direct MMIO.
/// Extension point: add UART/I2C/SPI setup routines in this layer so the
/// application remains hardware-intent focused and board support stays clean.
///
/// This file provides low-level helpers to control the RP2040's GPIO pins
/// by reading and writing memory-mapped IO (MMIO) registers. The comments
/// explain each constant and function in simple terms for beginners.
enum RP2040GPIO {
    // MARK: - Constants -

    /// RP2040 resets block base address.
    /// This is the starting memory address for the resets peripheral.
    private static let resetsBase: UInt32 = 0x4000_c000

    /// IO_BANK0 base address.
    /// Start address for the bank that contains per-pin CTRL/STATUS registers.
    private static let ioBank0Base: UInt32 = 0x4001_4000

    /// PADS_BANK0 base address.
    /// Start address for the pad control registers (pulls, drive strength).
    private static let padsBank0Base: UInt32 = 0x4001_c000

    /// SIO base address.
    /// Start address for the SIO block used to read/write/enable GPIO from CPU.
    private static let sioBase: UInt32 = 0xd000_0000

    /// Offset of the reset control register inside `resetsBase`.
    /// Writing bits here requests resets for peripherals.
    private static let resetsResetOffset: UInt32 = 0x00

    /// Offset of the reset-done register inside `resetsBase`.
    /// Read this to know when a peripheral has finished resetting.
    private static let resetsResetDoneOffset: UInt32 = 0x08

    /// SIO GPIO OUT_SET offset.
    /// Writing a 1 here sets the corresponding output bit(s) to high.
    private static let sioGPIOOutSetOffset: UInt32 = 0x14

    /// SIO GPIO OUT_CLR offset.
    /// Writing a 1 here clears the corresponding output bit(s) to low.
    private static let sioGPIOOutClrOffset: UInt32 = 0x18

    /// SIO GPIO OUT offset.
    /// The full output register; used for atomic set/clear operations.
    private static let sioGPIOOutOffset: UInt32 = 0x10
    /// SIO GPIO IN offset.
    /// Reading this register gives the current sampled input levels for all GPIOs.
    private static let sioGPIOInOffset: UInt32 = 0x04

    /// SIO GPIO OE_SET offset.
    /// Writing a 1 here enables output (makes pin driveable by CPU).
    private static let sioGPIOOESetOffset: UInt32 = 0x24

    /// SIO GPIO OE_CLR offset.
    /// Writing a 1 here disables output (pin becomes input readable by CPU).
    private static let sioGPIOOEClrOffset: UInt32 = 0x28

    /// Function select value for SIO on RP2040.
    /// Writing this to a pin's CTRL register selects the CPU-controlled mode.
    private static let funcSelSIO: UInt32 = 0x5

    /// Reset bit mask for IO_BANK0.
    /// Used when requesting or checking reset state for IO_BANK0.
    private static let resetIOBank0Bit: UInt32 = 1 << 5

    /// Reset bit mask for PADS_BANK0.
    /// Used when requesting or checking reset state for PADS_BANK0.
    private static let resetPadsBank0Bit: UInt32 = 1 << 8

    /// Pad register bit for enabling the internal pull-up resistor (PUE).
    private static let padPUEBit: UInt32 = 1 << 3

    /// Pad register bit for enabling the internal pull-down resistor (PDE).
    private static let padPDEBit: UInt32 = 1 << 2

    // MARK: - Private helpers -

    /// Compute the address of the pin's CTRL register in IO_BANK0.
    /// Note: STATUS is at +0 and CTRL at +4 for each pin, with an 8-byte stride.
    ///
    /// - Parameter pin: GPIO pin number (0..29)
    /// - Returns: The 32-bit memory address of the CTRL register for `pin`.
    @inline(__always)
    private static func ioGPIOCtrlAddress(pin: UInt32) -> UInt32 {

        ioBank0Base + 0x004 + (pin * 8)
    }

    /// Compute the address of the pad control register for `pin`.
    /// Pad registers control pull-ups/pull-downs and drive strength.
    ///
    /// - Parameter pin: GPIO pin number (0..29)
    /// - Returns: The 32-bit memory address of the pad control register.
    ///
    @inline(__always)
    private static func padsGPIOAddress(pin: UInt32) -> UInt32 {
        padsBank0Base + 0x004 + (pin * 4)
    }

    /// Configure a GPIO pin for CPU-controlled output.
    ///
    /// - Parameter pin: GPIO pin number to configure.
    ///
    /// Simple steps performed:
    /// 1. Release IO and PAD peripherals from reset.
    /// 2. Preserve pad configuration (pulls/drive).
    /// 3. Select SIO as the pin function and enable output.
    static func configureAsSIOOutput(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)

        // Wait until reset-done shows both peripherals are released.
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}
        // Preserve current pad configuration (pull/drive). For beginners:
        // pads control physical pin characteristics like pull-up/down.
        let padAddress = padsGPIOAddress(pin: pin)
        mmioWrite(padAddress, mmioRead(padAddress))

        // Route GPIO function mux to SIO and enable output (set OE bit).
        mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
        mmioWrite(sioBase + sioGPIOOESetOffset, 1 << pin)
    }

    /// Configure a GPIO pin for CPU-controlled input (readable by software).
    ///
    /// Steps performed:
    /// 1. Release IO and PAD peripherals from reset.
    /// 2. Preserve pad configuration (pulls/drive).
    /// 3. Select SIO as the pin function and disable output (make it input).
    ///
    /// - Parameter pin: GPIO pin number to configure.
    static func configureAsSIOInput(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)

        // Wait until reset-done shows both peripherals are released.
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}
        // Preserve current pad configuration (pull/drive). Pull-ups and
        // pull-downs are important for stable input readings on floating pins.
        let padAddress = padsGPIOAddress(pin: pin)
        mmioWrite(padAddress, mmioRead(padAddress))

        // Route GPIO function mux to SIO and disable output (clear OE bit).
        mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
        mmioWrite(sioBase + sioGPIOOEClrOffset, 1 << pin)
    }

    /// Enable the internal pull-up resistor on a pin's pad.
    ///
    /// - Parameter pin: GPIO pin number to enable pull-up for.
    ///
    /// This sets the PUE bit and clears PDE in the pad control register.
    /// The function also ensures the PAD and IO blocks are out of reset.
    static func enablePadPullUp(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

        let padAddress = padsGPIOAddress(pin: pin)
        var val = mmioRead(padAddress)
        val |= padPUEBit
        val &= ~padPDEBit
        mmioWrite(padAddress, val)
    }

    /// Enable the internal pull-down resistor on a pin's pad.
    ///
    /// - Parameter pin: GPIO pin number to enable pull-down for.
    ///
    /// This sets the PDE bit and clears PUE in the pad control register.
    /// The function also ensures the PAD and IO blocks are out of reset.
    static func enablePadPullDown(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

        let padAddress = padsGPIOAddress(pin: pin)
        var val = mmioRead(padAddress)
        val |= padPDEBit
        val &= ~padPUEBit
        mmioWrite(padAddress, val)
    }

    /// Disable internal pull resistors on a pin's pad (neither pull-up nor pull-down).
    ///
    /// - Parameter pin: GPIO pin number to clear pull configuration for.
    static func disablePadPulls(pin: UInt32) {
        let resetMask = resetIOBank0Bit | resetPadsBank0Bit
        mmioClearBits(resetsBase + resetsResetOffset, resetMask)
        while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}

        let padAddress = padsGPIOAddress(pin: pin)
        var val = mmioRead(padAddress)
        val &= ~padPUEBit
        val &= ~padPDEBit
        mmioWrite(padAddress, val)
    }

    /// Typo-tolerant alias for `configureAsSIOInput`.
    ///
    /// - Parameter pin: GPIO pin number to configure.
    static func configureAsSIInput(pin: UInt32) {
        configureAsSIOInput(pin: pin)
    }

    /// Set the output level for `pin` to logical high (1).
    /// This uses the SIO OUT register which allows atomic changes.
    ///
    /// - Parameter pin: GPIO pin number to set high.
    @inline(__always)
    static func setHigh(pin: UInt32) {
        mmioSetBits(sioBase + sioGPIOOutOffset, 1 << pin)
    }

    /// Read the current logical level of a GPIO pin.
    ///
    /// - Parameter pin: GPIO pin number to read.
    /// - Returns: `true` if the pin reads as logic high, otherwise `false`.
    @inline(__always)
    static func read(pin: UInt32) -> Bool {
        let v = mmioRead(sioBase + sioGPIOInOffset)
        return (v & (1 << pin)) != 0
    }

    /// Set the output level for `pin` to logical low (0).
    /// Uses the SIO OUT clear field to avoid read-modify-write hazards.
    ///
    /// - Parameter pin: GPIO pin number to set low.
    @inline(__always)
    static func setLow(pin: UInt32) {

        mmioClearBits(sioBase + sioGPIOOutOffset, 1 << pin)
    }
}
