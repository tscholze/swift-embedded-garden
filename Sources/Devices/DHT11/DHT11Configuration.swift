/// Configuration for an AZ-Delivery KY-015 DHT11 sensor.
struct DHT11Configuration {
  /// RP2040 GPIO used for the sensor data line.
  let dataPin: UInt32

  /// Friendly human-readable label for the selected wiring.
  let label: String

  init(dataPin: UInt32, label: String = "DHT11") {
    self.dataPin = dataPin
    self.label = label
  }
}
