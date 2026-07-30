// RP2040 firmware bootstrap and the minimal C boundary for Swift Embedded.
// Pico SDK startup lands here, then main jumps into swift_main().

#include "pico/stdlib.h"
#include <errno.h>
#include <malloc.h>
#include <stddef.h>
#include <stdint.h>

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

// Swift's raw-pointer loads and stores are not volatile. These functions retain
// the required volatile MMIO semantics while keeping register maps in Swift.
uint32_t rp2040_mmio_read(uint32_t address) {
  return *(volatile const uint32_t *)(uintptr_t)address;
}

void rp2040_mmio_write(uint32_t address, uint32_t value) {
  *(volatile uint32_t *)(uintptr_t)address = value;
}

int main(void) {
  swift_main();
  for (;;) {
    tight_loop_contents();
  }
}
