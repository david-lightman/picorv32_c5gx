/* software/sections.lds */
MEMORY {
    ram : ORIGIN = 0x10000000, LENGTH = 0x80000 /* 512KB SRAM */
}

SECTIONS {
    .text : {
        *(.text.start)
        *(.text)
    } > ram
    .rodata : { *(.rodata) } > ram
    .data : { *(.data) } > ram
    .bss : { *(.bss) } > ram
}
