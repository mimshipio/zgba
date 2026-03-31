// init.zig — GBA startup and memory initialisation
//
// This file owns:
//   - The GBA header struct (space reservation; filled by external build step)
//   - All linker-script symbol declarations
//   - The ARM-mode _start entry point
//   - The ARM-mode irqHandler trampoline
//   - The Thumb-mode dispatchIrq stub (fill in with your IRQ logic)
//   - EWRAM section declarations
//   - Overlay load helpers
//
// What this file deliberately does NOT contain:
//   - main() — defined in your application file
//   - Any game logic

// ── GBA header ────────────────────────────────────────────────────────────
// Space reservation only.  The external build step (gbafix or equivalent)
// overwrites this region with the correct Nintendo logo bitmap, complement
// check, and other validated fields before the ROM is run.
pub const Header = extern struct {
    entry_point:      u32      = 0xEA00002E,       // ARM B _start instruction
    nintendo_logo:    [156]u8  = [_]u8{0} ** 156,
    game_title:       [12]u8   = "ZIG GAME    ".*,
    game_code:        [4]u8    = "ZIG0".*,
    maker_code:       [2]u8    = "00".*,
    fixed_value:      u8       = 0x96,
    main_unit_code:   u8       = 0x00,
    device_type:      u8       = 0x00,
    reserved:         [7]u8    = [_]u8{0} ** 7,
    software_version: u8       = 0x00,
    complement_check: u8       = 0x00,
    checksum:         u16      = 0x00,
};

// ── Linker-script address symbols ─────────────────────────────────────────
//
// The linker script exports symbols that mark the boundaries of each section.
// A symbol like __bss_start is not a variable — it IS an address.  The linker
// places a label at that location; taking &__bss_start gives you that address.
//
// Correct Zig pattern:
//   extern const __foo: u8;           // declare as extern const u8
//   const addr = @intFromPtr(&__foo); // take the address of the symbol
//
// Why u8 and not u32?
//   The type is irrelevant — we never read the value at the symbol, only its
//   address.  u8 is conventional because it makes the pointer arithmetic
//   natural: @as([*]u8, @ptrFromInt(...)) needs no scaling.
//
// Why const and not var?
//   These are not writable memory locations.  Declaring them var would let
//   Zig believe you can assign through them, which would corrupt code or
//   metadata.
//
// Sections that live in IWRAM or EWRAM at runtime but are stored in ROM have
// three symbols each:
//   __X_load   — LMA: where the ROM image begins
//   __X_start  — VMA: where the CPU will access the data at runtime
//   __X_end    — VMA: end of the runtime region; (end - start) == copy length
//
// ROM-resident sections (.text.arm, .text) execute in place and have no _load
// symbol — there is nothing to copy.

// .bss — zero-initialised statics in IWRAM (no ROM image; zeroed by _start)
extern const __bss_start: u8;
extern const __bss_end:   u8;

// .data — initialised globals in IWRAM
extern const __data_start: u8;
extern const __data_end:   u8;
extern const __data_load:  u8;   // LMA: ROM image copied to __data_start at boot

// .iwram.irq — the ARM-mode IRQ trampoline, running from IWRAM
extern const __irq_handler_start: u8;
extern const __irq_handler_end:   u8;
extern const __irq_handler_load:  u8;   // LMA: ROM image; must be copied before
                                        //      step 8 installs the vector

// .iwram — general fast code/data in IWRAM
extern const __iwram_start: u8;
extern const __iwram_end:   u8;
extern const __iwram_load:  u8;   // LMA: ROM image

// .text.arm — ARM-mode code in ROM; executes in place, no copy needed.
// These are exposed mainly as a diagnostic / disassembler hint: everything
// between __arm_code_start and __arm_code_end is 32-bit ARM instructions.
extern const __arm_code_start: u8;
extern const __arm_code_end:   u8;

// .text — Thumb code and .rodata in ROM; executes in place, no copy needed.
extern const __thumb_code_start: u8;
extern const __thumb_code_end:   u8;

