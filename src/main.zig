const sys = @import("sys.zig");

export const header linksection(".gba_header") = Header{
    .entry_point = 0xEA00002E, // Standard branch to start
    .game_title = "MYZIGGAME   ".*, 
    .game_code = "ZIG0".*,
    .maker_code = "00".*,
};

const Header = extern struct {
    entry_point: u32,             // ARM branch instruction            
    nintendo_logo: [156]u8 = undefined,       // Hardware-specific bitmap
    game_title: [12]u8,           // "GAME_TITLE" from your Makefile
    game_code: [4]u8,             // "GAME_CODE" from your Makefile
    maker_code: [2]u8,            // "MAKER_CODE" from your Makefile
    fixed_value: u8 = 0x96,
    main_unit_code: u8 = 0x00,
    device_type: u8 = 0x00,
    reserved: [7]u8 = [_]u8{0} ** 7,
    software_version: u8 = 0x00,
    complement_check: u8 = 0x00,
    checksum: u16 = 0x00,
};

// Symbols exported by the linker script
extern var __bss_start: u32;
extern var __bss_end: u32;
extern var __data_start: u32;
extern var __data_end: u32;
extern var __data_load: u32;
extern var __iwram_start: u32;
extern var __iwram_end: u32;
extern var __iwram_load: u32;
extern var _stack_top: u32;

comptime {
    asm (
        \\.section .gba_header_entry, "ax", %progbits
        \\.arm
        \\.global _start
        \\.type _start, %function
        \\_start:
        \\
        \\ @ Set stack pointer to top of IWRAM (0x03008000)
        \\ ldr sp, =_stack_top
        \\
        \\ @ Zero .bss section
        \\ ldr r0, =__bss_start
        \\ ldr r1, =__bss_end
        \\ mov r2, #0
        \\.bss_loop:
        \\  cmp r0, r1
        \\  strlt r2, [r0], #4
        \\  blt .bss_loop
        \\
        \\ @ Copy .data image from ROM to IWRAM
        \\ ldr r0, =__data_load
        \\ ldr r1, =__data_start
        \\ ldr r2, =__data_end
        \\.data_loop:
        \\  cmp r1, r2
        \\  ldrlt r3, [r0], #4
        \\  strlt r3, [r1], #4
        \\  blt .data_loop
        \\
        \\ @ Copy .iwram section image from ROM to IWRAM
        \\ ldr r0, =__iwram_load
        \\ ldr r1, =__iwram_start
        \\ ldr r2, =__iwram_end
        \\.iwram_loop:
        \\  cmp r1, r2
        \\  ldrlt r3, [r0], #4
        \\  strlt r3, [r1], #4
        \\  blt .iwram_loop
        \\
        \\ @ BX to main — LSB of address controls ARM/Thumb state.
        \\ @ The linker will set LSB=1 for Thumb functions automatically
        \\ @ when you branch via BX.
        \\ ldr r0, =main
        \\ bx r0
    );
}

const Rgb = packed struct(u16) {
    r: u5 = 0,
    g: u5 = 0,
    b: u5 = 0,
    _: u1 = 0,
};

const ScreenPosition = packed struct(u16) {
    x: u8 = 0,
    y: u8 = 0,
};

pub fn m3Plot(pos: ScreenPosition, color: Rgb) void {
    sys.Vram[@as(u16, pos.y) * 240 + pos.x] = @bitCast(color);
}

pub export fn main() callconv(.{ .arm_aapcs = .{} }) noreturn {
    sys.DisplayControl.* = .{ .mode = 3, .bg2 = true };

    const IRQ_HANDLER: *volatile usize = @as(*volatile usize, @ptrFromInt(0x03007FFC));
    IRQ_HANDLER.* = @intFromPtr(&sys.isr);

    sys.DisplayStat.*.vblank_irq = true;
    sys.InterruptEnable.*.vblank_irq = true;
    sys.InterruptMaster.*.enable = true;

     while (true) {
         m3Plot(.{ .x = 90, .y = 80 }, .{ .r = 31, .g = 0, .b = 0 });
         m3Plot(.{ .x = 80, .y = 90 }, .{ .r = 31, .g = 0, .b = 0 });
         m3Plot(.{ .x = 100, .y = 90 }, .{ .r = 31, .g = 0, .b = 0 });

         sys.bios.vblankIntrWait();
    }
}
