/// Demonstrates a DRV8833 dual H-bridge driver for two small brushed DC motors.
///
/// Example pin assignment:
/// - AIN1 -> GP6
/// - AIN2 -> GP7
/// - BIN1 -> GP8
/// - BIN2 -> GP9
///
/// Wire the DRV8833 VM pin to the motor supply, VCC to 3.3V logic, and GND to
/// the Pico ground. Motor A connects to AOUT1/AOUT2, and Motor B connects to
/// BOUT1/BOUT2.
struct DRV8833Sample {
  // MARK: - Wiring -

  /// Wiring used by the sample.
  private let configuration: DRV8833Configuration

  // MARK: - Initialization -

  /// Creates the sample with example wiring.
  ///
  /// - Parameter configuration: Wiring used by the sample.
  init(
    configuration: DRV8833Configuration = DRV8833Configuration(
      motorAIn1Pin: 6,
      motorAIn2Pin: 7,
      motorBIn1Pin: 8,
      motorBIn2Pin: 9,
      pwmFrequencyHz: 1_000
    )
  ) {
    self.configuration = configuration
  }

  // MARK: - Sample run -

  /// Runs the DRV8833 sample forever.
  func run() -> Never {
    let driver = DRV8833(configuration: configuration)

    guard case .success = driver.initialize() else {
      motorFaultLoop(blinks: 1)
    }

    while true {
      // Drive the two bridges in opposite directions for a visible demo.
      driver.setMotorA(speedPercent: 60)
      driver.setMotorB(speedPercent: -60)
      pico_delay_ms(1_500)

      driver.stopAll()
      pico_delay_ms(500)

      // Reverse the motion so both directions are easy to verify.
      driver.setMotorA(speedPercent: -60)
      driver.setMotorB(speedPercent: 60)
      pico_delay_ms(1_500)

      // Use brake mode briefly before the next cycle.
      driver.stopAll(brake: true)
      pico_delay_ms(750)
    }
  }

  // MARK: - Private helpers -

  /// Signals a driver failure on the Pico onboard LED without requiring UART.
  ///
  /// - Parameter blinks: Number of short pulses emitted before each long pause.
  private func motorFaultLoop(blinks: UInt32) -> Never {
    let ledPin: UInt32 = 25
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)

    while true {
      for _ in 0..<blinks {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(120)
        RP2040GPIO.setLow(pin: ledPin)
        pico_delay_ms(180)
      }
      pico_delay_ms(1_000)
    }
  }
}
