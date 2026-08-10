/// Firmware entry point selected by the C bootstrap.
///
/// Switch the invoked sample to select a different firmware demonstration.
/// The current default is the rotary/SSD1306 sample.

@_cdecl("swift_main")
public func swift_main() -> Never {
  // Main and combined sample
  Sample().run()

  // 1. Blink onboard LED (GPIO 25) at 2Hz.
  // blink()

  // 4. Demonstrate rotary encoder input with a traffic light output.
  // Sample().run()

  // 5. Read temperature and humidity from a KY-015 DHT11 sensor.
  // GPIOSample().run()

  // 6. Demonstrate buzzer.
  // BuzzerSample().run()

  // 7. Keep onboard LED on while button is pressed.
  // ButtonSample().run()

  // 8. Demonstrate the DRV8833 dual H-bridge driver.
  // DRV8833Sample().run()

  // 9. DHT11 sample with LED feedback for success/failure.
  // DHT11Sample().run()
}

// MARK: - Samples -

/// Blinks the RP2040 Pico onboard LED forever for a minimal GPIO smoke test.
private func blink() -> Never {
  RP2040GPIO.configureLed()

  while true {
    RP2040GPIO.setLedHigh()
    pico_delay_ms(500)
    RP2040GPIO.setLedLow()
    pico_delay_ms(500)
  }
}
