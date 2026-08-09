/// Demonstrates a DRV8833 dual H-bridge driver for two small brushed DC motors.
///
/// Example pin assignment:
/// - AIN1 -> GP6
/// - AIN2 -> GP7
/// - BIN1 -> GP8
/// - BIN2 -> GP9
/// - nSLEEP -> GP10 (optional, only if your breakout exposes and requires it)
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
      motorAIn1Pin: 14,
      motorAIn2Pin: 15,
      motorBIn1Pin: 8,
      motorBIn2Pin: 9,
      // Set this to a GPIO number only when you wired nSLEEP to the Pico.
      sleepPin: nil,
      pwmFrequencyHz: 20_000
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
      // Drive motor A forward at full power to overcome startup friction.
      driver.setMotorA(speedPercent: 100)
      driver.stopMotorB()
      pico_delay_ms(1_000)

      driver.stopAll()
      pico_delay_ms(500)

      // Reverse motor A to verify both directions.
      driver.setMotorA(speedPercent: -100)
      driver.stopMotorB()
      pico_delay_ms(2_000)
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
