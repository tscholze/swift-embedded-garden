// C bootstrap for RP2040 startup.
// Pico SDK startup lands here, then we jump into Swift embedded firmware code.

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

// Exposed to Swift so blink timing is driven by a hardware-backed SDK delay.
void pico_delay_ms(uint32_t ms) {
  sleep_ms(ms);
}

int main(void) {
  swift_main();
  for (;;) {
    tight_loop_contents();
  }
}
