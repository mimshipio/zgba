const std = @import("std");

pub const BIOS_IRQ_FLAGS = @as(*volatile u16, @ptrFromInt(0x03FFFFF8));

pub export fn isr() callconv(.{ .arm_aapcs = .{} }) void {
    const triggered = @as(u16, @bitCast(InterruptEnable.*)) & @as(u16, @bitCast(InterruptFlags.*));
    BIOS_IRQ_FLAGS.* |= @bitCast(triggered);    // tell BIOS
    InterruptFlags.* = @bitCast(triggered); // acknowledge hardware
}


const DISPCNT = packed struct(u16) {
    mode:          u3  = 0,
    gbc_mode:      u1  = 0,
    page_select:   u1  = 0,
    hblank_oam:    u1  = 0,
    obj_id:        u1  = 0,
    force_blank:   u1  = 0,
    bg0:           bool = false,
    bg1:           bool = false,
    bg2:           bool = false,
    bg3:           bool = false,
    obj:           bool = false,
    win0:          bool = false,
    win1:          bool = false,
    win_obj:       bool = false,
};
pub const DisplayControl: *volatile DISPCNT = @as(*volatile DISPCNT, @ptrFromInt(0x04000000));

const DISPSTAT = packed struct(u16) {
    vblank_status:   u1 = 0,
    hblank_status:   u1 = 0,
    vcount:          u1 = 0,
    vblank_irq:      bool = false,
    hblank_irq:      bool = false,
    vcount_irq:      bool = false,
    padding:         u2 = 0,
    vcount_irq_line: u8 = 0,
};
pub const DisplayStat: *volatile DISPSTAT = @as(*volatile DISPSTAT, @ptrFromInt(0x04000004));

const VCOUNT = packed struct(u16) {
    vcount:    u8 = 0,
    read_only: u8 = 0,
};
pub const VCount: *volatile VCOUNT = @as(*volatile VCOUNT, @ptrFromInt(0x04000006));

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

const VRAM = [0x00009600]u16;
pub const Vram: *volatile VRAM = @as(*volatile VRAM, @ptrFromInt(0x06000000));

pub inline fn call(comptime number: u8) void {
    asm volatile ("swi #" ++ std.fmt.comptimePrint("0x{X}0000", .{number})
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
        asm volatile ("swi #0x060000"
            : [q] "={r0}" (q),
              [r] "={r1}" (r),
            : [n] "{r0}" (q),
              [d] "{r1}" (r),
            : .{ .r3 = true }
        );
        return .{ .quot = q, .rem = r };
    }
};
