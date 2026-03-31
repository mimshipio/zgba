const std = @import("std");

const display = @import("display.zig");

const BIOS_IRQ_FLAGS = @as(*volatile u16, @ptrFromInt(0x03FFFFF8));
// ── IRQ dispatch ──────────────────────────────────────────────────────────
//
// ARM/Thumb boundary explained:
//
//   Your Zig target triple (thumb-freestanding-eabi) makes the compiler emit
//   16-bit Thumb instructions for all Zig functions by default.  The BIOS,
//   however, always calls your IRQ handler in ARM state — it has no way to
//   know the handler is Thumb.
//
//   The solution is a two-layer design:
//     1. irqHandler  — ARM-mode asm stub in .iwram.irq.  This is what the
//                      BIOS calls.  It bridges to Thumb using the
//                      mov-lr-pc / bx idiom (see below).
//     2. dispatchIrq — Normal Zig function, Thumb-mode.  Contains your
//                      actual interrupt logic.
//
//   Why not just write the whole handler in ARM asm?
//   Because then you lose Zig's type system, safety checks, and the ability
//   to call your own Zig code without another trampoline at every callsite.
//   One trampoline at the entry point is the right trade-off.
//
// dispatchIrq:
//   Declared `export` so the assembly trampoline can reference it by name.
//   The `arm_aapcs` calling convention is correct here: it is the standard
//   call/return ABI for both ARM and Thumb on this target, and it means
//   the function returns by executing `bx lr`, which the trampoline relies on.
//
//   Fill in the body with your interrupt dispatch logic:
//     - Read 0x04000200 (IE) and 0x04000202 (IF) to find which interrupt fired
//     - Write the same bits back to IF to acknowledge it
//     - Also clear the BIOS's own IF mirror at 0x03FFFFF8
pub export fn dispatchIrq() callconv(.{ .arm_aapcs = .{} }) void {
    const fired: u16 = @as(u16, @bitCast(InterruptEnable.*)) & @as(u16, @bitCast(InterruptFlags.*));
    InterruptFlags.* = @bitCast(fired); // ack hardware
    BIOS_IRQ_FLAGS.* |= fired;          // ack BIOS
}

const IRQ = packed struct(u16) {
    vblank_irq:     bool = false,
    hblank_irq:     bool = false,
    vcount_irq:     bool = false,
    timer0_irq:     bool = false,
    timer1_irq:     bool = false,
    timer2_irq:     bool = false,
    timer3_irq:     bool = false,
    serial_com_irq: bool = false,
    dma0_irq:       bool = false,
    dma1_irq:       bool = false,
    dma2_irq:       bool = false,
    dma3_irq:       bool = false,
    key_irq:        bool = false,
    cart_irq:       bool = false,
    padding:        u2 = 0,
};
pub const InterruptEnable = @as(*volatile IRQ, @ptrFromInt(0x04000200));
pub const InterruptFlags = @as(*volatile IRQ, @ptrFromInt(0x04000202));

const IME = packed struct(u32) {
    enable:  bool = false,
    padding: u31 = 0,
};
pub const InterruptMaster = @as(*volatile IME, @ptrFromInt(0x04000208));

pub const Vram: [*]volatile u16 = @ptrFromInt(0x06000000);

pub fn call(comptime number: u8) void {
    asm volatile (std.fmt.comptimePrint("swi 0x{X}", .{number})
        :::.{ .r0 = true, .r1 = true, .r2 = true, .r3 = true }
    );
}

pub const bios = struct {
    pub inline fn softReset() void {
        call(0x00);
    }
    pub inline fn halt() void {
        call(0x02);
    }
    pub inline fn vblankIntrWait() void {
        call(0x05);
    }
    pub inline fn div(numerator: i32, denominator: i32) struct { quot: i32, rem: i32 } {
        var q: i32 = numerator;
        var r: i32 = denominator;
        asm volatile ("swi #0x06"
            : [q] "={r0}" (q),
              [r] "={r1}" (r),
            : [n] "{r0}" (q),
              [d] "{r1}" (r),
            : .{ .r3 = true }
        );
        return .{ .quot = q, .rem = r };
    }
    pub inline fn fastMemCpy(src: anytype, dest: anytype, control: u32) void {
    asm volatile ("swi 0x0C"
        :
        : [src]     "{r0}" (src),
          [dest]    "{r1}" (dest),
          [control] "{r2}" (control),
        : .{ .r3 = true } // SWI 0x0C clobbers r3
    );
    }
};
