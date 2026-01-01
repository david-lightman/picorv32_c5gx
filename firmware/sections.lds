MEMORY {
    mem : ORIGIN = 0x00000000, LENGTH = 0x00000400
}

SECTIONS {
    .text : {
        . = 0x00000000;
        *(.text.start) *(.text)
    } > mem

    .rodata : { *(.rodata) } > mem
    .data :   { *(.data) }   > mem
    .bss :    { *(.bss) }    > mem
}

