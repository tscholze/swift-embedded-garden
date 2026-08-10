// RP2040 firmware bootstrap and the minimal C boundary for Swift Embedded.
// Pico SDK startup lands here, then main jumps into swift_main().

#include "pico/stdlib.h"
#include <errno.h>
#include <malloc.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

// RASPBERRYPI_PICO_W is a plain #define in the board header, always reachable via pico/stdlib.h.
#if defined(RASPBERRYPI_PICO_W)
#include "pico/cyw43_arch.h"
#endif

extern void swift_main(void);

// Swift Embedded runtime may request aligned allocations through
// posix_memalign; newlib on Pico exposes memalign instead.
int posix_memalign(void **memptr, size_t alignment, size_t size) {
  if ((alignment < sizeof(void *)) || ((alignment & (alignment - 1)) != 0)) {
    return EINVAL;
  }

  void *ptr = memalign(alignment, size);
  if (!ptr) {
    return ENOMEM;
  }

  *memptr = ptr;
  return 0;
}

// Exposed to Swift so delay loops use the Pico SDK timer implementation.
void pico_delay_ms(uint32_t ms) {
  sleep_ms(ms);
}

void pico_delay_us(uint32_t us) {
  sleep_us(us);
}

// Swift's raw-pointer loads and stores are not volatile. These functions retain
// the required volatile MMIO semantics while keeping register maps in Swift.
uint32_t rp2040_mmio_read(uint32_t address) {
  return *(volatile const uint32_t *)(uintptr_t)address;
}

void rp2040_mmio_write(uint32_t address, uint32_t value) {
  *(volatile uint32_t *)(uintptr_t)address = value;
}

// Initialises the on-board LED for the active board target.
// On Pico:   configures GPIO 25 as a SIO output (fast MMIO path).
// On Pico W: initialises the CYW43 wireless chip via cyw43_arch_init()
//            so its GPIO expander is ready to use.
// Call once before any pico_board_led_set() call.
void pico_board_led_init(void) {
#if defined(RASPBERRYPI_PICO_W)
    cyw43_arch_init();
#else
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
#endif
}

// Sets the on-board LED state.
// On Pico:   drives GPIO 25 directly through the SIO block.
// On Pico W: forwards the request to the CYW43 GPIO expander.
void pico_board_led_set(bool on) {
#if defined(RASPBERRYPI_PICO_W)
    cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, on);
#else
    gpio_put(PICO_DEFAULT_LED_PIN, on);
#endif
}

int main(void) {
  swift_main();
  for (;;) {
    tight_loop_contents();
  }
}
