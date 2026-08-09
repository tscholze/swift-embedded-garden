/// Firmware entry point selected by the C bootstrap.
///
/// Switch the invoked sample to select a different firmware demonstration.
/// The current default is the rotary/SSD1306 sample.

@_cdecl("swift_main")
public func swift_main() -> Never {
  // Main and combined sample
  // Sample().run()

  DRV8833Sample().run()

  // 1. Blink onboard LED (GPIO 25) at 2Hz.
  // blink()

  // 2. Blink a traffic light sequence using GPIO15, GPIO14, and GPIO12.
  // blinkTrafficLight()

  // 3. Ramp LED brightness using RP2040PWM helpers.
  // PWMSample().run()

  // 4. Demonstrate rotary encoder input with a traffic light output.
  // Sample().run()

  // 5. Read temperature and humidity from a KY-015 DHT11 sensor.
  // GPIOSample().run()

  // 6. Demonstrate buzzer.
  //BuzzerSample().run()

  // 7. Keep onboard LED on while button is pressed.
  // ButtonSample().run()

  // 8. Demonstrate the DRV8833 dual H-bridge driver.
  // DRV8833Sample().run()
}

// MARK: - Samples -

/// Blinks the RP2040 Pico onboard LED forever for a minimal GPIO smoke test.
private func blink() -> Never {
  let ledPin: UInt32 = 25
  RP2040GPIO.configureAsSIOOutput(pin: ledPin)

  while true {
    RP2040GPIO.setHigh(pin: ledPin)
    pico_delay_ms(500)
    RP2040GPIO.setLow(pin: ledPin)
    pico_delay_ms(500)
  }
}

/// Blinks a traffic-light sequence using GPIO15, GPIO14, and GPIO12.
private func blinkTrafficLight() -> Never {
  let redPin = UInt32(15)
  let yellowPin = UInt32(14)
  let greenPin = UInt32(12)

  RP2040GPIO.configureAsSIOOutput(pin: redPin)
  RP2040GPIO.configureAsSIOOutput(pin: yellowPin)
  RP2040GPIO.configureAsSIOOutput(pin: greenPin)

  while true {
    // Red on, others off
    RP2040GPIO.setHigh(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)
    pico_delay_ms(5000)

    // Yellow on, others off
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setHigh(pin: yellowPin)
    RP2040GPIO.setLow(pin: greenPin)
    pico_delay_ms(2000)

    // Green on, others off
    RP2040GPIO.setLow(pin: redPin)
    RP2040GPIO.setLow(pin: yellowPin)
    RP2040GPIO.setHigh(pin: greenPin)
    pico_delay_ms(5000)
  }
}

/// Imports the Pico SDK-backed millisecond delay from the C bootstrap.
@_silgen_name("pico_delay_ms")
func pico_delay_ms(_ ms: UInt32)

/// Imports the Pico SDK-backed microsecond delay from the C bootstrap.
@_silgen_name("pico_delay_us")
func pico_delay_us(_ us: UInt32)
