/* set the entry point of the program to symbol 'boot' */
ENTRY(boot)

/* SECTIONS command is used to map input sections to output sections and specify
 * how they are laid out in memory*/
SECTIONS {
    /* 
     * The `.` denotes the current output location counter.
     * Here we set this to value `0x80200000`
     * I'm not sure why but I think it has something to do with qemu riscv32.
     * maybe it jumps to that location at the start.
    */
    . = 0x80200000;
    __kernel_base = .;

    /*
     * This describes the output .text section.
     * .text.boot input section is placed at the beginning
     * KEEP is used to tell the linker when using link-time garbage collection that
     * it should not remove the .text.boot section under any circumstances.
     * after the .text.boot section we include .text and any section starting with .text from all the files
    */
    .text :{
        KEEP(*(.text.boot));
        *(.text .text.*);
    }

    /*
     * Similar to .text section, this is used to describe the .rodata section.
     * ALIGN(4) is used to set the location of .rodata section to be an address aligned to 4 bytes.
    */
    .rodata : ALIGN(4) {
        *(.rodata .rodata.*);
    }

    .data : ALIGN(4) {
        *(.data .data.*);
    }

    .bss : ALIGN(4) {
        /*
         * this assigns the current address location to __bss symbol 
         * which can be referenced in c code as `extern char symbol_name`
        */
        __bss = .;
        *(.bss .bss.* .sbss .sbss.*);
        __bss_end = .;
    }

    /*
     * what ALIGN function does is it returns the location counter aligned to the next n boundary
     * n being specified by the argument (here 4)
     * n must be an expression whose value is a power of 2
    */
    . = ALIGN(4);
    /*
     * Allocate 128KB of stack
    */
    . += 128 * 1024;
    __stack_top = .;

    /*
     * This defines a memory region that is later used by the allocator.
     * In a real operating system, this would be done by obtaining information 
     * from hardware at boot time 
    */
    . = ALIGN(4096);
    __free_ram = .;
    . += 64 * 1024 * 1024;
    __free_ram_end = .;
}

/* 
 * RESOURCES:
 * - https://home.cs.colorado.edu/~main/cs1300/doc/gnu/ld_3.html
 */
