const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba.init;
const display = gba.display;
const input = gba.input;
const sys = gba.sys;

const Rgb = tonc.Rgb;

pub export fn main() callconv(.{ .arm_aapcs = .{} }) noreturn {
    display.DisplayControl.* = .{ .mode = 3, .bg2 = true };

    tonc.m3Rect(
        .{ .left = 12, .right = 108, .top = 8, .bottom = 72 },
        .{ .r =  31, .g = 0, .b =  0 });
    tonc.m3Rect(
        .{ .left = 108, .right = 132, .top = 72, .bottom = 88 },
        .{ .r =  0, .g = 31, .b =  0 });
    tonc.m3Rect(
        .{ .left = 132, .right = 228, .top = 88, .bottom = 152 },
        .{ .r =  0, .g = 0, .b =  31 });

    tonc.m3Frame(
        .{ .left = 132, .right = 228, .top = 8, .bottom = 72 },
        .{ .r =  31, .g = 0, .b =  31 });
    tonc.m3Frame(
        .{ .left = 109, .right = 131, .top = 73, .bottom = 87 },
        .{ .r =  0, .g = 0, .b =  0 });
    tonc.m3Frame(
        .{ .left = 12, .right = 108, .top = 88, .bottom = 152 },
        .{ .r =  0, .g = 31, .b =  31 });

    for (0..8) |i| {
        const ii: u8 = @intCast(i);
        const jj: u8 = @intCast(3*ii+7);
        tonc.m3Line(
            .{ .x1 = 132+11*ii, .y1 = 9, .x2 = 226, .y2 = 12+7*ii, },
            .{ .r = @intCast(jj), .g = 0, .b = @intCast(jj) });
        tonc.m3Line(
            .{ .x1 = 226-11*ii, .y1 = 70, .x2 = 133, .y2 = 69-7*ii, },
            .{ .r = @intCast(jj), .g = 0, .b = @intCast(jj) });
        tonc.m3Line(
            .{ .x1 = 15+11*ii, .y1 = 88, .x2 = 104-11*ii, .y2 = 150, },
            .{ .r = 0, .g = @intCast(jj), .b = @intCast(jj) });
    }

    while (true) { }
}

