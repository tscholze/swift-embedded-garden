/// Demonstrates reading values from a DHT11 sensor using GPIO bit-banging.
/// A slow blink indicates a successful read, while three quick blinks indicate a failed read.
struct DHT11Sample {
  // MARK: - GPIO Pin Assignments -

  private let sensor: DHT11

  // MARK: - Initialization -

  /// Initializes the sample and configures the DHT11 sensor pin.
  /// To run the sample, call the never-returning `run()` method.
  ///
  /// - Parameter configuration: The configuration for the DHT11 sensor.
  init(configuration: DHT11.Configuration) {
    RP2040GPIO.configureLed()

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
    RP2040GPIO.setLedHigh()
    pico_delay_ms(500)
    RP2040GPIO.setLedLow()
    pico_delay_ms(500)

    // The reading is valid, so the LED briefly pulses for a successful sample.
    _ = reading.temperatureC
    _ = reading.humidityPercent
  }

  private func showFailure() {
    for _ in 0..<3 {
      RP2040GPIO.setLedHigh()
      pico_delay_ms(80)
      RP2040GPIO.setLedLow()
      pico_delay_ms(120)
    }
  }
}
