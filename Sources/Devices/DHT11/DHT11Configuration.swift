/// Configuration for an AZ-Delivery KY-015 DHT11 sensor.
struct DHT11Configuration {
  /// RP2040 GPIO used for the sensor data line.
  let dataPin: UInt32

  init(dataPin: UInt32) {
    self.dataPin = dataPin
  }
}
