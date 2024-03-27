OUTPUT_ARCH(riscv)

MEMORY {
    /* TODO: edit the ram/flash size according to the decided spec*/
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x4000 /* 16 KiB */
	flash (rx): ORIGIN = 0x00100000, LENGTH = 0x4000 /* 16 KiB */
}

SECTIONS {
    /* The program code and other data goes into FLASH */
    .text :
    {
        . = ALIGN(4);
        *(.reset_vector*)
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
        *(.rodata)         /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)        /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
        . = ALIGN(4);
        _etext = .;        /* define a global symbol at end of code */
        _sidata = _etext;  /* This is used by the startup to initialize data */
    } >flash
    
    /* Initialized data section */
    .data : AT ( _sidata )
    {
        . = ALIGN(4);
        _sdata = .;
        _ram_start = .;
        *(.data)           /* .data sections */
        *(.data*)          /* .data* sections */
        *(.sdata)           /* .sdata sections */
        *(.sdata*)          /* .sdata* sections */
        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end */
    } >ram

    /* Uninitialized data section */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end; used by startup code */
    } >ram

    /* Define the start of the heap */
    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;
    } >ram

    . = ALIGN(4);
    end = .;
}

PROVIDE(_stack = ORIGIN(ram) + LENGTH(ram));
