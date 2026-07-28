// Minimal Swift Embedded firmware entry point.
// This blink loop demonstrates the layered project shape and MMIO GPIO control.

@_cdecl("swift_main")
public func swift_main() -> Never {

    // 1. Blink onboard LED (GPIO 25) at 2Hz.
    // blink()

    // Traffic light samples
    TrafficLight().run()
}

// MARK: - Samples -

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
func pico_delay_ms(_ ms: UInt32)
