pub const Header = extern struct {
    entry_point: u32 = 0xEA00002E, // ARM branch instruction            
    nintendo_logo: [156]u8 = [_]u8{0} ** 156, // Hardware-specific bitmap
    game_title: [12]u8 = "ZIG GAME    ".*,
    game_code: [4]u8 = "ZIG0".*,
    maker_code: [2]u8 = "00".*,
    fixed_value: u8 = 0x96,
    main_unit_code: u8 = 0x00,
    device_type: u8 = 0x00,
    reserved: [7]u8 = [_]u8{0} ** 7,
    software_version: u8 = 0x00,
    complement_check: u8 = 0x00,
    checksum: u16 = 0x00,
};

// Symbols exported by the linker script
pub extern var __bss_start: u32;
pub extern var __bss_end: u32;
pub extern var __data_start: u32;
pub extern var __data_end: u32;
pub extern var __data_load: u32;
pub extern var __iwram_start: u32;
pub extern var __iwram_end: u32;
pub extern var __iwram_load: u32;
pub extern var _stack_top: u32;

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

