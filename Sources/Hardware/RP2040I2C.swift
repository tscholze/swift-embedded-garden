/// RP2040 I2C0 master transport using the on-chip DesignWare I2C peripheral.
///
/// This layer deliberately knows nothing about a specific I2C device. Display
/// drivers use it to send one control byte followed by a bounded byte sequence.
///
/// The register setup, timing values, and one-byte completion flow are a Swift
/// transform of Raspberry Pi Pico SDK `hardware_i2c`. They preserve the SDK's
/// hardware requirements while replacing its C API with a focused Swift I2C0
/// transport; this is not an original I2C controller design.
enum RP2040I2C {
    /// Describes a configuration or transaction failure reported by I2C0.
    enum Error: Swift.Error {
        /// The supplied GPIOs are not an RP2040 I2C0 SDA/SCL pair.
        case invalidPins

        /// The requested bus frequency or I2C address is unsupported.
        case invalidClock

        /// A controller state transition or bus event exceeded the poll limit.
        case timeout

        /// The controller raised TX_ABRT with the raw RP2040 abort-source bits.
        case aborted(UInt32)
    }

    /// Base address of the RP2040 I2C0 register block.
    private static let base: UInt32 = 0x4004_4000

    /// Base address of the RP2040 reset controller.
    private static let resetsBase: UInt32 = 0x4000_c000

    /// Offset of the peripheral-reset request register.
    private static let resetOffset: UInt32 = 0x00

    /// Offset of the peripheral-reset completion register.
    private static let resetDoneOffset: UInt32 = 0x08

    /// Reset-controller bit assigned to I2C0.
    private static let resetBit: UInt32 = 1 << 3

    /// Offset of the DesignWare I2C control register.
    private static let conOffset: UInt32 = 0x00

    /// Offset of the seven-bit target-address register.
    private static let tarOffset: UInt32 = 0x04

    /// Offset of the transmit data and command register.
    private static let dataCmdOffset: UInt32 = 0x10

    /// Offset of the fast-mode SCL high-count register.
    private static let fsSclHcntOffset: UInt32 = 0x1c

    /// Offset of the fast-mode SCL low-count register.
    private static let fsSclLcntOffset: UInt32 = 0x20

    /// Offset of the unmasked interrupt-status register.
    private static let rawIntrStatOffset: UInt32 = 0x34

    /// Offset of the receive FIFO threshold register.
    private static let rxTlOffset: UInt32 = 0x38

    /// Offset of the transmit FIFO threshold register.
    private static let txTlOffset: UInt32 = 0x3c

    /// Offset of the read-to-clear transmit-abort interrupt register.
    private static let clrTxAbrtOffset: UInt32 = 0x54

    /// Offset of the read-to-clear STOP-detected interrupt register.
    private static let clrStopDetOffset: UInt32 = 0x60

    /// Offset of the controller enable register.
    private static let enableOffset: UInt32 = 0x6c

    /// Offset of the controller status register.
    private static let statusOffset: UInt32 = 0x70

    /// Offset of the current transmit FIFO-level register.
    private static let txFlrOffset: UInt32 = 0x74

    /// Offset of the SDA transmit and receive hold-time register.
    private static let sdaHoldOffset: UInt32 = 0x7c

    /// Offset of the raw transmit-abort-source register.
    private static let txAbrtSourceOffset: UInt32 = 0x80

    /// Offset of the DMA-control register.
    private static let dmaCrOffset: UInt32 = 0x88

    /// Offset of the controller enabled-status register.
    private static let enableStatusOffset: UInt32 = 0x9c

    /// Offset of the fast-mode spike-filter length register.
    private static let fsSpklenOffset: UInt32 = 0xa0

    /// Enables DesignWare master mode in `IC_CON`.
    private static let conMasterMode: UInt32 = 1 << 0

    /// Selects DesignWare fast-mode timing in `IC_CON`.
    private static let conSpeedFast: UInt32 = 2 << 1

