/// Motor bridge selection used by ``DRV8833``.
enum DRV8833Motor {
  /// The first bridge, also called motor A.
  case motorA

  /// The second bridge, also called motor B.
  case motorB
}

/// A minimal DRV8833 dual H-bridge controller for small brushed DC motors.
///
/// The driver configures each bridge input for PWM output and then drives the
/// H-bridge by switching the duty cycle between the two input pins. Positive
/// speed values move the selected motor forward, negative values reverse it,
/// and zero means coast. This driver is for brushed DC motors only; SG90-style
/// hobby servos require a dedicated servo pulse driver.
struct DRV8833 {
  // MARK: - Private properties -

  /// Wiring and PWM frequency used by the driver instance.
  private let configuration: DRV8833Configuration

  // MARK: - Initialization -

  /// Creates a driver for the supplied wiring configuration.
  ///
  /// - Parameter configuration: GPIO and PWM settings for the H-bridge.
  init(configuration: DRV8833Configuration) {
    self.configuration = configuration
  }

  // MARK: - Setup -

  /// Configures all four bridge inputs for PWM output.
  ///
  /// The bridge pins are configured as PWM outputs with a 0% duty cycle so
  /// the motors stay off until the caller explicitly drives them.
  ///
  /// - Returns: Success when all pins were configured, or the first PWM error.
  func initialize() -> Result<Void, RP2040PWM.PWMError> {
    switch configureMotorPins(
      in1Pin: configuration.motorAIn1Pin,
      in2Pin: configuration.motorAIn2Pin
    ) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    switch configureMotorPins(
      in1Pin: configuration.motorBIn1Pin,
      in2Pin: configuration.motorBIn2Pin
    ) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    return .success(())
  }

  // MARK: - Motor control -

  /// Drives motor A with a signed speed percentage.
  ///
  /// Positive values move the motor in the wiring's forward direction. Negative
  /// values reverse the direction. Zero leaves the bridge in coast mode.
  ///
  /// - Parameter speedPercent: Signed speed percentage from -100 to 100.
  func setMotorA(speedPercent: Double) {
    setMotor(
      motor: .motorA,
      speedPercent: speedPercent
    )
  }

  /// Drives motor B with a signed speed percentage.
  ///
  /// Positive values move the motor in the wiring's forward direction. Negative
  /// values reverse the direction. Zero leaves the bridge in coast mode.
  ///
  /// - Parameter speedPercent: Signed speed percentage from -100 to 100.
  func setMotorB(speedPercent: Double) {
    setMotor(
      motor: .motorB,
      speedPercent: speedPercent
    )
  }

  /// Stops motor A by coasting or braking the bridge.
  ///
  /// - Parameter brake: When `true`, both inputs are driven high and the motor
  ///   is electrically braked. When `false`, both inputs are driven low and the
  ///   motor coasts.
  func stopMotorA(brake: Bool = false) {
    stopMotor(
      motor: .motorA,
      brake: brake
    )
  }

  /// Stops motor B by coasting or braking the bridge.
  ///
  /// - Parameter brake: When `true`, both inputs are driven high and the motor
  ///   is electrically braked. When `false`, both inputs are driven low and the
  ///   motor coasts.
  func stopMotorB(brake: Bool = false) {
    stopMotor(
      motor: .motorB,
      brake: brake
    )
  }

  /// Stops both bridges by coasting or braking them.
  ///
  /// - Parameter brake: When `true`, both bridges are electrically braked.
  func stopAll(brake: Bool = false) {
    stopMotorA(brake: brake)
    stopMotorB(brake: brake)
  }

  // MARK: - Private helpers -

  /// Configures the two input pins for one bridge.
  ///
  /// The method initializes each pin with the same PWM frequency and a 0%
  /// duty cycle so the bridge starts in a safe off state.
  ///
  /// - Parameters:
  ///   - in1Pin: First bridge input pin.
  ///   - in2Pin: Second bridge input pin.
  /// - Returns: Success when both pins were configured, or the first error.
  private func configureMotorPins(
    in1Pin: UInt32,
    in2Pin: UInt32
  ) -> Result<Void, RP2040PWM.PWMError> {
    switch RP2040PWM.configure(
      pin: in1Pin,
      frequencyHz: configuration.pwmFrequencyHz,
      dutyPercent: 0
    ) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    switch RP2040PWM.configure(
      pin: in2Pin,
      frequencyHz: configuration.pwmFrequencyHz,
      dutyPercent: 0
    ) {
    case .success: break
    case .failure(let error): return .failure(error)
    }

    return .success(())
  }

