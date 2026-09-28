const DISPCNT = packed struct(u16) {
    mode:          u3  = 0,
    gbc_mode:     bool = false, // read-only
    page_select:  bool = false,
    hblank_oam:   bool = false,
    obj_id:       bool = false,
    force_blank:  bool = false,
    bg0:          bool = false,
    bg1:          bool = false,
    bg2:          bool = false,
    bg3:          bool = false,
    obj:          bool = false,
    win0:         bool = false,
    win1:         bool = false,
    win_obj:      bool = false,
};
pub const DisplayControl: *volatile DISPCNT = @as(*volatile DISPCNT, @ptrFromInt(0x04000000));

const DISPSTAT = packed struct(u16) {
    vblank_status:   u1 = 0,
    hblank_status:   u1 = 0,
    vcount:          u1 = 0,
    vblank_irq:    bool = false,
    hblank_irq:    bool = false,
    vcount_irq:    bool = false,
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
    priority:       u2 = 0,
    char_block:     u2 = 0,
    padding:        u2 = 0,
    mosaic:       bool = false,
    palette_type:
        enum(u1) {
            c16,
            c256,
        } = .c16,
    screen_block:   u5 = 0,
    affine_wrap:  bool = false,
    bg_size:        u2 = 0,
};
pub const BackgroundControl0: *volatile BGCNT = @ptrFromInt(0x04000008);
pub const BackgroundControl1: *volatile BGCNT = @ptrFromInt(0x0400000A);
pub const BackgroundControl2: *volatile BGCNT = @ptrFromInt(0x0400000C);
pub const BackgroundControl3: *volatile BGCNT = @ptrFromInt(0x0400000E);

const BGOFFSET = packed struct(u16) {
    offset:   u9 = 0,
    _padding: u7 = 0,
};
pub const BGOFFSET_HV = packed struct(u32) {
    horizontal: BGOFFSET = .{},
    vertical:   BGOFFSET = .{},
};
pub const BackgroundOffset0:  *volatile BGOFFSET_HV = @ptrFromInt(0x04000010);
pub const BackgroundOffset1:  *volatile BGOFFSET_HV = @ptrFromInt(0x04000014);
pub const BackgroundOffset2:  *volatile BGOFFSET_HV = @ptrFromInt(0x04000018);
pub const BackgroundOffset3:  *volatile BGOFFSET_HV = @ptrFromInt(0x0400001c);

// pub const PaletteMem = extern struct {
//     pub const bg:  *volatile [0x100]u16 = @ptrFromInt(0x05000000);
//     pub const obj: *volatile [0x100]u16 = @ptrFromInt(0x05000200);
// };
pub const PaletteMem: [*]volatile u16 = @ptrFromInt(0x05000000);
pub const SpriteMem:  [*]volatile u16  = @ptrFromInt(0x05000200);

pub const VideoMemoryType = extern union {
    raw:       [0xc000]u16,
    @"16-bit": [160][240]u16,
    @"32-bit": [160][120]u32,
    @"tile":   [6][512][32]u8,
    @"block":  [32][32][32]u16,
};
pub const VideoMemory: *volatile VideoMemoryType = @ptrFromInt(0x6000000);

const Attr0 = packed struct(u16) {
    /// Starts at top left if affine is off, or centre if affine is on
    /// Values wrap around; to achieve a -1 y coordinate, use y = 255.
    y:             u8 = 0,
    affine:      bool = false,
    double_size: bool = false,
    transparency:
        enum(u2) {
            normal,
            semi,
            obj_window,
            illegal,
        } = .normal,
    mosaic: bool = false,
    color_mode:
        enum(u1) {
            c16_bit,
            c256,
        } = .c16_bit,
    size: u2 = 0,
};
const Attr1 = packed union {
    /// Layout when Attribute 0 Bit 8 (Rotation/Scaling) is 0
    standard: packed struct(u16) {
        x_coord:  u9 = 0,
        unused:   u3 = 0,
        flip_h: bool = false,
        flip_v: bool = false,
        size:     u2 = 0,
    },
    
    /// Layout when Attribute 0 Bit 8 (Rotation/Scaling) is 1
    affine: packed struct(u16) {
        x_coord:    u9 = 0,
        affine_idx: u5 = 0,
        size:       u2 = 0,
    },
};
const Attr2 = packed struct(u16) {
    tile_idx:   u10 = 0,
    priority:    u2 = 0,
    palette_idx: u4 = 0,
};
const Attr3 = packed struct(u16) {
    fraction: u8 = 0,
    integer:  u7 = 0,
    sign:     u1 = 0
};
const OAM = packed struct(u64) {
    attr0: Attr0 = .{},
    attr1: Attr1 = .{.standard = .{}},
    attr2: Attr2 = .{},
    attr3: Attr3 = .{},
};
pub const Oam: [*]volatile OAM = @ptrFromInt(0x07000000);