    /// Permits repeated START conditions in `IC_CON`.
    private static let conRestartEnable: UInt32 = 1 << 5

    /// Disables the unused I2C slave role in `IC_CON`.
    private static let conSlaveDisable: UInt32 = 1 << 6

    /// Makes TX_EMPTY report completion after the shift register drains.
    private static let conTransmitEmptyControl: UInt32 = 1 << 8

    /// Requests a STOP condition after the current data byte.
    private static let dataCmdStop: UInt32 = 1 << 9

    /// Raw interrupt bit raised after a master STOP condition.
    private static let rawInterruptStopDetected: UInt32 = 1 << 9

    /// Raw interrupt bit raised when a transaction is aborted.
    private static let rawInterruptTransmitAbort: UInt32 = 1 << 6

    /// Raw interrupt bit raised when a transmitted byte fully completes.
    private static let rawInterruptTransmitEmpty: UInt32 = 1 << 4

    /// GPIO function-select value for the RP2040 I2C peripheral.
    private static let i2cFunction: UInt32 = 3

    /// Expected RP2040 system-clock frequency used by the Pico firmware setup.
    private static let systemClockHz: UInt32 = 125_000_000

    /// Maximum register-poll iterations before a blocking operation times out.
    private static let pollLimit = 1_000_000

    /// Configures I2C0 in fast mode and routes it to a valid I2C0 GPIO pair.
    ///
    /// This resets I2C0, enables pull-ups, selects GPIO function 3, applies the
    /// Pico SDK 400 kHz timing model, and selects the initial seven-bit target.
    ///
    /// - Parameters:
    ///   - sdaPin: I2C0 SDA GPIO.
    ///   - sclPin: I2C0 SCL GPIO paired with `sdaPin`.
    ///   - clockHz: Requested bus rate from 1 through 400,000 hertz.
    ///   - targetAddress: Initial seven-bit device address.
    /// - Returns: A configuration failure or success before any payload is sent.
    static func initialize(
        sdaPin: UInt32,
        sclPin: UInt32,
        clockHz: UInt32,
        targetAddress: UInt8
    ) -> Result<Void, Error> {
        guard isI2C0Pair(sda: sdaPin, scl: sclPin) else { return .failure(.invalidPins) }
        guard clockHz > 0, clockHz <= 400_000, targetAddress <= 0x7f else {
            return .failure(.invalidClock)
        }

mmioSetBits(resetsBase + resetOffset, resetBit)
mmioClearBits(resetsBase + resetOffset, resetBit)
var resetPolls = 0
while (mmioRead(resetsBase + resetDoneOffset) & resetBit) == 0 {
    resetPolls += 1
    if resetPolls >= pollLimit { return .failure(.timeout) }
}

        // The display normally has external pull-ups, but internal pull-ups
        // keep both lines high on a loosely wired prototype bus as well.
        RP2040GPIO.enablePadPullUp(pin: sdaPin)
        RP2040GPIO.enablePadPullUp(pin: sclPin)
        RP2040GPIO.setFunction(pin: sdaPin, funcSel: i2cFunction)
        RP2040GPIO.setFunction(pin: sclPin, funcSel: i2cFunction)

        mmioWrite(base + enableOffset, 0)
        guard waitForDisabled() else { return .failure(.timeout) }

        // Match the Pico SDK's fast-mode timing and 300 ns SDA hold time.
        let periodTicks = (systemClockHz + clockHz / 2) / clockHz
        let lowCount = periodTicks * 3 / 5
        let highCount = periodTicks - lowCount
        let sdaHoldCount = ((systemClockHz * 3) / 10_000_000) + 1
        mmioWrite(base + fsSclHcntOffset, highCount)
        mmioWrite(base + fsSclLcntOffset, lowCount)
        mmioWrite(base + fsSpklenOffset, max(lowCount / 16, 1))
        mmioWrite(base + sdaHoldOffset, sdaHoldCount)
        mmioWrite(base + rxTlOffset, 0)
        mmioWrite(base + txTlOffset, 0)
        mmioWrite(base + dmaCrOffset, 0x3)
        mmioWrite(
            base + conOffset,
            conMasterMode | conSpeedFast | conRestartEnable | conSlaveDisable | conTransmitEmptyControl
        )
        // IC_TAR is writable only while IC_ENABLE is clear on RP2040's I2C peripheral.
        mmioWrite(base + tarOffset, UInt32(targetAddress))
        mmioWrite(base + enableOffset, 1)
        clearInterruptState()
        return .success(())
    }

