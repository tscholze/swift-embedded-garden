/// RP2040 GPIO driver using direct MMIO.
/// Extension point: add UART/I2C/SPI setup routines in this layer so the
/// application remains hardware-intent focused and board support stays clean.
///
/// This file provides low-level helpers to control the RP2040's GPIO pins
/// by reading and writing memory-mapped IO (MMIO) registers. The comments
/// explain each constant and function in simple terms for beginners.
///
/// The `waitFor…` helpers block the calling core and suit bit-banged
/// protocols with a guaranteed response time. For inputs driven by a user,
/// use `EdgeDetector`, which samples once and returns immediately.
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

  /// TIMER block base address.
  /// Holds the free-running 1MHz microsecond counter.
  private static let timerBase: UInt32 = 0x4005_4000

  /// Offset of the reset control register inside `resetsBase`.
  /// Writing bits here requests resets for peripherals.
  private static let resetsResetOffset: UInt32 = 0x00

  /// Offset of the reset-done register inside `resetsBase`.
  /// Read this to know when a peripheral has finished resetting.
  private static let resetsResetDoneOffset: UInt32 = 0x08

  /// SIO GPIO IN offset.
  /// Reading this register gives the current sampled input levels for all GPIOs.
  private static let sioGPIOInOffset: UInt32 = 0x04

  /// SIO GPIO OUT offset.
  /// The full output register. Prefer the SET/CLR/XOR aliases below.
  private static let sioGPIOOutOffset: UInt32 = 0x10

  /// SIO GPIO OUT_SET offset.
  /// Writing a 1 here sets the corresponding output bit(s) to high.
  private static let sioGPIOOutSetOffset: UInt32 = 0x14

  /// SIO GPIO OUT_CLR offset.
  /// Writing a 1 here clears the corresponding output bit(s) to low.
  private static let sioGPIOOutClrOffset: UInt32 = 0x18

  /// SIO GPIO OUT_XOR offset.
  /// Writing a 1 here inverts the corresponding output bit(s).
  private static let sioGPIOOutXorOffset: UInt32 = 0x1c

  /// SIO GPIO OE_SET offset.
  /// Writing a 1 here enables output (makes pin driveable by CPU).
  private static let sioGPIOOESetOffset: UInt32 = 0x24

  /// SIO GPIO OE_CLR offset.
  /// Writing a 1 here disables output (pin becomes input readable by CPU).
  private static let sioGPIOOEClrOffset: UInt32 = 0x28

  /// TIMERAWL offset inside `timerBase`.
  /// Raw low word of the microsecond counter; reading it needs no latching.
  private static let timerRawLOffset: UInt32 = 0x28

  /// Function select value for SIO on RP2040.
  /// Writing this to a pin's CTRL register selects the CPU-controlled mode.
  private static let funcSelSIO: UInt32 = 0x5

  /// Function select value for the RP2040's I2C peripherals.
  /// This is the Swift Embedded equivalent of the Pico SDK's `GPIO_FUNC_I2C`.
  /// The value selects I2C, not a specific instance: which of the two
  /// controllers a pin reaches is fixed by the pin (GP12/13 are I2C0,
  /// GP14/15 are I2C1, repeating every four pins).
  private static let funcSelI2C: UInt32 = 0x3

  /// Reset bit mask for IO_BANK0.
  /// Used when requesting or checking reset state for IO_BANK0.
  private static let resetIOBank0Bit: UInt32 = 1 << 5

  /// Reset bit mask for PADS_BANK0.
  /// Used when requesting or checking reset state for PADS_BANK0.
  private static let resetPadsBank0Bit: UInt32 = 1 << 8

  /// Pad register bit for enabling the internal pull-down resistor (PDE).
  private static let padPDEBit: UInt32 = 1 << 2

  /// Pad register bit for enabling the internal pull-up resistor (PUE).
  private static let padPUEBit: UInt32 = 1 << 3

  /// Pad register bit for enabling the input buffer (IE).
  /// Without this bit a pin reads low whatever the voltage on it.
  private static let padIEBit: UInt32 = 1 << 6

  /// Pad register bit for disabling the output driver (OD).
  private static let padODBit: UInt32 = 1 << 7

  // MARK: - Types -

  /// Internal pull resistor selection for a pad.
  enum Pull {
    /// Leave the pad's pull configuration untouched.
    case unchanged

    /// Disable both pull resistors. For pins with an external resistor.
    case none

    /// Enable the internal pull-up. Idle high, e.g. a switch against GND.
    case up

    /// Enable the internal pull-down. Idle low, e.g. a switch against VCC.
    case down
  }

  /// The result of a single non-blocking edge sample.
  enum Edge {
    /// The level is unchanged since the previous sample.
    case none

    /// The level went from low to high.
    case rising

    /// The level went from high to low.
    case falling
  }

  // MARK: - Private helpers -

  /// Compute the address of the pin's CTRL register in IO_BANK0.
  /// Note: STATUS is at +0 and CTRL at +4 for each pin, with an 8-byte stride.
  ///
  /// - Parameter pin: GPIO pin number (0...29)
  /// - Returns: The 32-bit memory address of the CTRL register for `pin`.
  @inline(__always)
  private static func ioGPIOCtrlAddress(pin: UInt32) -> UInt32 {
    ioBank0Base + 0x004 + (pin * 8)
  }

  /// Compute the address of the pad control register for `pin`.
  /// Pad registers control pull-ups/pull-downs and drive strength.
  ///
  /// - Parameter pin: GPIO pin number (0...29)
  /// - Returns: The 32-bit memory address of the pad control register.
  @inline(__always)
  private static func padsGPIOAddress(pin: UInt32) -> UInt32 {
    padsBank0Base + 0x004 + (pin * 4)
  }

  /// Release IO_BANK0 and PADS_BANK0 from reset and wait for completion.
  ///
  /// Clearing a reset bit is idempotent, so repeated calls are harmless.
  /// Never set these bits again after start-up: that returns every pin in
  /// both banks to its default function and detaches configured peripherals.
  private static func releaseBanksFromReset() {
    let resetMask = resetIOBank0Bit | resetPadsBank0Bit
    mmioClearBits(resetsBase + resetsResetOffset, resetMask)
    while (mmioRead(resetsBase + resetsResetDoneOffset) & resetMask) != resetMask {}
  }

  /// Apply a pull selection, leaving all other pad bits untouched.
  ///
  /// - Parameters:
  ///   - pull: The requested pull configuration.
  ///   - pin: GPIO pin number to configure.
  private static func applyPull(_ pull: Pull, pin: UInt32) {
    switch pull {
    case .unchanged: return
    case .none: disablePadPulls(pin: pin)
    case .up: enablePadPullUp(pin: pin)
    case .down: enablePadPullDown(pin: pin)
    }
  }

  // MARK: - Function mux -

  /// Set the function (mux) for a GPIO pin.
  ///
  /// Only this pin is affected. Other pins that could carry the same
  /// peripheral stay available for other uses.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number
  ///   - funcSel: Function select value from the datasheet (e.g., 5=SIO, 4=PWM)
  static func setFunction(pin: UInt32, funcSel: UInt32) {
    releaseBanksFromReset()
    mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSel)
  }

  /// Configure a GPIO pin for one of the RP2040's I2C peripherals.
  ///
  /// This is the Swift Embedded equivalent of the Pico SDK calls
  /// `gpio_set_function(pin, GPIO_FUNC_I2C)` and `gpio_pull_up(pin)`.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to route to its I2C controller.
  ///   - enablePullUp: Whether to enable the internal pull-up resistor.
  static func configureAsI2C(pin: UInt32, enablePullUp: Bool = true) {
    if enablePullUp {
      enablePadPullUp(pin: pin)
    }
    setFunction(pin: pin, funcSel: funcSelI2C)
  }

  // MARK: - Pin configuration -

  /// Configure a GPIO pin for CPU-controlled output.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to configure.
  ///   - pull: Pull configuration. Outputs rarely need one.
  static func configureAsSIOOutput(pin: UInt32, pull: Pull = .unchanged) {
    releaseBanksFromReset()

    // Enable the output driver, keep the input buffer on so the pin can be
    // read back.
    let padAddress = padsGPIOAddress(pin: pin)
    var pad = mmioRead(padAddress)
    pad &= ~padODBit
    pad |= padIEBit
    mmioWrite(padAddress, pad)

    applyPull(pull, pin: pin)

    // Route GPIO function mux to SIO and enable output (set OE bit).
    mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
    mmioWrite(sioBase + sioGPIOOESetOffset, 1 << pin)
  }

  /// Configure a GPIO pin for CPU-controlled input (readable by software).
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to configure.
  ///   - pull: Pull configuration. The reset default is a pull-down, so an
  ///     input left at `.unchanged` idles low. A switch against GND needs
  ///     `.up` and a falling edge, a switch against VCC `.down` and a rising
  ///     edge. Use `.none` for modules carrying their own resistor.
  static func configureAsSIOInput(pin: UInt32, pull: Pull = .unchanged) {
    releaseBanksFromReset()

    // Enable the input buffer. Without IE the pin always reads low.
    let padAddress = padsGPIOAddress(pin: pin)
    var pad = mmioRead(padAddress)
    pad |= padIEBit
    pad &= ~padODBit
    mmioWrite(padAddress, pad)

    applyPull(pull, pin: pin)

    // Route GPIO function mux to SIO and disable output (clear OE bit).
    mmioWrite(ioGPIOCtrlAddress(pin: pin), funcSelSIO)
    mmioWrite(sioBase + sioGPIOOEClrOffset, 1 << pin)
  }

  /// Enable the internal pull-up resistor on a pin's pad.
  ///
  /// - Parameter pin: GPIO pin number to enable pull-up for.
  static func enablePadPullUp(pin: UInt32) {
    releaseBanksFromReset()

    let padAddress = padsGPIOAddress(pin: pin)
    var val = mmioRead(padAddress)
    val |= padPUEBit
    val &= ~padPDEBit
    mmioWrite(padAddress, val)
  }

  /// Enable the internal pull-down resistor on a pin's pad.
  ///
  /// - Parameter pin: GPIO pin number to enable pull-down for.
  static func enablePadPullDown(pin: UInt32) {
    releaseBanksFromReset()

    let padAddress = padsGPIOAddress(pin: pin)
    var val = mmioRead(padAddress)
    val |= padPDEBit
    val &= ~padPUEBit
    mmioWrite(padAddress, val)
  }

  /// Disable internal pull resistors on a pin's pad.
  ///
  /// - Parameter pin: GPIO pin number to clear pull configuration for.
  static func disablePadPulls(pin: UInt32) {
    releaseBanksFromReset()

    let padAddress = padsGPIOAddress(pin: pin)
    var val = mmioRead(padAddress)
    val &= ~padPUEBit
    val &= ~padPDEBit
    mmioWrite(padAddress, val)
  }

  // MARK: - Level access -

  /// Read the current logical level of a GPIO pin.
  ///
  /// - Parameter pin: GPIO pin number to read.
  /// - Returns: `true` if the pin reads as logic high, otherwise `false`.
  @inline(__always)
  static func read(pin: UInt32) -> Bool {
    (mmioRead(sioBase + sioGPIOInOffset) & (1 << pin)) != 0
  }

  /// Set the output level for `pin` to logical high (1).
  /// Uses the SIO OUT_SET alias to avoid a read-modify-write sequence.
  ///
  /// - Parameter pin: GPIO pin number to set high.
  @inline(__always)
  static func setHigh(pin: UInt32) {
    mmioWrite(sioBase + sioGPIOOutSetOffset, 1 << pin)
  }

  /// Set the output level for `pin` to logical low (0).
  /// Uses the SIO OUT_CLR alias to avoid a read-modify-write sequence.
  ///
  /// - Parameter pin: GPIO pin number to set low.
  @inline(__always)
  static func setLow(pin: UInt32) {
    mmioWrite(sioBase + sioGPIOOutClrOffset, 1 << pin)
  }

  /// Drive `pin` to an explicit level.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to drive.
  ///   - high: `true` drives the pin high, `false` drives it low.
  @inline(__always)
  static func write(pin: UInt32, high: Bool) {
    if high { setHigh(pin: pin) } else { setLow(pin: pin) }
  }

  /// Toggle the output state of a GPIO pin.
  /// Uses the SIO OUT_XOR alias, so no other pin is disturbed.
  ///
  /// - Parameter pin: GPIO pin number to toggle.
  @inline(__always)
  static func toggle(pin: UInt32) {
    mmioWrite(sioBase + sioGPIOOutXorOffset, 1 << pin)
  }

  // MARK: - Time base -

  /// The RP2040's free-running microsecond counter.
  ///
  /// Driven by the watchdog tick that the Pico SDK start-up code configures.
  /// The value wraps every 2^32 microseconds, about every 71 minutes, so
  /// compare timestamps with `&-`; plain `-` would trap on underflow.
  ///
  /// - Returns: Microseconds since boot, modulo 2^32.
  @inline(__always)
  static func micros() -> UInt32 {
    mmioRead(timerBase + timerRawLOffset)
  }

  /// Microseconds elapsed since a timestamp taken with `micros()`.
  ///
  /// - Parameter start: A previously captured `micros()` value.
  /// - Returns: The elapsed microseconds, correct across a counter wrap.
  @inline(__always)
  static func elapsedUs(since start: UInt32) -> UInt32 {
    micros() &- start
  }

  // MARK: - Non-blocking edge detection -

  /// Detects level changes on a pin by sampling, without blocking.
  ///
  /// Call `poll()` once per main loop pass. The detector remembers the
  /// previous level, so it reports an edge that happened between two calls.
  /// The `waitFor…` functions cannot do this: they re-read the starting level
  /// on entry and only see edges occurring while they run.
  ///
  /// The instance has to outlive the loop. Recreating it each pass resets the
  /// remembered level and reports a phantom edge every time.
  struct EdgeDetector {
    /// The observed GPIO pin.
    let pin: UInt32

    /// Level seen during the previous `poll()`.
    private var last: Bool

    /// Creates a detector for an already configured input pin.
    ///
    /// - Parameters:
    ///   - pin: GPIO pin number to observe.
    ///   - initialLevelHigh: The pin's idle level, so the first poll does not
    ///     report a phantom edge. `true` for pull-up, `false` for pull-down.
    init(pin: UInt32, initialLevelHigh: Bool) {
      self.pin = pin
      self.last = initialLevelHigh
    }

    /// Samples the pin once and returns immediately.
    ///
    /// - Returns: The edge observed since the previous call, if any.
    mutating func poll() -> Edge {
      let current = RP2040GPIO.read(pin: pin)
      defer { last = current }

      if current == last { return .none }
      return current ? .rising : .falling
    }

    /// The level recorded at the most recent `poll()`.
    var level: Bool { last }
  }

  // MARK: - Blocking waits -

  /// Wait until the pin reads high, or the timeout elapses.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to watch.
  ///   - timeoutUs: Maximum time to wait, in microseconds.
  /// - Returns: `true` if the pin reached high, `false` if it timed out.
  static func waitForHigh(pin: UInt32, timeoutUs: UInt32) -> Bool {
    let start = micros()
    while micros() &- start < timeoutUs {
      if read(pin: pin) { return true }
    }
    return false
  }

  /// Wait until the pin reads low, or the timeout elapses.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to watch.
  ///   - timeoutUs: Maximum time to wait, in microseconds.
  /// - Returns: `true` if the pin reached low, `false` if it timed out.
  static func waitForLow(pin: UInt32, timeoutUs: UInt32) -> Bool {
    let start = micros()
    while micros() &- start < timeoutUs {
      if !read(pin: pin) { return true }
    }
    return false
  }

  /// Wait for a rising edge (low -> high) on `pin`, or until the timeout.
  ///
  /// Only edges occurring while this function runs are seen. Use
  /// `EdgeDetector` to catch edges while other work happens.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to watch.
  ///   - timeoutUs: Maximum time to wait, in microseconds.
  /// - Returns: `true` if a rising edge occurred, `false` if it timed out.
  static func waitForRisingEdge(pin: UInt32, timeoutUs: UInt32) -> Bool {
    let start = micros()
    var last = read(pin: pin)
    while micros() &- start < timeoutUs {
      let current = read(pin: pin)
      if !last && current { return true }
      last = current
    }
    return false
  }

  /// Wait for a falling edge (high -> low) on `pin`, or until the timeout.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to watch.
  ///   - timeoutUs: Maximum time to wait, in microseconds.
  /// - Returns: `true` if a falling edge occurred, `false` if it timed out.
  static func waitForFallingEdge(pin: UInt32, timeoutUs: UInt32) -> Bool {
    let start = micros()
    var last = read(pin: pin)
    while micros() &- start < timeoutUs {
      let current = read(pin: pin)
      if last && !current { return true }
      last = current
    }
    return false
  }

  /// Measure how long `pin` stays at one level, up to a timeout.
  ///
  /// Useful for one-wire protocols that encode bits as pulse lengths.
  ///
  /// - Parameters:
  ///   - pin: GPIO pin number to watch.
  ///   - levelHigh: The level whose duration is measured.
  ///   - timeoutUs: Maximum time to wait, in microseconds.
  /// - Returns: The pulse length in microseconds, or `nil` on timeout.
  static func measurePulse(pin: UInt32, levelHigh: Bool, timeoutUs: UInt32) -> UInt32? {
    let start = micros()
    while read(pin: pin) == levelHigh {
      if micros() &- start >= timeoutUs { return nil }
    }
    return micros() &- start
  }

  // MARK: - Board pin constants -

  /// GPIO pin number of the on-board LED for the Raspberry Pi Pico.
  ///
  /// On the **Pico** this is GPIO 25, a regular SIO-addressable output.
  /// On the **Pico W** the on-board LED is wired to the CYW43 wireless chip
  /// and is not reachable through normal GPIO MMIO. The virtual pin number
  /// used by the Pico SDK for that chip is 32. `Scripts/switch.sh` updates
  /// this constant automatically when you switch between board targets.
  static let internalLedPin: UInt32 = 25

  // MARK: - Deprecated -

  /// Configure a GPIO pin for the RP2040's I2C peripheral.
  @available(*, deprecated, renamed: "configureAsI2C(pin:enablePullUp:)")
  static func configureAsI2C1(pin: UInt32, enablePullUp: Bool = true) {
    configureAsI2C(pin: pin, enablePullUp: enablePullUp)
  }

  /// Typo-tolerant alias for `configureAsSIOInput`.
  @available(*, deprecated, renamed: "configureAsSIOInput(pin:pull:)")
  static func configureAsSIInput(pin: UInt32) {
    configureAsSIOInput(pin: pin)
  }
}
