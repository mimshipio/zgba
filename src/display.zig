const DISPCNT = packed struct(u16) {
    mode:          u3  = 0,
    gbc_mode:      u1  = 0, // read-only
    page_select:   u1  = 0,
    hblank_oam:    u1  = 0,
    obj_id:        u1  = 0,
    force_blank:   u1  = 0,
    bg0:           bool = false,
    bg1:           bool = false,
    bg2:           bool = false,
    bg3:           bool = false,
    obj:           bool = false,
    win0:          bool = false,
    win1:          bool = false,
    win_obj:       bool = false,
};
pub const DisplayControl: *volatile DISPCNT = @as(*volatile DISPCNT, @ptrFromInt(0x04000000));

const DISPSTAT = packed struct(u16) {
    vblank_status:   u1 = 0,
    hblank_status:   u1 = 0,
    vcount:          u1 = 0,
    vblank_irq:      bool = false,
    hblank_irq:      bool = false,
    vcount_irq:      bool = false,
    padding:         u2 = 0,
    vcount_irq_line: u8 = 0,
};
pub const DisplayStat: *volatile DISPSTAT = @as(*volatile DISPSTAT, @ptrFromInt(0x04000004));

const VCOUNT = packed struct(u16) {
    vcount:    u8 = 0,
    read_only: u8 = 0, // a read-only mirror
};
pub const VCount: *volatile VCOUNT = @as(*volatile VCOUNT, @ptrFromInt(0x04000006));

const BGCNT = packed struct(u16) {
    priority:     u2 = 0,
    char_data:    u2 = 0,
    padding:      u2 = 0,
    mosaic:       bool = false,
    palette_type: u1 = 0,
    char_tmap:    u5 = 0,
    screen_over:  bool = false,
    tmap_size:    u2 = 0,
};
pub const BackgroundControl0: *volatile BGCNT = @as(*volatile BGCNT, @ptrFromInt(0x04000008));
pub const BackgroundControl1: *volatile BGCNT = @as(*volatile BGCNT, @ptrFromInt(0x0400000A));
pub const BackgroundControl2: *volatile BGCNT = @as(*volatile BGCNT, @ptrFromInt(0x0400000C));
pub const BackgroundControl3: *volatile BGCNT = @as(*volatile BGCNT, @ptrFromInt(0x0400000E));