    /// Writes one complete I2C transaction.
    ///
    /// The first transmitted byte is the device-specific `control` byte. Each
    /// subsequent payload byte waits for `TX_EMPTY`, matching the Pico SDK's
    /// blocking write behavior; the final byte requests STOP.
    ///
    /// - Parameters:
    ///   - address: Seven-bit target address selected while I2C0 is disabled.
    ///   - control: Device-specific prefix, such as SSD1306 `0x00` or `0x40`.
    ///   - bytes: Non-control bytes to send after the prefix.
    /// - Returns: A transport error or success after STOP is observed.
    static func write(address: UInt8, control: UInt8, bytes: [UInt8]) -> Result<Void, Error> {
        guard address <= 0x7f else { return .failure(.invalidClock) }
        guard selectTarget(address) else { return .failure(.timeout) }
        clearInterruptState()

        let totalCount = bytes.count + 1
        for index in 0..<totalCount {
            let value = index == 0 ? control : bytes[index - 1]
            let stop = index == totalCount - 1 ? dataCmdStop : 0
            mmioWrite(base + dataCmdOffset, UInt32(value) | stop)
            switch waitForTransmitComplete() {
            case .success: break
            case .failure(let error): return .failure(error)
            }
        }

        guard waitForStop() else { return .failure(.timeout) }
        _ = mmioRead(base + clrStopDetOffset)
        return .success(())
    }

    private static func isI2C0Pair(sda: UInt32, scl: UInt32) -> Bool {
        (sda == 0 && scl == 1) || (sda == 4 && scl == 5) ||
            (sda == 8 && scl == 9) || (sda == 12 && scl == 13) ||
            (sda == 16 && scl == 17) || (sda == 20 && scl == 21)
    }

    private static func waitForDisabled() -> Bool {
        for _ in 0..<pollLimit where (mmioRead(base + enableStatusOffset) & 1) == 0 { return true }
        return false
    }

    /// The RP2040 requires IC_TAR changes while the I2C controller is disabled.
    private static func selectTarget(_ address: UInt8) -> Bool {
        mmioWrite(base + enableOffset, 0)
        guard waitForDisabled() else { return false }
        mmioWrite(base + tarOffset, UInt32(address))
        mmioWrite(base + enableOffset, 1)
        return true
    }

    private static func waitForTransmitComplete() -> Result<Void, Error> {
        for _ in 0..<pollLimit {
            let interrupts = mmioRead(base + rawIntrStatOffset)
            if (interrupts & rawInterruptTransmitAbort) != 0 {
                return .failure(readAndClearAbort())
            }
            if (interrupts & rawInterruptTransmitEmpty) != 0 { return .success(()) }
        }
        return .failure(.timeout)
    }

    private static func waitForStop() -> Bool {
        for _ in 0..<pollLimit {
            let interrupts = mmioRead(base + rawIntrStatOffset)
            if (interrupts & rawInterruptTransmitAbort) != 0 { return false }
            if (interrupts & rawInterruptStopDetected) != 0 {
                return true
            }
        }
        return false
    }

    private static func readAndClearAbort() -> Error {
        let abortSource = mmioRead(base + txAbrtSourceOffset)
        _ = mmioRead(base + clrTxAbrtOffset)
        return .aborted(abortSource)
    }

    private static func clearInterruptState() {
        _ = mmioRead(base + clrTxAbrtOffset)
        _ = mmioRead(base + clrStopDetOffset)
        while mmioRead(base + txFlrOffset) != 0 {}
    }
}