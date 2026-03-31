const std = @import("std");

const display = @import("display.zig");

pub const BIOS_IRQ_FLAGS = @as(*volatile u16, @ptrFromInt(0x03FFFFF8));

pub export fn isr() callconv(.{ .arm_aapcs = .{} }) void {
    const triggered = @as(u16, @bitCast(InterruptEnable.*)) & @as(u16, @bitCast(InterruptFlags.*));
    BIOS_IRQ_FLAGS.* |= @bitCast(triggered);    // tell BIOS
    InterruptFlags.* = @bitCast(triggered); // acknowledge hardware
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

pub inline fn call(comptime number: u8) void {
    std.fmt.comptimePrint("0x{X}", .{number});
    asm volatile (std.fmt.comptimePrint("swi 0x{X}0000", .{number})
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
        // call(0x05);
        asm volatile ("swi 0x050000" ::: .{ .r0 = true, .r1 = true, .r2 = true, .r3 = true} );
    }
    // pub inline fn div(numerator: i32, denominator: i32) struct { quot: i32, rem: i32 } {
    //     var q: i32 = numerator;
    //     var r: i32 = denominator;
    //     asm volatile ("swi #0x06"
    //         : [q] "={r0}" (q),
    //           [r] "={r1}" (r),
    //         : [n] "{r0}" (q),
    //           [d] "{r1}" (r),
    //         : .{ .r3 = true }
    //     );
    //     return .{ .quot = q, .rem = r };
    // }
};
