OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 16K }
SECTIONS {
    .text   : { *(.text._start) *(.text*) *(.rodata*) *(.srodata*) } > RAM
    .data   : { *(.data*) *(.sdata*) } > RAM
    .bss    : { _bss = .; *(.bss*) *(.sbss*) *(COMMON) _ebss = .; } > RAM
}
