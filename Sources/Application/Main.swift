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
    let ledPin = PicoBoard.onboardLEDPin
    RP2040GPIO.configureAsSIOOutput(pin: ledPin)

    while true {
        RP2040GPIO.setHigh(pin: ledPin)
        pico_delay_ms(250)
        RP2040GPIO.setLow(pin: ledPin)
        pico_delay_ms(250)
    }
}

@_silgen_name("pico_delay_ms")
func pico_delay_ms(_ ms: UInt32)
