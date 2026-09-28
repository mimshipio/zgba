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
    display.DisplayStat.*.vblank_irq = true;
    sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
    input.KeyControl.* = .{ .irq = true, .irq_type = 1 };
    sys.InterruptMaster.*.enable = true;

    const pic_pal_data align(4) = @embedFile("modes.pal.bin").*;
    const pic_img_data align(4) = @embedFile("modes.img.bin").*;

    bios.cpuFastSet(&pic_img_data, display.VideoMemory);
    bios.cpuFastSet(&pic_pal_data, display.PaletteMem);

    var mode: u3 = 3;

    while (true) {
        bios.vBlankIntrWait();

        input.poll();

        if (input.KEYINPUT.hit(.{ .left = true }) and mode > 3) {
            mode -= 1;
        } else if (input.KEYINPUT.hit(.{ .right = true }) and mode < 5) {
            mode += 1;
        }

        display.DisplayControl.* = .{ .mode = mode, .bg2 = true };
    }
}
