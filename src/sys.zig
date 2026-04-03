const std = @import("std");

const display = @import("display.zig");

// TODO: - rename
//       - and move
const BIOS_IRQ_FLAGS = @as(*volatile u16, @ptrFromInt(0x03FFFFF8));

pub export fn dispatchIrq() linksection(".iwram.irq") void {
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
