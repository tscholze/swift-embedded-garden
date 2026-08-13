extension DHT11 {
  /// Configuration for an AZ-Delivery KY-015 DHT11 sensor.
  struct Configuration {
    /// RP2040 GPIO used for the sensor data line.
    let dataPin: UInt32
  }
}
