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


    while (true) {
        tonc.m3Plot(.{ .x = 136, .y = 80 }, .{ .r =  0, .g = 31, .b =  0 });
        tonc.m3Plot(.{ .x = 120, .y = 96 }, .{ .r =  0, .g =  0, .b = 31 });
    }
}

