// Basic RP2040 PWM helpers using MMIO.
// This file provides a small, beginner-friendly API to configure PWM on
// pins, set frequency and duty cycle, and enable/disable PWM output.

enum RP2040PWM {
  // PWM base address and per-slice offsets (from RP2040 datasheet).
  private static let pwmBase: UInt32 = 0x4005_0000
  private static let pwmSliceStride: UInt32 = 0x14

  // Registers inside a slice (offsets from slice base)
  private static let pwmCSROffset: UInt32 = 0x00  // control and status
  private static let pwmDIVOffset: UInt32 = 0x04  // clock divider
  private static let pwmTOPOffset: UInt32 = 0x10  // counter wrap (TOP)
  private static let pwmCCOffset: UInt32 = 0x0C  // channel compare (A/B)

  // Global enable register
  private static let pwmEnOffset: UInt32 = 0x0A0  // global PWM enable register offset from pwmBase

  /// Possible PWM configuration errors.
  enum PWMError: Error {
    case invalidPin
    case invalidFrequency
    case dividerOutOfRange
  }

  /// Map a GPIO pin to the PWM slice and channel.
  /// On RP2040 each GPIO maps to a PWM slice and channel (A/B).
  /// - Parameter pin: GPIO pin number
  /// - Returns: (slice, channel) where channel is 0 for A, 1 for B
  static func sliceAndChannel(forPin pin: UInt32) -> (UInt32, UInt32) {
    let slice = pin / 2
    let channel = pin % 2
    return (slice, channel)
  }

  private static func sliceBase(slice: UInt32) -> UInt32 {
    pwmBase + (slice * pwmSliceStride)
  }

  /// Configure PWM on `pin` with `frequencyHz` and initial `dutyPercent`.
  /// - Parameters:
  ///   - pin: GPIO pin to configure for PWM (must be PWM-capable)
  ///   - frequencyHz: Desired PWM frequency in Hz
  ///   - dutyPercent: Initial duty cycle 0.0...100.0
  /// - Returns: true if configured (quick validation), false otherwise
  static func configure(pin: UInt32, frequencyHz: UInt32, dutyPercent: Double) -> Result<
    Void, PWMError
  > {
    let (slice, channel) = sliceAndChannel(forPin: pin)

    // Basic validation: RP2040 has slices 0..7 (for 16 GPIOs pairs up to 30)
    if slice > 7 { return .failure(.invalidPin) }

    // Select PWM function for the pin (funcSel 2 is PWM in RP2040 datasheet)
    RP2040GPIO.setFunction(pin: pin, funcSel: 2)

    // Compute clock divider and TOP to achieve desired frequency.
    // We'll aim for the maximum TOP (65535) to maximize resolution when possible.
    // PWM input clock is system_clock / divider. divider = sys_clk / (frequency * (TOP+1)).
    // RP2040 DIV register uses 8:4 fixed-point (INT:FRAC where FRAC is 4 bits).
    let sysClk: Double = 125_000_000.0
    let top: UInt32 = 65535
    let denom = Double(frequencyHz) * Double(top + 1)
    if denom == 0 { return .failure(.invalidFrequency) }

    let divider = sysClk / denom
    // allowed divider range: >= 1.0 and <= 255.9375 (255 + 15/16)
    if divider > 255.9375 { return .failure(.dividerOutOfRange) }
    let dividerFixed = UInt32((divider * 16.0).rounded())
    let finalDividerFixed = max(dividerFixed, 1 * 16)

    let sliceBaseAddr = sliceBase(slice: slice)

    // Write divider (8.4 fixed-point) to DIV register
    mmioWrite(sliceBaseAddr + pwmDIVOffset, finalDividerFixed)

    // Write TOP
    mmioWrite(sliceBaseAddr + pwmTOPOffset, top)

    // Compute compare value from dutyPercent
    let duty = UInt32((Double(top) * (dutyPercent / 100.0)).rounded())

    // Write compare to CC register (channel A in low 16, B in high 16)
    var cc = mmioRead(sliceBaseAddr + pwmCCOffset)
    if channel == 0 {
      cc = (cc & 0xffff_0000) | (duty & 0xffff)
    } else {
      cc = (cc & 0x0000_ffff) | ((duty & 0xffff) << 16)
    }
    mmioWrite(sliceBaseAddr + pwmCCOffset, cc)

    // Enable the slice by setting CSR EN bit (bit 0)
    mmioSetBits(sliceBaseAddr + pwmCSROffset, 1)

    // Also set global PWM enable bit for this slice in PWM.EN register
    mmioSetBits(pwmBase + pwmEnOffset, 1 << slice)

    return .success(())
  }

  /// Set PWM duty cycle for a configured pin.
  /// - Parameters:
  ///   - pin: GPIO pin number
  ///   - dutyPercent: Duty cycle 0.0...100.0
  static func setDuty(pin: UInt32, dutyPercent: Double) {
    let (slice, channel) = sliceAndChannel(forPin: pin)
    let sliceBaseAddr = sliceBase(slice: slice)
    let top = mmioRead(sliceBaseAddr + pwmTOPOffset)
    let duty = UInt32((Double(top) * (dutyPercent / 100.0)).rounded()) & 0xffff
    var cc = mmioRead(sliceBaseAddr + pwmCCOffset)
    if channel == 0 {
      cc = (cc & 0xffff_0000) | duty
    } else {
      cc = (cc & 0x0000_ffff) | (duty << 16)
    }
    mmioWrite(sliceBaseAddr + pwmCCOffset, cc)
  }

  /// Disable PWM on the pin (turn off slice output if both channels unused).
  /// - Parameter pin: GPIO pin number
  static func disable(pin: UInt32) {
    let (slice, _) = sliceAndChannel(forPin: pin)
    let sliceBaseAddr = sliceBase(slice: slice)
    // Clear CSR enable bit
    mmioClearBits(sliceBaseAddr + pwmCSROffset, 1)
    // Clear global PWM enable bit for this slice
    mmioClearBits(pwmBase + pwmEnOffset, 1 << slice)
  }
}