// .ewram_data — initialised globals in EWRAM
extern const __ewram_data_start: u8;
extern const __ewram_data_end:   u8;
extern const __ewram_data_load:  u8;   // LMA: ROM image

// .ewram_bss — zero-initialised buffers in EWRAM (no ROM image; zeroed by _start)
extern const __ewram_bss_start: u8;
extern const __ewram_bss_end:   u8;

// IWRAM overlay bank 0 — loaded on demand, not at startup
extern const __ov0_start:    u8;
extern const __ov0_end:      u8;
extern const __ov0_load:     u8;   // LMA: ROM image

// Stack layout — pure address values, no backing storage.
//
// The BIOS assumes the top of IWRAM (0x03007FFF downward) is split:
//   0x03007FFF – 0x03007FA0  →  IRQ stack (0x60 bytes, __sp_irq base)
//   0x03007F9F – 0x03007F00  →  user/SYS stack (0xA0 bytes, __sp_usr base)
//
// _start sets SP = _stack_top = __sp_usr.  When an interrupt fires, the BIOS
// switches to IRQ mode and uses __sp_irq automatically — you do not manage
// the IRQ stack yourself.
extern const _stack_top: u8;      // = __sp_usr; _start sets SP here
extern const __sp_usr:   u8;
extern const __sp_irq:   u8;

// ── Convenience address constants ─────────────────────────────────────────
// Pre-computed at comptime.  Import this module and use e.g. init.IwramLoad
// instead of repeating @intFromPtr(&__iwram_load) throughout your codebase.
pub const BssStart        = @intFromPtr(&__bss_start);
pub const BssEnd          = @intFromPtr(&__bss_end);
pub const DataStart       = @intFromPtr(&__data_start);
pub const DataEnd         = @intFromPtr(&__data_end);
pub const DataLoad        = @intFromPtr(&__data_load);
pub const IrqHandlerStart = @intFromPtr(&__irq_handler_start);
pub const IrqHandlerEnd   = @intFromPtr(&__irq_handler_end);
pub const IrqHandlerLoad  = @intFromPtr(&__irq_handler_load);
pub const IwramStart      = @intFromPtr(&__iwram_start);
pub const IwramEnd        = @intFromPtr(&__iwram_end);
pub const IwramLoad       = @intFromPtr(&__iwram_load);
pub const ArmCodeStart    = @intFromPtr(&__arm_code_start);
pub const ArmCodeEnd      = @intFromPtr(&__arm_code_end);
pub const ThumbCodeStart  = @intFromPtr(&__thumb_code_start);
pub const ThumbCodeEnd    = @intFromPtr(&__thumb_code_end);
pub const EwramDataStart  = @intFromPtr(&__ewram_data_start);
pub const EwramDataEnd    = @intFromPtr(&__ewram_data_end);
pub const EwramDataLoad   = @intFromPtr(&__ewram_data_load);
pub const EwramBssStart   = @intFromPtr(&__ewram_bss_start);
pub const EwramBssEnd     = @intFromPtr(&__ewram_bss_end);
pub const Ov0Start        = @intFromPtr(&__ov0_start);
pub const Ov0End          = @intFromPtr(&__ov0_end);
pub const Ov0Load         = @intFromPtr(&__ov0_load);
pub const StackTop        = @intFromPtr(&_stack_top);
pub const SpUsr           = @intFromPtr(&__sp_usr);
pub const SpIrq           = @intFromPtr(&__sp_irq);

// ── EWRAM sections ────────────────────────────────────────────────────────
// Globals placed here are accessible from anywhere but pay the 16-bit bus
// penalty: a 32-bit word read from EWRAM costs 6 cycles; the same read from
// IWRAM costs 1.  Prefer byte/halfword access patterns for EWRAM data.
//
// .ewram_bss: zeroed by _start, no ROM image.
// .ewram_data: has a ROM image; _start copies it to EWRAM at boot.
//              Uncomment bigTable (or add your own) once you have an initialiser.

