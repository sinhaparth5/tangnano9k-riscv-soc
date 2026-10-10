#define UART_DATA   (*(volatile unsigned *)0x10000000)
#define UART_STATUS (*(volatile unsigned *)0x10000004)
#define ACC_X       (*(volatile unsigned *)0x20000000)
#define ACC_N       (*(volatile unsigned *)0x20000004)
#define ACC_CTRL    (*(volatile unsigned *)0x20000008)
#define ACC_STATUS  (*(volatile unsigned *)0x2000000C)
#define VRAM        ((volatile unsigned char *)0x30000000)   // 90x30 chars, write-only
#define VOFF        (*(volatile unsigned *)0x30001000)
#define COLS 90
#define ROWS 30
#define TX_BUSY 1
#define RX_FULL 2

/* ---- text screen: cursor kept in software; scrolling rotates the hardware row offset ---- */
static int cx, cy, top;                       // cursor column/row (logical), first physical row
static volatile unsigned char *vrow(int r) { return VRAM + ((r + top) % ROWS) * COLS; }
static void vblank(int r) { for (int i = 0; i < COLS; i++) vrow(r)[i] = ' '; }
static void vnl(void) {
    cx = 0;
    if (cy < ROWS - 1) { cy++; return; }
    top = (top + 1) % ROWS; VOFF = top;       // row 0 moves to the bottom
    vblank(ROWS - 1);
}
static void vputc(char c) {
    if (c == '\r') cx = 0;
    else if (c == '\n') vnl();
    else if (c == '\b') { if (cx) cx--; }
    else if (c >= ' ' && c < 127) { vrow(cy)[cx] = c; if (++cx == COLS) vnl(); }
}
static void vclear(void) { for (int r = 0; r < ROWS; r++) vblank(r); cx = cy = top = 0; VOFF = 0; }

static void putc_(char c) { vputc(c); while (UART_STATUS & TX_BUSY); UART_DATA = c; }
static void puts_(const char *s) { while (*s) putc_(*s++); }
static void putu(unsigned v) {
    char b[10]; int i = 0;
    do { b[i++] = '0' + v % 10; v /= 10; } while (v);
    while (i) putc_(b[--i]);
}
static void puthex(unsigned v) {
    for (int i = 28; i >= 0; i -= 4) putc_("0123456789abcdef"[(v >> i) & 15]);
}
static char getc_(void) { while (!(UART_STATUS & RX_FULL)); return UART_DATA; }
static unsigned cycles(void) { unsigned c; asm volatile("rdcycle %0" : "=r"(c)); return c; }
static unsigned xs(unsigned x) { x ^= x << 13; x ^= x >> 17; x ^= x << 5; return x; }

static int streq(const char *a, const char *b) {
    while (*a && *a == *b) a++, b++;
    return *a == *b;
}
static unsigned parse(const char *s, int base) {   // optional 0x prefix when base 16
    unsigned v = 0;
    if (base == 16 && s[0] == '0' && s[1] == 'x') s += 2;
    for (; *s; s++) {
        int d = *s >= 'a' ? *s - 'a' + 10 : *s >= 'A' ? *s - 'A' + 10 : *s - '0';
        v = v * base + d;
    }
    return v;
}

static void hw_run(unsigned n) {
    ACC_N = n; ACC_CTRL = 1;
    while (ACC_STATUS & 1);
}

static void bench(unsigned n) {
    unsigned x = 1, t0 = cycles();
    for (unsigned i = 0; i < n; i++) x = xs(x);
    unsigned sw = cycles() - t0;
    t0 = cycles();
    ACC_X = 1; hw_run(n);
    unsigned r = ACC_X, hw = cycles() - t0;
    puts_("xorshift32 x"); putu(n);
    puts_(": SW "); putu(sw); puts_(" cyc, HW "); putu(hw);
    puts_(" cyc, speedup "); putu(sw / hw); puts_("x, ");
    puts_(r == x ? "match\r\n" : "MISMATCH #\r\n");
}

static void run(int argc, char **argv) {
    char *c = argv[0];
    if (streq(c, "help")) {
        puts_("help                 this list\r\n"
              "rand [n]             advance HW PRNG n steps (default 1), print state\r\n"
              "seed <hex>           set PRNG state\r\n"
              "bench [n]            SW vs HW cycles for n steps (default 1000)\r\n"
              "peek <hexaddr>       read word\r\n"
              "poke <hexaddr> <hex> write word\r\n"
              "cycles               CPU cycle counter\r\n");
    } else if (streq(c, "rand")) {
        hw_run(argc > 1 ? parse(argv[1], 10) : 1);
        puthex(ACC_X); puts_("\r\n");
    } else if (streq(c, "seed") && argc > 1) {
        ACC_X = parse(argv[1], 16);
    } else if (streq(c, "bench")) {
        bench(argc > 1 ? parse(argv[1], 10) : 1000);
    } else if (streq(c, "peek") && argc > 1) {
        puthex(*(volatile unsigned *)parse(argv[1], 16)); puts_("\r\n");
    } else if (streq(c, "poke") && argc > 2) {
        *(volatile unsigned *)parse(argv[1], 16) = parse(argv[2], 16);
    } else if (streq(c, "cycles")) {
        putu(cycles()); puts_("\r\n");
    } else {
        puts_("? argc="); putu(argc); puts_(" cmd=");
        for (char *q = c; *q; q++) { puthex(*q); putc_(' '); }   // dump bytes to spot hidden chars
        puts_("(type help)\r\n");
    }
}

int main(void) {
    char line[64]; int len = 0;
    vclear();
    puts_("\r\n[SoC Boot] Tang Nano 9K PicoRV32 Online!\r\n"
          "Initializing MMIO Peripherals... Done.\r\nType help\r\n> ");
    for (;;) {
        char c = getc_();
        if (c == '\r') {
            puts_("\r\n");
            line[len] = 0;
            char *argv[3]; int argc = 0;
            for (char *p = line; *p && argc < 3; ) {
                while (*p == ' ') *p++ = 0;
                if (*p) argv[argc++] = p;
                while (*p && *p != ' ') p++;
            }
            if (argc) run(argc, argv);
            len = 0;
            puts_("> ");
        } else if (c == 0x7f || c == 8) {
            if (len) { len--; puts_("\b \b"); }
        } else if (c >= ' ' && len < 63) {
            line[len++] = c; putc_(c);
        }
    }
}
