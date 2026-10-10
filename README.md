# Tang Nano 9K RISC-V SoC

PicoRV32 + 16 KB RAM + UART + a memory-mapped xorshift32 accelerator on a Sipeed Tang Nano 9K, built with open-source tools only (Yosys, nextpnr-himbaechel, Apicula, openFPGALoader).

```
 PicoRV32 ── bus ──┬── 0x0000_0000  16 KB BSRAM (code, data, stack)
                   ├── 0x1000_0000  UART  (data, status)  ── USB ── PC terminal
                   └── 0x2000_0000  xorshift32 accelerator (X, N, CTRL, STATUS)
```

Measured on the board: 1000 xorshift32 steps take 50015 cycles in software and 1066 with the accelerator (46x). Details, memory map and resource numbers: [docs/report.pdf](docs/report.pdf).

## Use

```bash
source ~/oss-cad-suite/environment          # Yosys, nextpnr, gowin_pack, openFPGALoader, iverilog
make PHASE=p4_accel sim                     # simulate (p2..p4 have testbenches)
make PHASE=p4_accel prog                    # load to SRAM (lost at power-off)
picocom -b 115200 /dev/ttyUSB1              # open AFTER loading; press S1 for the banner
make docs                                   # build docs/report.pdf
```

Phases: `p1_blink` LED counter, `p2_uart` echo, `p3_cpu` CPU + UART, `p4_accel` accelerator + shell. See [ROADMAP.md](ROADMAP.md).

On Linux, stop ModemManager from probing the board's serial port, or the console receives its own output:

```bash
echo 'ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", ENV{ID_MM_DEVICE_IGNORE}="1"' | sudo tee /etc/udev/rules.d/99-tangnano-mm.rules
```
