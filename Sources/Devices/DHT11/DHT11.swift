/// Minimal DHT11 driver for the RP2040 using direct GPIO bit-banging.
struct DHT11 {
  // MARK: - Internal properties -

  /// Configuration for the DHT11 sensor.
  let configuration: DHT11.Configuration

  // MARK: - Initialization -

  ///
  /// - Parameter configuration:
  init(configuration: DHT11.Configuration) {
    self.configuration = configuration
    configure()
  }

  // MARK: - Internal helper -

  /// Reads a single temperature and humidity sample from the sensor.
  func read() throws -> DHT11Reading {
    let maxAttempts = 3
    for attempt in 0..<maxAttempts {
      do {
        return try readTransaction()
      } catch {
        if attempt == maxAttempts - 1 { throw error }
        pico_delay_ms(5)
      }
    }

    throw DHT11Error.timeout
  }

  // MARK: - Private helper -

  /// Configures the data pin for the DHT11 bus.
  func configure() {
    RP2040GPIO.configureAsSIOOutput(pin: configuration.dataPin)
    RP2040GPIO.setHigh(pin: configuration.dataPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.dataPin)
    pico_delay_ms(250)
  }

  /// Executes one full DHT11 transfer transaction.
  private func readTransaction() throws -> DHT11Reading {
    // Let the pull-up settle before issuing the start signal.
    RP2040GPIO.configureAsSIOInput(pin: configuration.dataPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.dataPin)
    pico_delay_ms(1)

    // Start signal: host pulls data low for at least 18ms, then high.
    RP2040GPIO.configureAsSIOOutput(pin: configuration.dataPin)
    RP2040GPIO.setLow(pin: configuration.dataPin)
    pico_delay_ms(20)
    RP2040GPIO.setHigh(pin: configuration.dataPin)
    pico_delay_us(40)

    // Release the data line so the sensor can drive the response.
    RP2040GPIO.configureAsSIOInput(pin: configuration.dataPin)
    RP2040GPIO.enablePadPullUp(pin: configuration.dataPin)
    pico_delay_us(10)

    // DHT11 handshake: ~80us LOW, then ~80us HIGH.
    guard expectPulse(levelHigh: false) != nil else { throw DHT11Error.timeout }
    guard expectPulse(levelHigh: true) != nil else { throw DHT11Error.timeout }

    var payload = [UInt8](repeating: 0, count: 5)
    for bitIndex in 0..<40 {
      guard let lowCycles = expectPulse(levelHigh: false) else { throw DHT11Error.timeout }
      guard let highCycles = expectPulse(levelHigh: true) else { throw DHT11Error.timeout }

      payload[bitIndex / 8] <<= 1
      if highCycles > lowCycles {
        payload[bitIndex / 8] |= 1
      }
    }

    let checksum = payload[4]
    let expectedChecksum = (payload[0] &+ payload[1] &+ payload[2] &+ payload[3]) & 0xFF
    guard checksum == expectedChecksum else { throw DHT11Error.checksumMismatch }

    return DHT11Reading(
      humidityPercent: payload[0],
      temperatureC: payload[2],
      checksum: checksum
    )
  }

  /// Measures how long the data pin remains at one logic level.
  ///
  /// The returned value is a relative pulse length used to classify each bit.
  private func expectPulse(levelHigh: Bool, timeoutUs: UInt32 = 10_000) -> UInt32? {
    var count: UInt32 = 0
    while RP2040GPIO.read(pin: configuration.dataPin) == levelHigh {
      if count >= timeoutUs { return nil }
      pico_delay_us(1)
      count += 1
    }
    return count
  }

}

/// Parsed reading from a DHT11 temperature and humidity sensor.
struct DHT11Reading {
  let humidityPercent: UInt8
  let temperatureC: UInt8
  let checksum: UInt8
}

/// Errors that can be raised while talking to the DHT11 sensor.
enum DHT11Error: Error {
  case timeout
  case checksumMismatch
}
