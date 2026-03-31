const std = @import("std");

const gba = @import("gba");

const init = gba.init;
const display = gba.display;
const input = gba.input;
const sys = gba.sys;

export const header linksection(".gba_header") = init.Header{};

pub const Rgb = packed struct(u16) {
    r: u5 = 0,
    g: u5 = 0,
    b: u5 = 0,
    _: u1 = 0,
};

const Point = packed struct(u16) {
    x: u8 = 0,
    y: u8 = 0,
};

const Rect = packed struct(u32) {
    left:   u8 = 0,
    right:  u8 = 0,
    top:    u8 = 0,
    bottom: u8 = 0,
};

const Line = packed struct(u32) {
    x1: u8 = 0,
    x2: u8 = 0,
    y1: u8 = 0,
    y2: u8 = 0,
};

pub inline fn m3Plot(pos: Point, color: Rgb) void {
    sys.Vram[@as(u16, pos.y) * 240 + pos.x] = @bitCast(color);
}

pub fn m3Line(line: Line, color: Rgb) void {
    bmp16Line(line, color);
}

pub inline fn m3Rect(rect: Rect, color: Rgb) void {
    bmp16Rect(rect, color);
}

pub inline fn m3Frame(rect: Rect, color: Rgb) void {
    bmp16Frame(rect, color);

}

fn bmp16Line(line: Line, color: Rgb) void {
    const clr: u16 = @bitCast(color);
    const dst_pitch: isize = 240;

    var dx: isize = undefined;
    var dy: isize = undefined;
    var x_step: isize = undefined;
    var y_step: isize = undefined;

    if (line.x1 > line.x2) { x_step = -1;         dx = line.x1 - line.x2; }
    else                   { x_step =  1;         dx = line.x2 - line.x1; }
    if (line.y1 > line.y2) { y_step = -dst_pitch; dy = line.y1 - line.y2; }
    else                   { y_step =  dst_pitch; dy = line.y2 - line.y1; }

    var start: isize = @as(isize, line.y1) * dst_pitch + line.x1;

    if (dy == 0) {
        var i: isize = 0;
        while (i <= dx) : (i += 1) {
            sys.Vram[@intCast(start + i * x_step)] = clr;

        }
    } else if (dx == 0) {
        var i: isize = 0;
        while (i <= dy) : (i += 1) {
            sys.Vram[@intCast(start + i * y_step)] = clr;
        }
    } else if (dx >= dy) {
        var dd: isize = 2 * dy - dx;
        var i: isize = 0;
        while (i <= dx) : (i += 1) {
            sys.Vram[@intCast(start)] = clr;
            if (dd >= 0) { dd -= 2 * dx; start += y_step; }
            dd += 2 * dy;
            start += x_step;
        }
    } else {
        var dd: isize = 2 * dx - dy;
        var i: isize = 0;
        while (i <= dy) : (i += 1) {
            sys.Vram[@intCast(start)] = clr;
            if (dd >= 0) { dd -= 2 * dy; start += x_step; }
            dd += 2 * dx;
            start += y_step;
        }
    }
}

fn bmp16Rect(rect: Rect, color: Rgb) void {
    const clr: u16 = @bitCast(color);
    const dst_pitch: usize = 240;

    const width: u32 = rect.right - rect.left;
    const height: u32 = rect.bottom - rect.top;

    const start: usize = rect.top * dst_pitch + rect.left;

    // --- Draw ---
    for (0..height) |iy| {
        for (0..width) |ix| {
            sys.Vram[@intCast(start + iy * dst_pitch + ix)] = clr;
        }
    }

}

fn bmp16Frame(rect: Rect, color: Rgb) void {
    // Frame is RB exclusive
    const new_rect: Rect = .{
        .right  = rect.right-1,
        .bottom = rect.bottom-1,
    };

    bmp16Line(.{ .x1 = new_rect.left,  .x2 = new_rect.right, .y1 = new_rect.top,    .y2 = new_rect.top }, color);
    bmp16Line(.{ .x1 = new_rect.left,  .x2 = new_rect.right, .y1 = new_rect.bottom, .y2 = new_rect.bottom }, color);

    bmp16Line(.{ .x1 = new_rect.left,  .x2 = new_rect.left,  .y1 = new_rect.top,    .y2 = new_rect.bottom }, color);
    bmp16Line(.{ .x1 = new_rect.right, .x2 = new_rect.right, .y1 = new_rect.top,    .y2 = new_rect.bottom }, color);
}

// pub export fn main() callconv(.{ .arm_aapcs = .{} }) noreturn {
//     display.DisplayControl.* = .{ .mode = 4, .bg2 = true };
//
//     const IRQ_HANDLER: *volatile usize = @as(*volatile usize, @ptrFromInt(0x03007FFC));
//     IRQ_HANDLER.* = @intFromPtr(&sys.isr);
//
//     display.DisplayStat.*.vblank_irq = true;
//
//     sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
//     input.KeyControl.* = .{ .irq = true, .irq_type = 1 };
//     sys.InterruptMaster.*.enable = true;
//
//     // Background Palette RAM starts at 0x05000000
//     // const pal_bg_mem: [*]volatile u16 = @ptrFromInt(0x05000000);
//
//     var frame: u8 = 0;
//
//     while (true) {
//         sys.bios.vblankIntrWait();
//
//         if ((frame & 7) == 0) {
//             input.poll();
//
//             m3Plot(.{ .x = frame, .y = 80 }, .{ .r = 31, .g = 0, .b = 0 });
//         }
//         frame += 1;
//
//     }
// }

pub fn cpuFastSet(src: anytype, dest: anytype, control: u32) void {
    asm volatile ("swi 0x0C0000"
        :
        : [src]     "{r0}" (src),
          [dest]    "{r1}" (dest),
          [control] "{r2}" (control),
        : .{ .r3 = true } // SWI 0x0C clobbers r3
    );
}
