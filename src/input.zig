const KEYINPUT = packed struct(u16) {
    a:      bool = false,
    b:      bool = false,
    select: bool = false,
    start:  bool = false,
    right:  bool = false,
    left:   bool = false,
    up:     bool = false,
    down:   bool = false,
    r:      bool = false,
    l:      bool = false,
    padding:  u6 = 0,
};
const KeyInput: *volatile KEYINPUT = @as(*volatile KEYINPUT, @ptrFromInt( 0x04000130));

const KEYCTL = packed struct(u16) {
    a:      bool = false,
    b:      bool = false,
    select: bool = false,
    start:  bool = false,
    dpad_r: bool = false,
    dpad_l: bool = false,
    dpad_u: bool = false,
    dpad_d: bool = false,
    trgr_r: bool = false,
    trgr_l: bool = false,
    padding:  u4 = 0,
    irq:    bool = false,
    irq_type: u1 = 0,
};
pub const KeyControl: *volatile KEYCTL = @as(*volatile KEYCTL, @ptrFromInt( 0x04000132));
var key_previous: u16 = 0;
var key_current: u16 = 0;
var key_repeat: REPEATREC = .{};

const REPEATREC = struct {
    keys:  u16 = 0, // Repeated keys.
    mask:  u16 = 0, // Only check repeats for these keys.
    count:  u8 = 60, // Repeat counter.
    delay:  u8 = 60, // Limit for first repeat.
    repeat: u8 = 30, // Limit for successive repeats.
};

pub fn poll() linksection(".iwram.irq") void {
    key_previous = key_current;
    key_current = ~@as(u16, @bitCast(KeyInput.*)) & 0x03FF;

    const rpt: *REPEATREC = &key_repeat;

    rpt.keys = 0; // Clear repeats again

    if (rpt.delay > 0) {
        if (Key.transit(rpt.mask)) {
            rpt.count = rpt.delay;
            rpt.keys = key_current;
        }
        else {
            rpt.count -= 1;
        }

        // Time's up: set repeats (for this frame)
        if (rpt.count == 0) {
            rpt.count = rpt.repeat;
            rpt.keys = key_current & rpt.mask;
        }
    }
}

pub const Key = struct {
    pub const Index = struct {
        pub const a:      u4 = 0;
        pub const b:      u4 = 1;
        pub const select: u4 = 2;
        pub const start:  u4 = 3;
        pub const right:  u4 = 4;
        pub const left:   u4 = 5;
        pub const down:   u4 = 6;
        pub const up:     u4 = 7;
        pub const r:      u4 = 8;
        pub const l:      u4 = 9;
    };

    pub const a:      u16 = 1 << 0;
    pub const b:      u16 = 1 << 1;
    pub const select: u16 = 1 << 2;
    pub const start:  u16 = 1 << 3;
    pub const right:  u16 = 1 << 4;
    pub const left:   u16 = 1 << 5;
    pub const down:   u16 = 1 << 6;
    pub const up:     u16 = 1 << 7;
    pub const r:      u16 = 1 << 8;
    pub const l:      u16 = 1 << 9;

    pub inline fn transit(key: u16) bool {
        return ((( key_current ^ key_previous ) & key) != 0);
    }
    pub inline fn hit(key: u16) bool {
        return ((( key_current & ~key_previous ) & key) != 0);
    }
    pub inline fn released(key: u16) bool {
        return ((( ~key_current & key_previous ) & key)) != 0;
    }
    pub inline fn held(key: u16) bool {
        return ((( key_current & key_previous ) & key)) != 0;
    }
};

pub fn key_tri_vert() i16 {
    return bit_tribool(key_current, Key.Index.up, Key.Index.down);
}
pub fn key_tri_horz() i16 {
    return bit_tribool(key_current, Key.Index.right, Key.Index.left);
}

inline fn bit_tribool(flags: u16, plus: u4, minus: u4) i16 {
    const p = (flags >> plus) & 1;
    const m = (flags >> minus) & 1;
    return @intCast(p - m);
}
