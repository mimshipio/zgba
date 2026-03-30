/*
 * gba.ld — GBA linker script for Zig (thumb-freestanding-eabi, arm7tdmi)
 *
 * Memory layout:
 *   ROM    0x08000000  32 MB   16-bit bus  cartridge code + data
 *   IWRAM  0x03007F00  32 KB   32-bit bus  fast RAM: stack, hot code, .data
 *   EWRAM  0x02000000 256 KB   16-bit bus  heap, large buffers, thumb code
 *
 * The first 0xC0 (192) bytes of ROM are the GBA header.  Your _start ARM
 * trampoline lives immediately after it.  The boot ROM jumps to 0x08000000,
 * which must be a valid 32-bit ARM B instruction pointing at _start.
 */

OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

/* ── Memory regions ──────────────────────────────────────────────────────── */

MEMORY {
    /*                  origin      length */
    ROM    (rx)  : ORIGIN = 0x08000000, LENGTH = 32M
    IWRAM  (rwx) : ORIGIN = 0x03000000, LENGTH = 32K
    EWRAM  (rwx) : ORIGIN = 0x02000000, LENGTH = 256K
}

/* ── Symbols used by startup code ───────────────────────────────────────── */
/*
 * _stack_top   — initial SP; set to the very top of IWRAM.
 *                The boot ROM already points SP here, but set it explicitly.
 * __bss_start / __bss_end        — zeroed by _start.
 * __data_start / __data_end      — destination in IWRAM (VMA).
 * __data_load                    — source in ROM (LMA); copied by _start.
 */

_stack_top = 0x03007F00;

/* ── Sections ────────────────────────────────────────────────────────────── */

SECTIONS {

    /* ── ROM ──────────────────────────────────────────────────────────────── */

    /*
     * .gba_header  (0x08000000 – 0x080000BF, 192 bytes)
     *
     * The GBA boot ROM validates this region before handing off execution.
     * Your Zig source must export a section named ".gba_header" containing:
     *   [0x00] 4 bytes  ARM B instruction  →  _start
     *   [0x04] 156 bytes Nintendo logo bitmap  (exact copy required)
     *   [0xA0] 12 bytes Game title  (ASCII, uppercase, null-padded)
     *   [0xAC] 4 bytes  Game code
     *   [0xB0] 2 bytes  Maker code
     *   [0xB2] 1 byte   Fixed value 0x96
     *   [0xB3] 7 bytes  Unit/device/reserved  (all 0x00)
     *   [0xBC] 1 byte   Software version  0x00
     *   [0xBD] 1 byte   Complement check  (computed by gbafix or comptime)
     *   [0xBE] 2 bytes  Reserved  0x0000
     */
    .gba_header : {
        KEEP(*(.gba_header))
    } > ROM

    /*
     * .text.boot  — ARM-mode startup trampoline (_start).
     *
     * Must be ARM (not Thumb) because the CPU boots in ARM state.
     * Responsibilities:
     *   1. Set SP = _stack_top
     *   2. Zero .bss  (__bss_start .. __bss_end)
     *   3. Copy .data from ROM (__data_load) to IWRAM (__data_start .. __data_end)
     *   4. BX into Thumb main()
     */
	.text.boot : {
		KEEP(*(.gba_header_entry))   /* ← _start from global asm */
		KEEP(*(.text.boot))
		KEEP(*(.text._start))
	} > ROM

    /* General code and read-only data */
    .text : {
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > ROM

    /* ── IWRAM ────────────────────────────────────────────────────────────── */

    /*
     * .data — initialised globals/statics.
     *
     * LMA (load address) = end of .text in ROM  →  stored in the cartridge.
     * VMA (virtual address) = IWRAM              →  where the CPU accesses it.
     * _start copies the image from ROM to IWRAM at boot.
     */
	.data : {
		__data_start = .;
		*(.data*)
		. = ALIGN(4);
		__data_end = .;
	} > IWRAM AT > ROM          /* linker places LMA right after .text in ROM */

    /*
     * __data_load marks where the initialised-data image sits in ROM.
     * The startup routine reads from here and writes to __data_start in IWRAM.
     */
	__data_load = LOADADDR(.data);   /* safe to query now that section is defined */

    /*
     * .iwram — code/data explicitly placed in fast IWRAM.
     *
     * Tag a function with  export fn foo() callconv(.Thumb) void
     * and place it in section ".iwram" via  @setSection(".iwram")  or a
     * comptime linker trick.  Useful for ISR handlers and inner loops.
     */
    .iwram : AT(LOADADDR(.data) + SIZEOF(.data)) {
		__iwram_load = LOADADDR(.iwram);   /* ← this line is missing */
        __iwram_start = .;
        *(.iwram*)
        . = ALIGN(4);
        __iwram_end = .;
    } > IWRAM

    /*
     * .bss — uninitialised globals/statics.
     *
     * The image for .bss is NOT stored in ROM.  _start zeroes this region.
     */
    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > IWRAM

    /* ── EWRAM ────────────────────────────────────────────────────────────── */

    /*
     * .ewram — large buffers or Thumb code you deliberately place in EWRAM.
     *
     * EWRAM has a 16-bit bus — prefer Thumb (16-bit instructions) over ARM
     * (32-bit instructions) here to avoid bus-width penalties.
     * Tag with section ".ewram" the same way as .iwram above.
     */
    .ewram (NOLOAD) : {
        __ewram_start = .;
        *(.ewram*)
        . = ALIGN(4);
        __ewram_end = .;
    } > EWRAM

    /* ── Diagnostics ─────────────────────────────────────────────────────── */

    /*
     * Discard C++ exception tables, ARM unwind info, and other sections
     * that have no meaning in a freestanding binary.
     */
    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
        *(.eh_frame*)
        *(.note*)
        *(.comment*)
    }
}

/*
 * Sanity assertions — the linker will error if these are violated.
 *
 * Stack grows downward from _stack_top, so leave headroom.  Here we
 * require at least 4 KB of stack space below the .bss/.data/.iwram.
 */
ASSERT(__bss_end <= _stack_top - 0x1000,
    "IWRAM overflow: .bss/.data/.iwram leave less than 4 KB for the stack.")

ASSERT(SIZEOF(.gba_header) == 0xC0,
    "GBA header section must be exactly 192 bytes (0xC0).  Check your header struct.")
