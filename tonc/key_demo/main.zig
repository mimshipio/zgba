const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba.init;
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

    display.DisplayControl.* = .{ .mode = 4, .bg2 = true };

    const pic_pal_data align(4) = @embedFile("gba_pic.pal.bin").*;
    const pic_img_data align(4) = @embedFile("gba_pic.img.bin").*;

    bios.cpuFastSet(&pic_img_data, display.VideoMemory);
    bios.cpuFastSet(&pic_pal_data, display.PaletteMem);

    var frame: u16 = 0;

    const CLR_RED: tonc.Rgb = .{.r = 31};
    const CLR_YELLOW: tonc.Rgb = .{.r = 31, .g = 31};
    const CLR_LIME: tonc.Rgb = .{.g = 31, .b = 15};
    const CLR_UP: tonc.Rgb = .{.r = 27, .g = 27, .b = 29};

    while (true) : (frame += 1) {
        bios.vBlankIntrWait();

        if ((frame & 7) == 0) {
            input.poll();
        }
        for (0..10) |key| {
            var col: tonc.Rgb = .{};

            const btn: input.KEYINPUT = @bitCast(@as(u16, 1) << @intCast(key));

            if (input.KEYINPUT.hit(btn)) {
                col = CLR_RED;
            } else if (input.KEYINPUT.released(btn)) {
                col = CLR_YELLOW;
            } else if (input.KEYINPUT.held(btn)) {
                col = CLR_LIME;
            } else {
                col = CLR_UP;
            }
            display.PaletteMem[5+key] = @as(u16, @bitCast(col));
        }
    }
}
