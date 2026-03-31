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
    /*                      origin      length */
    ROM    (rx)  : ORIGIN = 0x08000000, LENGTH = 32M
    IWRAM  (rwx) : ORIGIN = 0x03000000, LENGTH = 32K
    EWRAM  (rwx) : ORIGIN = 0x02000000, LENGTH = 256K
}

/*
 * Stack layout (top of IWRAM, growing downward):
 *
 *   0x03007FFF  ← top of IWRAM
 *   0x03007FA0  ← __sp_irq   (IRQ stack, 0x60 bytes)
 *   0x03007F00  ← __sp_usr   (user/Thumb stack, 0xA0 bytes)
 *                  ↑ _stack_top — where _start sets SP before calling main
 *
 * The BIOS hardcodes 0x03007FA0 as the IRQ stack pointer on interrupt entry.
 * If you install your own IRQ handler in Zig, it will already find SP there.
 * You only need these symbols if your startup code re-initialises the stacks
 * or if you want to assert they haven't been trampled.
 *
 * These are pure symbol definitions — they consume no ROM space.
 */
_stack_top  = 0x03007F00;   /* user/main stack — _start sets SP here */
__sp_usr    = 0x03007F00;   /* alias — matches devkitARM convention   */
__sp_irq    = 0x03007FA0;   /* IRQ stack — BIOS restores this on exit */

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

	/*
	 * .text.arm — explicitly ARM-mode (32-bit) functions in ROM.
	 *
	 * Use this for code that must run in ARM state outside of startup:
	 *   - Inner loops that need ARM's barrel-shifter addressing modes
	 *   - Veneer stubs that call into BIOS SWIs expecting ARM state
	 *
	 * In Zig, declare with:
	 *   export fn myArmFn() linksection(".text.arm") void { ... }
	 *
	 * The CPU stays in ARM state for the entire function. If it calls a Thumb
	 * function, the linker inserts a BX veneer automatically.
	 *
	 * NOTE: ARM instructions are 32-bit; on the GBA's 16-bit ROM bus each
	 * fetch takes two cycles instead of one. Prefer Thumb unless you have a
	 * specific reason. IWRAM (32-bit bus) does not have this penalty — put
	 * ARM hot code in .iwram instead.
	 */
	.text.arm : {
		__arm_code_start = .;
		*(.text.arm .text.arm.*)
		. = ALIGN(4);
		__arm_code_end = .;
	} > ROM

	/*
	 * .text — Thumb-mode code (default for all Zig functions).
	 *
	 * In Zig, callconv(.{ .arm_aapcs = .{} }) is the default for freestanding targets.
	 * and applies to both 32-bit ARM instructions and 16-bit Thumb instructions.
	 * You do not need to annotate normal functions — they land here.
	 * Only use linksection(".text.arm") when you deliberately need ARM state.
	 *
	 * __thumb_code_start marks the transition point. Your debugger or
	 * disassembler can use this to know where to decode 16-bit Thumb.
	 */
	.text : {
		__thumb_code_start = .;
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
	 * .iwram.irq — interrupt service routine(s).
	 *
	 * The GBA IRQ vector at 0x03007FFC is set to the address of your handler
	 * by writing it at runtime. The handler must be in fast memory.
	 *
	 * In Zig:
	 *   export fn irqHandler() linksection(".iwram.irq") void {
	 *       // ARM state — the BIOS calls IRQ handlers in ARM mode
	 *   }
	 */
	.iwram.irq : AT(LOADADDR(.data) + SIZEOF(.data)) {
		__irq_handler_load  = LOADADDR(.iwram.irq);
		__irq_handler_start = .;
		*(.iwram.irq .iwram.irq.*)
		. = ALIGN(4);
		__irq_handler_end   = .;
	} > IWRAM

	/* Then your general .iwram follows, chaining LMAs: */
	.iwram : AT(LOADADDR(.iwram.irq) + SIZEOF(.iwram.irq)) {
		__iwram_load  = LOADADDR(.iwram);
		__iwram_start = .;
		*(.iwram*)
		. = ALIGN(4);
		__iwram_end   = .;
	} > IWRAM

	/*
	 * IWRAM overlays — mutually exclusive code banks.
	 *
	 * Only one bank occupies IWRAM at a time. Your Zig code DMAs a bank in
	 * before calling any function inside it, and DMAs another in when done.
	 *
	 * Zig usage pattern:
	 *
	 *   // In your overlay module:
	 *   export fn audioMix() linksection(".iwram_ov0") void { ... }
	 *
	 *   // In your runtime (startup.zig or audio.zig):
	 *   extern const __ov0_load:   u8;  // LMA: where the bank sits in ROM
	 *   extern const __ov0_start:  u8;  // VMA: where it runs in IWRAM
	 *   extern const __ov0_end:    u8;  // VMA: end
	 *
	 *   fn loadOverlay0() void {
	 *       const src = @intFromPtr(&__ov0_load);
	 *       const dst = @intFromPtr(&__ov0_start);
	 *       const len = @intFromPtr(&__ov0_end) - dst;
	 *       @memcpy(@as([*]u8, @ptrFromInt(dst))[0..len],
	 *               @as([*]const u8, @ptrFromInt(src))[0..len]);
	 *   }
	 *
	 * All banks share the same VMA range — they are NOCROSSREFS so the linker
	 * errors if code in one bank calls code in another without a DMA in between.
	 *
	 * __overlay_base is placed after .iwram so banks don't overlap live IWRAM code.
	 */

	/*
	 * IWRAM overlay banks — LLD-compatible manual layout.
	 *
	 * GNU ld's OVERLAY directive is not supported by ld.lld (the linker Zig uses).
	 * We replicate it manually.
	 *
	 * What OVERLAY did automatically that we now do explicitly:
	 *   VMA: every bank starts at __overlay_base (they share the same address range
	 *        in IWRAM — only one bank is resident at a time).
	 *   LMA: banks are stored sequentially in ROM, each AT() chaining off the
	 *        previous bank's LOADADDR + SIZEOF.
	 *
	 * The `. = __overlay_base;` lines reset the VMA location counter back to the
	 * shared base before each bank.  Without them the counter would advance past
	 * the first bank and each subsequent bank would get a higher VMA, defeating
	 * the whole point.
	 */

	__overlay_base = __iwram_end;

	. = __overlay_base;
	.iwram_ov0 : AT(LOADADDR(.iwram) + SIZEOF(.iwram)) {
		__ov0_start = .;
		*(.iwram_ov0*)
		. = ALIGN(4);
		__ov0_end = .;
	} > IWRAM
	__ov0_load = LOADADDR(.iwram_ov0);

	. = __overlay_base;
	.iwram_ov1 : AT(LOADADDR(.iwram_ov0) + SIZEOF(.iwram_ov0)) {
		__ov1_start = .;
		*(.iwram_ov1*)
		. = ALIGN(4);
		__ov1_end = .;
	} > IWRAM
	__ov1_load = LOADADDR(.iwram_ov1);

	. = __overlay_base;
	.iwram_ov2 : AT(LOADADDR(.iwram_ov1) + SIZEOF(.iwram_ov1)) {
		__ov2_start = .;
		*(.iwram_ov2*)
		. = ALIGN(4);
		__ov2_end = .;
	} > IWRAM
	__ov2_load = LOADADDR(.iwram_ov2);

	. = __overlay_base;
	.iwram_ov3 : AT(LOADADDR(.iwram_ov2) + SIZEOF(.iwram_ov2)) {
		__ov3_start = .;
		*(.iwram_ov3*)
		. = ALIGN(4);
		__ov3_end = .;
	} > IWRAM
	__ov3_load = LOADADDR(.iwram_ov3);

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
	 * .ewram_data — initialised globals placed in EWRAM.
	 *
	 * Like .data, this has a ROM image (LMA) that your startup code copies
	 * to EWRAM at boot. Use for large lookup tables or buffers that need
	 * a known starting state.
	 *
	 * In Zig:
	 *   var bigTable: [1024]u16 linksection(".ewram_data") = init_values;
	 *
	 * 16-bit EWRAM bus penalty: reads are 3 cycles for 16-bit, 6 for 32-bit.
	 * Prefer Thumb code (16-bit instructions) when operating on this data.
	 * Avoid tight loops that do 32-bit word reads from EWRAM.
	 */
	.ewram_data : AT(__ewram_data_load_base) {
		__ewram_data_start = .;
		*(.ewram_data .ewram_data.*)
		. = ALIGN(4);
		__ewram_data_end   = .;
	} > EWRAM

	__ewram_data_load_base = /* LMA chain from end of overlay images */
	LOADADDR(.iwram_ov0) + SIZEOF(.iwram_ov0) +
	SIZEOF(.iwram_ov1)   + SIZEOF(.iwram_ov2) + SIZEOF(.iwram_ov3);
	__ewram_data_load = LOADADDR(.ewram_data);

	/*
	 * .ewram_bss — zero-initialised globals in EWRAM.
	 *
	 * No ROM image — startup code zeroes this region.
	 * Add to your _start zero loop alongside the IWRAM .bss region.
	 *
	 * In Zig:
	 *   var scratchBuffer: [65536]u8 linksection(".ewram_bss") = undefined;
	 *   // (Zig's undefined means "I will write before I read" —
	 *   //  startup zeroing makes this safe for C-style zero-init semantics.)
	 */
	.ewram_bss (NOLOAD) : {
		__ewram_bss_start = .;
		*(.ewram_bss .ewram_bss.*)
		. = ALIGN(4);
		__ewram_bss_end   = .;
	} > EWRAM

	/*
	 * .ewram — unmanaged EWRAM.
	 * Buffers and code you populate yourself. NOLOAD, no ROM image.
	 */
	.ewram (NOLOAD) : {
		__ewram_start = .;
		*(.ewram*)
		. = ALIGN(4);
		__ewram_end   = .;
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
 * require at least 512 B of stack space .bss and the user stack.
 */
ASSERT(__bss_end <= __sp_usr - 0x200,
    "IWRAM overflow: less than 512 B between .bss end and user stack.")

ASSERT(SIZEOF(.gba_header) == 0xC0,
    "GBA header section must be exactly 192 bytes (0xC0).  Check your header struct.")
