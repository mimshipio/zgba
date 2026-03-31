const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba.init;
const display = gba.display;
const input = gba.input;
const sys = gba.sys;

const Rgb = tonc.Rgb;

pub export fn main() linksection(".iwram") noreturn {
    display.DisplayControl.* = .{ .mode = 4, .bg2 = true };

    gba.sys.dispatchIrq();
    display.DisplayStat.*.vblank_irq = true;

    sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
    input.KeyControl.* = .{ .irq = true, .irq_type = 1 };
    sys.InterruptMaster.*.enable = true;

    const pal_bg_mem: [*]volatile u16 = @ptrFromInt(0x05000000);

    const pic_pal_data align(4) = @embedFile("gba_pic.pal.bin");
    const pic_img_data align(4) = @embedFile("gba_pic.img.bin");

    const picImgLen = 38400;
    const picPalLen = 512;

    gba.sys.bios.fastMemCpy(pic_img_data, sys.Vram, (picImgLen / @sizeOf(u32)));
    gba.sys.bios.fastMemCpy(pic_pal_data, pal_bg_mem, (picPalLen / @sizeOf(u16)));

    var frame: u32 = 0;
    var col: tonc.Rgb = .{};

    const CLR_RED: tonc.Rgb = .{.r = 31};
    const CLR_YELLOW: tonc.Rgb = .{.r = 31, .g = 31};
    const CLR_LIME: tonc.Rgb = .{.g = 31, .b = 15};
    const CLR_BLUE: tonc.Rgb = .{.b = 31};

    while (true) {
        sys.bios.vblankIntrWait();

        if ((frame & 7) == 0) {
            input.poll();
        }
        for (0..10) |key| {
            const btn: u16 = @as(u16, 1) << @intCast(key);

            if (input.key_hit(btn) != 0) {
                col = CLR_RED;
            } else if (input.key_released(btn) != 0) {
                col = CLR_YELLOW;
            } else if (input.key_held(btn) != 0) {
                col = CLR_LIME;
            } else {
                col = CLR_BLUE;
            }
            pal_bg_mem[5+key] = @as(u16, @bitCast(col));
        }

        frame += 1;
    }
}
