// Board support mapping for Raspberry Pi Pico.
// Extension point: create additional board structs for Pico W or custom RP2040
// boards and switch application wiring without touching hardware primitives.

enum PicoBoard {
    // Raspberry Pi Pico onboard LED is on GPIO25.
    static let onboardLEDPin: UInt32 = 25
}
