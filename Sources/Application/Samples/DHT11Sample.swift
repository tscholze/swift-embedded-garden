/// Demonstrates reading values from a DHT11 sensor using GPIO bit-banging.
struct DHTS11Sample {
  // MARK: - GPIO Pin Assignments -

  private let ledPin: UInt32 = 25
  private let sensor: DHT11

  // MARK - Initialization -

  init(configuration: DHT11Configuration) {
    sensor = DHT11(configuration: configuration)
    sensor.configure()
  }

  // MARK: - Sample run -

  func run() -> Never {
    while true {
      do {
        let reading = try sensor.read()
        showSuccess(reading: reading)
      } catch {
        showFailure()
      }

      pico_delay_ms(2_000)
    }
  }

  // MARK: - Helper -

  /// Tries to read a sample from the DHT11 sensor.
  ///
  /// **Caution**
  /// Between each reading should be a cooldown the callee must implement.
  ///
  /// - Returns: Found value on success, or `nil` if the reading failed.
  func readSensor() -> DHT11Reading? {
    return try? sensor.read()
  }

  // MARK: - Private helpers -

  private func showSuccess(reading: DHT11Reading) {
    RP2040GPIO.setHigh(pin: ledPin)
    pico_delay_ms(200)
    RP2040GPIO.setLow(pin: ledPin)
    pico_delay_ms(200)

    // The reading is valid, so the LED briefly pulses for a successful sample.
    _ = reading.temperatureC
    _ = reading.humidityPercent
  }

  private func showFailure() {
    for _ in 0..<3 {
      RP2040GPIO.setHigh(pin: ledPin)
      pico_delay_ms(80)
      RP2040GPIO.setLow(pin: ledPin)
      pico_delay_ms(120)
    }
  }
}
