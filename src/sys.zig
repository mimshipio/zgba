const std = @import("std");

// TODO: - rename
//       - and move
const BIOS_IRQ_FLAGS = @as(*volatile u16, @ptrFromInt(0x03007FF8));

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
pub const InterruptFlags  = @as(*volatile IRQ, @ptrFromInt(0x04000202));

const WAITCNT = packed struct(u32) {
    sram_control:        u2,
    wait_state_0_first:  u2,
    wait_state_0_second: u1,
    wait_state_1_first:  u2,
    wait_state_1_second: u1,
    wait_state_2_first:  u2,
    wait_state_2_second: u1,
    phi_terminal_output: enum(u2) {
        disable,
        @"4.19mhz",
        @"8.38mhz",
        @"16.78mhz",
    },
    _padding0: u1,
    game_pak_prefetch: bool,
    game_pak_type: enum(u1) { gba = 0, gbc = 1, },
    _ : u16,
};
pub const WaitStateControl: *volatile WAITCNT = @ptrFromInt(0x04000204);

const IME = packed struct(u16) {
    enable:  bool = false,
    padding: u15 = 0,

    pub fn set(ime: *IME, enable: bool) void {
        ime.enable = enable;
    }
};
pub const InterruptMaster = @as(*volatile IME, @ptrFromInt(0x04000208));