  /// Applies signed speed to the selected motor bridge.
  ///
  /// The active input gets the PWM duty cycle while the inactive input stays at
  /// 0%. This mirrors how a DRV8833 is typically driven for DC motors.
  ///
  /// - Parameters:
  ///   - motor: Bridge selection.
  ///   - speedPercent: Signed speed percentage from -100 to 100.
  private func setMotor(motor: DRV8833Motor, speedPercent: Double) {
    let clampedSpeedPercent = clamp(speedPercent, lowerBound: -100, upperBound: 100)
    let dutyPercent = abs(clampedSpeedPercent)

    let pins = bridgePins(for: motor)

    // Restore PWM mode if the bridge was previously coasted or braked with SIO.
    _ = configureMotorPins(in1Pin: pins.in1Pin, in2Pin: pins.in2Pin)

    if clampedSpeedPercent > 0 {
      // Forward: drive the first input and keep the second low.
      RP2040PWM.setDuty(pin: pins.in1Pin, dutyPercent: dutyPercent)
      RP2040PWM.setDuty(pin: pins.in2Pin, dutyPercent: 0)
    } else if clampedSpeedPercent < 0 {
      // Reverse: swap the active input and keep the other low.
      RP2040PWM.setDuty(pin: pins.in1Pin, dutyPercent: 0)
      RP2040PWM.setDuty(pin: pins.in2Pin, dutyPercent: dutyPercent)
    } else {
      // Zero speed means coast, so both bridge inputs are low.
      RP2040PWM.setDuty(pin: pins.in1Pin, dutyPercent: 0)
      RP2040PWM.setDuty(pin: pins.in2Pin, dutyPercent: 0)
    }
  }

  /// Stops the selected motor bridge in coast or brake mode.
  ///
  /// - Parameters:
  ///   - motor: Bridge selection.
  ///   - brake: When `true`, both inputs are driven high.
  private func stopMotor(motor: DRV8833Motor, brake: Bool) {
    let pins = bridgePins(for: motor)

    if brake {
      // Brake mode drives both inputs high so the motor is electrically held.
      stopPin(pin: pins.in1Pin, high: true)
      stopPin(pin: pins.in2Pin, high: true)
    } else {
      // Coast mode drives both inputs low and leaves the bridge unpowered.
      stopPin(pin: pins.in1Pin, high: false)
      stopPin(pin: pins.in2Pin, high: false)
    }
  }

  /// Returns the pins that belong to the selected bridge.
  ///
  /// - Parameter motor: Bridge selection.
  /// - Returns: The two GPIO pins that wire into the DRV8833 bridge.
  private func bridgePins(for motor: DRV8833Motor) -> (in1Pin: UInt32, in2Pin: UInt32) {
    switch motor {
    case .motorA:
      return (configuration.motorAIn1Pin, configuration.motorAIn2Pin)
    case .motorB:
      return (configuration.motorBIn1Pin, configuration.motorBIn2Pin)
    }
  }

  /// Switches one bridge input to SIO output mode and drives it to a level.
  ///
  /// - Parameters:
  ///   - pin: Bridge input pin to drive.
  ///   - high: `true` drives the pin high, `false` drives it low.
  private func stopPin(pin: UInt32, high: Bool) {
    RP2040PWM.disable(pin: pin)
    RP2040GPIO.configureAsSIOOutput(pin: pin)
    RP2040GPIO.write(pin: pin, high: high)
  }

  /// Clamps a value to the provided bounds.
  ///
  /// - Parameters:
  ///   - value: Raw value to clamp.
  ///   - lowerBound: Minimum allowed value.
  ///   - upperBound: Maximum allowed value.
  /// - Returns: A value limited to the closed interval `[lowerBound, upperBound]`.
  private func clamp(_ value: Double, lowerBound: Double, upperBound: Double) -> Double {
    min(max(value, lowerBound), upperBound)
  }
}