pub var scratchBuffer: [65536]u8 linksection(".ewram_bss") = undefined;
pub var bigTable: [1024]u16 linksection(".ewram_data") = [_]u16{0} ** 1024;

comptime {
    // ── _start ────────────────────────────────────────────────────────────
    //
    // Placed in .gba_header_entry, which the linker puts immediately after
    // the 192-byte GBA header.  The header's entry_point field (0xEA00002E)
    // is a pre-encoded ARM `B _start` that jumps here.  The BIOS boots in
    // ARM state, so this block must stay ARM throughout.
    //
    // Startup sequence — keep this comment in sync with the linker script:
    //   1. Set SP to the top of the user stack region in IWRAM
    //   2. Zero IWRAM .bss        (__bss_start  .. __bss_end)
    //   3. Copy .data      ROM→IWRAM (__data_load       → __data_start..__data_end)
    //   4. Copy .iwram.irq ROM→IWRAM (__irq_handler_load → __irq_handler_start..__irq_handler_end)
    //   5. Copy .iwram     ROM→IWRAM (__iwram_load       → __iwram_start..__iwram_end)
    //   6. Copy .ewram_data ROM→EWRAM (__ewram_data_load  → __ewram_data_start..__ewram_data_end)
    //   7. Zero EWRAM .ewram_bss  (__ewram_bss_start .. __ewram_bss_end)
    //   8. Install IRQ handler pointer at 0x03007FFC
    //   9. BX to main()
    //
    // Steps where the section might be empty (e.g. no .iwram code yet) are
    // safe to run unconditionally: the copy loop compares start == end on the
    // first iteration and exits immediately without touching memory.
    //
    // Overlay banks (.iwram_ov0 etc.) are NOT copied here.  Call loadOverlayN()
    // before executing code in that bank.
    //
    // Note on `ldr rN, =symbol` (literal pool loads):
    //   GAS turns these into PC-relative word loads from a literal pool it
    //   appends after the function.  The pool entry must be within ±4 KB of
    //   the load instruction in ARM mode.  _start is compact enough that this
    //   is not a concern, but if you add many more literal loads you may need
    //   a `.ltorg` directive to force an early pool dump.
    asm (
        \\.section .gba_header_entry, "ax", %progbits
        \\.arm
        \\.global _start
        \\.type _start, %function
        \\_start:
        \\
        \\ @ ── 1: stack ──────────────────────────────────────────────────
        \\ @ _stack_top = 0x03007F00 (linker script symbol).
        \\ @ The BIOS may already point SP here, but we set it explicitly so
        \\ @ startup is self-contained and predictable.
        \\ ldr sp, =_stack_top
        \\
        \\ @ ── 2: zero IWRAM .bss ─────────────────────────────────────────
        \\ ldr r0, =__bss_start
        \\ ldr r1, =__bss_end
        \\ mov r2, #0
        \\.bss_loop:
        \\  cmp   r0, r1
        \\  strlt r2, [r0], #4
        \\  blt   .bss_loop
        \\
        \\ @ ── 3: copy .data ROM → IWRAM ──────────────────────────────────
        \\ @ r0 = LMA source (__data_load, in ROM)
        \\ @ r1 = VMA dest   (__data_start, in IWRAM)
        \\ @ r2 = VMA end    (__data_end,   in IWRAM)
        \\ ldr r0, =__data_load
        \\ ldr r1, =__data_start
        \\ ldr r2, =__data_end
        \\.data_loop:
        \\  cmp    r1, r2
        \\  ldrlt  r3, [r0], #4
        \\  strlt  r3, [r1], #4
        \\  blt    .data_loop
        \\
        \\ @ ── 4: copy .iwram.irq ROM → IWRAM ─────────────────────────────
        \\ @ This copies the irqHandler trampoline into IWRAM.
        \\ @ Must happen before step 8 writes irqHandler's address to 0x03007FFC,
        \\ @ otherwise an early interrupt would jump to stale or absent code.
        \\ ldr r0, =__irq_handler_load
        \\ ldr r1, =__irq_handler_start
        \\ ldr r2, =__irq_handler_end
        \\.irq_copy_loop:
        \\  cmp    r1, r2
        \\  ldrlt  r3, [r0], #4
        \\  strlt  r3, [r1], #4
        \\  blt    .irq_copy_loop
        \\
        \\ @ ── 5: copy .iwram ROM → IWRAM ─────────────────────────────────
        \\ ldr r0, =__iwram_load
        \\ ldr r1, =__iwram_start
        \\ ldr r2, =__iwram_end
        \\.iwram_loop:
        \\  cmp    r1, r2
        \\  ldrlt  r3, [r0], #4
        \\  strlt  r3, [r1], #4
        \\  blt    .iwram_loop
        \\
        \\ @ ── 6: copy .ewram_data ROM → EWRAM ────────────────────────────
        \\ @ EWRAM has a 16-bit bus (32-bit reads cost 6 cycles vs 1 in IWRAM).
        \\ @ We still copy 32 bits at a time here because startup cost is paid
        \\ @ once.  It is runtime access patterns that suffer from the bus width.
        \\ ldr r0, =__ewram_data_load
        \\ ldr r1, =__ewram_data_start
        \\ ldr r2, =__ewram_data_end
        \\.ewram_data_loop:
        \\  cmp    r1, r2
        \\  ldrlt  r3, [r0], #4
        \\  strlt  r3, [r1], #4
        \\  blt    .ewram_data_loop
        \\
        \\ @ ── 7: zero EWRAM .ewram_bss ────────────────────────────────────
        \\ @ scratchBuffer (and any other .ewram_bss globals) live here.
        \\ @ The linker marks this section NOLOAD so there is no ROM image;
        \\ @ we zero it explicitly.
        \\ ldr r0, =__ewram_bss_start
        \\ ldr r1, =__ewram_bss_end
        \\ mov r2, #0
        \\.ewram_bss_loop:
        \\  cmp   r0, r1
        \\  strlt r2, [r0], #4
        \\  blt   .ewram_bss_loop
        \\
        \\ @ ── 8: install IRQ handler ──────────────────────────────────────
        \\ @ The BIOS reads 0x03007FFC and calls that address when any
        \\ @ interrupt fires.  We write the VMA of irqHandler, which now lives
        \\ @ in IWRAM after step 4.
        \\ @
        \\ @ irqHandler is ARM-mode code so its address has LSB=0.  The BIOS
        \\ @ calls it in ARM state — correct.  Do not point this at dispatchIrq
        \\ @ directly; that is Thumb (LSB=1) and the BIOS does not handle the
        \\ @ state switch.
        \\ ldr r0, =irqHandler
        \\ ldr r1, =0x03007FFC
        \\ str r0, [r1]
        \\
        \\ @ ── 9: branch to main ───────────────────────────────────────────
        \\ @ main() is compiled as Thumb.  The linker sets LSB=1 on all Thumb
        \\ @ function addresses.  BX reads that bit and switches the CPU from
        \\ @ ARM to Thumb state before executing the first instruction of main.
        \\ @ This is the one and only intentional ARM→Thumb transition in the
        \\ @ normal execution path.
        \\ ldr r0, =main
        \\ bx  r0
    );

    // ── irqHandler trampoline ──────────────────────────────────────────────
    //
    // Lives in .iwram.irq so it is always resident in fast RAM when an
    // interrupt fires.  Must be ARM-mode because the BIOS calls it in ARM
    // state with no prior state switch.
    //
    // How the BIOS calls us:
    //   The BIOS IRQ wrapper runs in IRQ mode, saves registers, then switches
    //   to System mode and does roughly:
    //     ldr r0, [0x03007FFC]   @ load our handler address
    //     mov lr, pc             @ lr = address of instruction after bx
    //     bx  r0                 @ call our handler (ARM or Thumb per LSB)
    //   On return from our handler it restores registers and does SUBS PC, LR, #4.
    //
    // The ARM→Thumb call problem:
    //   The GBA's CPU is an ARM7TDMI, which implements ARMv4T.  BLX (branch
    //   with link and exchange) was only introduced in ARMv5T.  On ARMv4T the
    //   only instruction that switches CPU state is BX, which does NOT set LR.
    //   To call a Thumb function from ARM and get a return address, the idiom is:
    //
    //     mov lr, pc    @ lr = (address of this instruction) + 8
    //     bx  rN        @ jump to Thumb; returns here via BX lr
    //
    //   Why +8?  The ARM7TDMI has a 3-stage pipeline.  While an instruction
    //   executes, the PC register already points 8 bytes ahead (two instructions
    //   forward).  So `mov lr, pc` stores (address of mov) + 8, which is the
    //   address of the instruction after the following bx — exactly where we
    //   want dispatchIrq to return.
    //
    //   Concretely, if `mov lr, pc` is at address A:
    //     A+0: mov lr, pc      → lr = A + 8
    //     A+4: bx  r0          → jumps to dispatchIrq (Thumb)
    //     A+8: pop {r0}        ← dispatchIrq returns here (via BX lr in Thumb)
    //     A+12: bx r0          → return to BIOS (ARM, LSB=0 in BIOS lr)
    //
    // Why not POP {PC} to return to the BIOS?
    //   On ARMv4T, POP {PC} does NOT perform interworking — it loads the value
    //   into PC without reading the LSB to select ARM/Thumb state.  Only BX
    //   does that.  Since we are in ARM mode and the BIOS return address is
    //   also ARM (LSB=0), BX is still the correct instruction.
    asm (
        \\.section .iwram.irq, "ax", %progbits
        \\.arm
        \\.global irqHandler
        \\.type irqHandler, %function
        \\irqHandler:
        \\
        \\ @ Save the BIOS return address.  We will BX to it at the end.
        \\ @ On entry, lr = address the BIOS wants us to return to (ARM, LSB=0).
        \\ push {lr}
        \\
        \\ @ Load dispatchIrq's address into r0.
        \\ @ The linker sets LSB=1 on all Thumb symbols, so BX will switch state.
        \\ ldr r0, =dispatchIrq
        \\
        \\ @ ARM pipeline trick: set lr = address of the instruction after bx.
        \\ @ See the comment above for why this is (address of this mov) + 8.
        \\ mov lr, pc
        \\ bx  r0              @ call dispatchIrq in Thumb mode
        \\                     @ dispatchIrq returns here via BX lr
        \\
        \\ @ Restore the BIOS return address and return to it.
        \\ @ We pop into r0 (a scratch register) rather than PC because
        \\ @ POP {PC} does not do interworking on ARMv4T.
        \\ pop  {r0}
        \\ bx   r0             @ return to BIOS in ARM mode (LSB=0)
    );
}

// ── Overlay loading ────────────────────────────────────────────────────────
//
// IWRAM overlay banks are mutually exclusive code regions stored in ROM and
// loaded on demand.  They all share the same VMA range (the IWRAM region
// starting at __overlay_base).  The linker script's NOCROSSREFS directive
// makes inter-bank calls a link-time error rather than a silent runtime crash
// when the wrong bank is loaded.
//
// Usage:
//   loadOverlay0();           // DMA bank 0 into IWRAM
//   myFunctionInOverlay0();   // safe to call now
//   loadOverlay1();           // bank 0 is silently overwritten
//
// Do not call a function in a bank after loading a different bank.
// Do not call loadOverlayN() while executing code inside that bank.
pub fn loadOverlay0() void {
    const src = Ov0Load;
    const dst = Ov0Start;
    const len = Ov0End - dst;
    @memcpy(
        @as([*]u8, @ptrFromInt(dst))[0..len],
        @as([*]const u8, @ptrFromInt(src))[0..len],
    );
}
// Add loadOverlay1(), loadOverlay2(), etc. as you define more overlay banks
// in the linker script.
