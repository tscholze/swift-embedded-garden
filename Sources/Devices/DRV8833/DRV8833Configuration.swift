/// Configuration values for a DRV8833 dual H-bridge driver.
///
/// The driver uses one GPIO pair per bridge: one input receives PWM while the
/// other is held low for forward motion, and the pair is swapped for reverse
/// motion.
struct DRV8833Configuration {
  /// PWM-capable GPIO used for bridge A input 1.
  let motorAIn1Pin: UInt32

  /// PWM-capable GPIO used for bridge A input 2.
  let motorAIn2Pin: UInt32

  /// PWM-capable GPIO used for bridge B input 1.
  let motorBIn1Pin: UInt32

  /// PWM-capable GPIO used for bridge B input 2.
  let motorBIn2Pin: UInt32

  /// PWM frequency used for all four bridge inputs.
  let pwmFrequencyHz: UInt32

  /// Creates a DRV8833 configuration.
  ///
  /// - Parameters:
  ///   - motorAIn1Pin: GPIO wired to AIN1.
  ///   - motorAIn2Pin: GPIO wired to AIN2.
  ///   - motorBIn1Pin: GPIO wired to BIN1.
  ///   - motorBIn2Pin: GPIO wired to BIN2.
  ///   - pwmFrequencyHz: PWM frequency applied to the bridge inputs.
  init(
    motorAIn1Pin: UInt32,
    motorAIn2Pin: UInt32,
    motorBIn1Pin: UInt32,
    motorBIn2Pin: UInt32,
    pwmFrequencyHz: UInt32 = 1_000
  ) {
    self.motorAIn1Pin = motorAIn1Pin
    self.motorAIn2Pin = motorAIn2Pin
    self.motorBIn1Pin = motorBIn1Pin
    self.motorBIn2Pin = motorBIn2Pin
    self.pwmFrequencyHz = pwmFrequencyHz
  }
}
