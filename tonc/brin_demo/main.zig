const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba._init;
const disp = gba.display;
const input = gba.input;
const sys = gba.sys;
const bios = gba.bios;

const Rgb = tonc.Rgb;

pub export fn main() linksection(".iwram") noreturn {
    disp.DisplayStat.*.vblank_irq = true;
    sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
    input.KeyControl.*    = .{ .irq = true, .irq_type = 1 };
    sys.InterruptMaster.*.enable = true;

    disp.BackgroundControl0.* = .{
        .char_block = 0,
        .screen_block = 30,
        .palette_type = .c16,
        .bg_size = 1,
    };
    disp.DisplayControl.* = .{ .mode = 0, .bg0 = true };

    const pic_pal_data align(4) = @embedFile("brin.pal.bin");
    const pic_img_data align(4) = @embedFile("brin.img.bin").*;
    const pic_map_data align(4) = @embedFile("brin.map.bin").*;

    bios.cpuFastSet( pic_pal_data,  disp.PaletteMem);
    bios.cpuFastSet(&pic_img_data, &disp.VideoMemory.@"tile");
    bios.cpuFastSet(&pic_map_data, &disp.VideoMemory.@"block"[30]);

    var x: i16 = 192;
    var y: i16 = 64;

    while (true) {
        bios.vBlankIntrWait();
        input.poll();

        x += if (input.KEYINPUT.held(.{ .right = true })) 1
            else if (input.KEYINPUT.held(.{ .left = true })) -1
                else 0;
        y += if (input.KEYINPUT.held(.{ .down = true })) 1
            else if (input.KEYINPUT.held(.{ .up = true })) -1
                else 0;

        disp.BackgroundOffset0.* = disp.BGOFFSET_HV{
            .horizontal = .{ .offset = @intCast(x) },
            .vertical   = .{ .offset = @intCast(y) },
        };
    }
}
