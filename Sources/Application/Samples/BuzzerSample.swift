/// Demonstrates using the Buzzer device.
struct BuzzerSample {

  // MARK: - Interal properties -

  /// The GPIO pin number to which the buzzer is connected.
  let triggerPin: UInt32

  // MARK: - Sample run -

  func run() -> Never {

    let buzzer = Buzzer(
      configuration: Buzzer.Configuration(triggerPin: triggerPin)
    )

    while true {
      buzzer.buzz()
      pico_delay_ms(1_000)
      buzzer.buzz()
      pico_delay_ms(1_000)
    }
  }
}
