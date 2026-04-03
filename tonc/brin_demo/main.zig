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
    gba.sys.dispatchIrq();
    disp.DisplayStat.*.vblank_irq = true;

    sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
    input.KeyControl.* = .{ .irq = true, .irq_type = 1 };
    sys.InterruptMaster.*.enable = true;

    disp.BackgroundControl0.* = .{
        .char_block = 0,
        .palette_type = .c16_bit,
        .screen_block = 30,
        .bg_size = 1,
    };
    disp.DisplayControl.* = .{ .mode = 0, .bg0 = true };

    const pic_pal_data = @embedFile("brin.pal.bin");
    const pic_img_data align(4) = @embedFile("brin.img.bin").*;
    const pic_map_data align(4) = @embedFile("brin.map.bin").*;

    const picPalLen = 512;
    const picMapLen = 4096;
    const picImgLen = 992;

    bios.cpuFastSet(pic_pal_data, disp.PaletteMem, (picPalLen / @sizeOf(u32)));
    bios.cpuFastSet(&pic_img_data, &disp.TileMem.*, (picImgLen / @sizeOf(u32)));
    bios.cpuFastSet(&pic_map_data, &disp.ScreenBlockMem.*[30], (picMapLen / @sizeOf(u32)));

    var x: i16 = 192;
    var y: i16 = 64;
    while (true) {
        bios.vBlankIntrWait();

        input.poll();

        x += input.key_tri_horz();
        y += input.key_tri_vert();

        disp.BG0HOFS.* = @intCast(x);
        disp.BG0VOFS.* = @intCast(y);
    }
}
