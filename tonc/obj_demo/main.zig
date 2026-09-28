const std = @import("std");

const gba = @import("gba");
const tonc = @import("tonc");

const init = gba.init;
const disp = gba.display;
const input = gba.input;
const sys = gba.sys;
const bios = gba.bios;
const oam = gba.oam;

const Rgb = tonc.Rgb;

pub export fn main() linksection(".iwram") noreturn {
    disp.DisplayStat.*.vblank_irq = true;
    sys.InterruptEnable.* = .{ .vblank_irq = true, .key_irq = true };
    input.KeyControl.* = .{ .irq = true, .irq_type = 1 };
    sys.InterruptMaster.*.enable = true;

    const pic_pal_data align(4) = @embedFile("metr.pal.bin");
    const pic_img_data align(4) = @embedFile("metr.img.bin").*;

    bios.cpuFastSet(pic_pal_data,  disp.SpriteMem,);
    bios.cpuFastSet(&pic_img_data, &disp.VideoMemory.@"tile"[4]);

    var x: u9 = 96;
    var y: u8 = 32;
    var tile_id: u10 = 10;
    var palette_bank: u4 = 0;

    oam.ObjectAttributeMemory.objects[0] = .{
        .attr0 = .{ .shape = .square, .color_mode = .@"4bit" },
        .attr1 = .{ .standard = .{ .size = 3 } },
        .attr2 = .{ .tile_idx = tile_id, .palette_idx = palette_bank },
    };

    disp.DisplayControl.* = .{ .obj = true, .obj_id = true, };

    while (true) {
        bios.vBlankIntrWait();
        input.poll();

        if (input.KEYINPUT.held(.{ .left = true }))
            x -%= 1
        else if (input.KEYINPUT.held(.{ .right = true }))
            x +%= 1;

        if (input.KEYINPUT.held(.{ .down = true }))
            y -%= 1
        else if (input.KEYINPUT.held(.{ .up = true }))
            y +%= 1;

        if (input.KEYINPUT.hit(.{ .l = true }))
            tile_id -%= 1
        else if (input.KEYINPUT.hit(.{ .r = true }))
            tile_id +%= 1;

        if (input.KEYINPUT.hit(.{ .a = true }))
            oam.ObjectAttributeMemory.objects[0].attr1.standard.flip_h =
                ~oam.ObjectAttributeMemory.objects[0].attr1.standard.flip_h;
        if (input.KEYINPUT.hit(.{ .b = true }))
            oam.ObjectAttributeMemory.objects[0].attr1.standard.flip_v =
                ~oam.ObjectAttributeMemory.objects[0].attr1.standard.flip_v;

        palette_bank = if (input.KEYINPUT.held(.{ .select = true })) 1 else 0;

        if(input.KEYINPUT.hit(.{ .start = true }))
            disp.DisplayControl.obj_id =
                ~disp.DisplayControl.obj_id;

        oam.ObjectAttributeMemory.objects[0].attr0.y = y;
        oam.ObjectAttributeMemory.objects[0].attr1.standard.x = x;
        oam.ObjectAttributeMemory.objects[0].attr2.palette_idx = palette_bank;
        oam.ObjectAttributeMemory.objects[0].attr2.tile_idx = tile_id;
    }
}
