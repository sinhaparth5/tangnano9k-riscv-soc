# Tang Nano 9K RISC-V SoC — Roadmap

Board: Tang Nano 9K (GW1NR-9, 8640 LUT, 27 MHz osc on pin 52, 6 active-low LEDs, BL702 USB-UART on pins 17/18).
Toolchain: Yosys → nextpnr-himbaechel (gowin) → Apicula `gowin_pack` → openFPGALoader. Build: `make PHASE=<dir>`.

## Phase 1 — Clock, LEDs, toolchain  (`phases/p1_blink`)
- [x] Install tools; `make PHASE=p1_blink` yields `build/p1_blink.fs`
- [x] `make prog` → LEDs count in binary (top 6 bits of a 25-bit counter, ~0.8 Hz on the slowest LED toggle rate)
- Done when: LEDs count smoothly, no PnR errors.

## Phase 2 — UART Tx/Rx  (`phases/p2_uart`)
- [x] `uart_tx.v`, `uart_rx.v`: 8N1, divisor = 27e6/115200 ≈ 234 (sample mid-bit; 16x oversampling not needed at this baud/clock)
- [x] Top-level echo; testbench (iverilog, `make PHASE=p2_uart sim`) sends a byte, expects it back
- [x] Uncomment `uart_tx`/`uart_rx` in the `.cst`
- Done when: `picocom -b 115200 /dev/ttyUSB1` (BL702 UART is usually the 2nd port; check `ls /dev/ttyUSB*`) echoes typed chars intact.

## Phase 3 — PicoRV32 + BRAM + MMIO UART  (`phases/p3_cpu`)
- [x] Vendor `picorv32.v` (YosysHQ), config RV32IMC-ish (`ENABLE_MUL`/`ENABLE_DIV`, `COMPRESSED_ISA`)
- [x] 16 KB BRAM via `$readmemh` of firmware hex; memory map: `0x0000_0000` RAM, `0x1000_0000` UART
- [x] `fw/`: linker script, `start.S`, `main.c` printing boot banner; toolchain `riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32`
- [x] Check LUT use (4113 of 8640, 47%; est. was 2–3.5k, MUL+DIV+C cost more); watch timing at 27 MHz (71 MHz fmax, passes)
- Done when: banner and prompt appear in the terminal on power-up. (Simulated: `make PHASE=p3_cpu sim` PASS; on-board: pending)

## Phase 4 — Custom accelerator at `0x2000_0000`  (`phases/p4_accel`)
- [x] xorshift32 PRNG, N steps at 1 step/clock (`accel.v`)
- [x] Regs: operands, `CTRL.start`, `STATUS.done`, `RESULT`
- [x] C benchmark: SW vs HW cycle counts via `rdcycle`
- Done when: benchmark prints measured speedup (expect 10–50x on suitable workloads; report whatever is actually measured).

## Notes
- Phase 3+ will want a pre-built RISC-V GCC; Phase 3 firmware flow gets its own Makefile rules then, not before.
- Phases 1-3 verified on board; Phase 4 shell (help, rand, seed, bench, peek, poke, cycles) verified for rand/seed. S1 = reset (pin 4, unverified on board).
- Switching PHASE: run `make clean` first (firmware build is shared at `build/fw.*`).
