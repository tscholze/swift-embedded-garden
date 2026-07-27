// Minimal Swift Embedded firmware entry point.
// This blink loop demonstrates the layered project shape and MMIO GPIO control.

@_cdecl("swift_main")
public func swift_main() -> Never {
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