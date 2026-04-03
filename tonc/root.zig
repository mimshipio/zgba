const std = @import("std");

const gba = @import("gba");
const arm = @import("tonc_arm");

const init = gba.init;
const display = gba.display;
const input = gba.input;
const sys = gba.sys;

const dst_pitch: isize = 240;
const i_dst_pitch: usize = 240;

pub const Rgb = packed struct(u16) {
    r: u5 = 0,
    g: u5 = 0,
    b: u5 = 0,
    paddng: u1 = 0,
};

const Point = packed struct(u16) {
    x: u8 = 0,
    y: u8 = 0,
};

pub const Rect = packed struct(u32) {
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
    display.Vram16[pos.y][pos.x] = @bitCast(color);
}

pub inline fn m3Line(line: Line, color: Rgb) void {
    bmp16Line(line, @bitCast(color));
}

pub inline fn m3Rect(rect: Rect, color: Rgb) void {
    bmp16Rect(rect, @bitCast(color));
}

pub inline fn m3Frame(rect: Rect, color: Rgb) void {
    bmp16Frame(rect, @bitCast(color));

}

pub inline fn m3Fill(color: Rgb) void {
    arm.bmp32Fill(@bitCast(color));
}


fn bmp16Line(line: Line, color: u16) void {
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
            // display.Vram[@intCast(start + i * x_step)] = color;
            display.Vram16[0][@intCast(start+i*x_step)] = color;
        }
    } else if (dx == 0) {
        var i: isize = 0;
        while (i <= dy) : (i += 1) {
            display.Vram[@intCast(start + i * y_step)] = color;
            // display.Vram16[0][@intCast(start+i*y_step)] = color;
        }
    } else if (dx >= dy) {
        var dd: isize = 2 * dy - dx;
        var i: isize = 0;
        while (i <= dx) : (i += 1) {
            display.Vram[@intCast(start)] = color;
            if (dd >= 0) { dd -= 2 * dx; start += y_step; }
            dd += 2 * dy;
            start += x_step;
        }
    } else {
        var dd: isize = 2 * dx - dy;
        var i: isize = 0;
        while (i <= dy) : (i += 1) {
            display.Vram[@intCast(start)] = color;
            if (dd >= 0) { dd -= 2 * dy; start += x_step; }
            dd += 2 * dx;
            start += y_step;
        }
    }
}

fn bmp16Rect(rect: Rect, color: u16) void {
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;

    for (0..height) |y| {
        for (0..width) |x| {
            display.Vram16[rect.top + y][rect.left + x] = color;
        }
    }
}

fn bmp16Frame(rect: Rect, color: u16) void {
    const new_rect: Rect = .{
        .left   = rect.left,
        .top    = rect.top,
        .right  = rect.right - 1,
        .bottom = rect.bottom - 1,
    };

    bmp16Line(.{ .x1 = new_rect.left,  .x2 = new_rect.right, .y1 = new_rect.top,    .y2 = new_rect.top }, color);
    bmp16Line(.{ .x1 = new_rect.left,  .x2 = new_rect.right, .y1 = new_rect.bottom, .y2 = new_rect.bottom }, color);

    bmp16Line(.{ .x1 = new_rect.left,  .x2 = new_rect.left,  .y1 = new_rect.top,    .y2 = new_rect.bottom }, color);
    bmp16Line(.{ .x1 = new_rect.right, .x2 = new_rect.right, .y1 = new_rect.top,    .y2 = new_rect.bottom }, color);
}
