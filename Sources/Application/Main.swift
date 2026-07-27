// Minimal Swift Embedded firmware entry point.
// This blink loop demonstrates the layered project shape and MMIO GPIO control.

@_cdecl("swift_main")
public func main() -> Never {
    // 1. Blink the Raspberry Pi Pico onboard LED
    // blinkOnboardLed()

    // 2. Blink a traffic light sequence
    blinkTrafficLight()
}

// MARK: - Samples -

/// Blink the Raspberry Pi Pico onboard LED (GPIO25) in a loop.
private func blinkOnboardLed() -> Never {
    let ledPin = PicoBoard.onboardLEDPin
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)

    while true {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(500)
        RP2040GPIO.setLow(pin: ledPin)
        pico_delay_ms(500)
    }
}

/// Blink a traffic light sequence using GPIO15 (red), 
/// GPIO14 (yellow), and GPIO12 (green).
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

@_silgen_name("pico_delay_ms")
private func pico_delay_ms(_ ms: UInt32)
