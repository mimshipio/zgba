const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba.init;
const display = gba.display;
const input = gba.input;
const sys = gba.sys;

const Rgb = tonc.Rgb;

const RED    = Rgb{ .r = 31, .g =  0, .b =   0 };
const GREEN  = Rgb{ .r =  0, .g = 31, .b =   0 };
const BLUE   = Rgb{ .r =  0, .g =  0, .b =  31 };
const CYAN   = Rgb{ .r =  0, .g = 31, .b =  31 };
const BLACK  = Rgb{ .r =  0, .g =  0, .b =   0 };
const YELLOW = Rgb{ .r = 31, .g = 31, .b =   0 };

pub export fn main() noreturn {
    display.DisplayControl.* = .{ .mode = 3, .bg2 = true };

    tonc.m3Fill(.{ .r = 12, .g = 12, .b = 14 });

    const rec0 = tonc.Rect{ .left = 12, .right = 108, .top = 8, .bottom = 72 };
    tonc.m3Rect( rec0, RED );

    const rec1 = tonc.Rect{ .left = 108, .right = 132, .top = 72, .bottom = 88 };
    tonc.m3Rect( rec1, GREEN );

    const rec2 = tonc.Rect{ .left = 132, .right = 228, .top = 88, .bottom = 152 };
    tonc.m3Rect( rec2, BLUE );

    tonc.m3Frame(
        .{ .left = 132, .right = 228, .top = 8, .bottom = 72 },
        CYAN);
    tonc.m3Frame(
        .{ .left = 109, .right = 131, .top = 73, .bottom = 87 },
        BLACK);
    tonc.m3Frame(
        .{ .left = 12, .right = 108, .top = 88, .bottom = 152 },
        YELLOW);

    for (0..9) |i| {
        const ii: u8 = @intCast(i);
        const jj: u8 = @intCast(3*ii+7);
        tonc.m3Line(
            .{ .x1 = 132+11*ii,    .y1 =  9,  .x2 = 226, .y2 = 12+7*ii, },
            .{ .r  = @intCast(jj), .g  =  0,           .b = @intCast(jj) });
        tonc.m3Line(
            .{ .x1 = 226-11*ii,    .y1 = 70, .x2 = 133, .y2 = 69-7*ii, },
            .{ .r  = @intCast(jj), .g  =  0,           .b = @intCast(jj) });
        tonc.m3Line(
            .{ .x1 = 15+11*ii,     .y1 = 88, .x2 = 104-11*ii, .y2 = 150, },
            .{ .r  = 0,            .g  = @intCast(jj), .b = @intCast(jj) });
    }

    while (true) { }
}

