const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba._init;
const display = gba.display;
const input = gba.input;
const sys = gba.sys;
const bios = gba.bios;

const Rgb = tonc.Rgb;

pub export fn main() linksection(".iwram") noreturn {
    gba.sys.dispatchIrq();
    display.DisplayStat.*.vblank_irq = true;

    sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
    input.KeyControl.* = .{ .irq = true, .irq_type = 1 };
    sys.InterruptMaster.*.enable = true;

    const pic_pal_data align(4) = @embedFile("modes.pal.bin").*;
    const pic_img_data align(4) = @embedFile("modes.img.bin").*;

    const picImgLen = 76800;
    const picPalLen = 512;

    bios.cpuFastSet(&pic_img_data, display.Vram,       (picImgLen / @sizeOf(u32)));
    bios.cpuFastSet(&pic_pal_data, display.PaletteMem, (picPalLen / @sizeOf(u32)));

    var mode: u3 = 3;

    while (true) {
        bios.vBlankIntrWait();

        input.poll();

        if (input.Key.hit(input.Key.left) and mode > 3) {
            mode -= 1;
        } else if (input.Key.hit(input.Key.right) and mode < 5) {
            mode += 1;
        }

        display.DisplayControl.* = .{ .mode = mode, .bg2 = true };
    }
}
