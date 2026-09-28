const Attr0 = packed struct(u16) {
    /// Starts at top left if affine is off, or centre if affine is on
    /// Values wrap around; to achieve a -1 y coordinate, use y = 255.
    y:             u8 = 0,
    affine:      bool = false,
    double_size: bool = false,
    transparency: enum(u2) { normal, semi, obj_window, prohib } = .normal,
    mosaic: bool = false,
    color_mode: enum(u1) { @"4bit", @"8bit" } = .@"4bit",
    shape: enum(u2) { square, horizontal, vertical, prohib } = .square,
};
const Attr1 = packed union {
    /// Layout when Attribute 0 Bit 8 (affine) is false
    standard: packed struct(u16) {
        x:        u9 = 0,
        _padding: u3 = 0,
        flip_h: bool = false,
        flip_v: bool = false,
        size:     u2 = 0,
    },
    
    /// Layout when Attribute 0 Bit 8 (affine) is true
    affine: packed struct(u16) {
        x_coord:    u9 = 0,
        affine_idx: u5 = 0,
        size:       u2 = 0,
    },
};
const Attr2 = packed struct(u16) {
    tile_idx:   u10 = 0,
    priority:    u2 = 0, // 0 is highest
    palette_idx: u4 = 0, // only used in 4bit colour mode
};
const ObjectEntry = packed struct(u64) {
    attr0: Attr0 = .{},
    attr1: Attr1 = .{.standard = .{}},
    attr2: Attr2 = .{},
    attr3: i16 = 0,
};
// const AffineMatrix = packed struct(u256) {
//     // PA
//     shrink_x: i16, _pad0: u48,
//     // PB
//     shear_x:  i16, _pad1: u48,
//     // PC
//     shear_y:  i16, _pad2: u48,
//     // PD
//     shrink_y: i16, _pad3: u48,
// };
pub const ObjectAttributeMemoryType = extern union {
    objects: [128]ObjectEntry,
    // matrices: [32]AffineMatrix,
};
pub const ObjectAttributeMemory: *volatile ObjectAttributeMemoryType = @ptrFromInt(0x7000000);
