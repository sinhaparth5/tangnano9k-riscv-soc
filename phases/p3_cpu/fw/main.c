#define UART_DATA   (*(volatile unsigned *)0x10000000)
#define UART_STATUS (*(volatile unsigned *)0x10000004)
#define TX_BUSY 1
#define RX_FULL 2

static void putc_(char c) { while (UART_STATUS & TX_BUSY); UART_DATA = c; }
static void puts_(const char *s) { while (*s) putc_(*s++); }

int main(void) {
    puts_("\r\n[SoC Boot] Tang Nano 9K PicoRV32 Online!\r\n"
          "Initializing MMIO Peripherals... Done.\r\n> ");
    for (;;) {
        while (!(UART_STATUS & RX_FULL));
        char c = UART_DATA;
        if (c == '\r') puts_("\r\n> ");
        else putc_(c);
    }
}
