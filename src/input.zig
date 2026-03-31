const KEYINPUT = packed struct(u16) {
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
    padding: u6 = 0,
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

comptime {
    asm (
        \\.section .iwram, "ax", %progbits
        \\.thumb
        \\.thumb_func
        \\.global poll
        \\poll:
        \\  @ thumb instructions here
        \\  bx lr
    );
}

pub fn poll() void {
    KeyControl.*.irq = true;

    key_previous = key_current;
    key_current = ~@as(u16, @bitCast(KeyControl.*)) & @as(u16, @bitCast(KeyInput.*));

    const rpt: *REPEATREC = &key_repeat;

    rpt.keys = 0;	// Clear repeats again

    if (rpt.delay > 0) {
        if(key_transit(rpt.mask) != 0) {
            rpt.count = rpt.delay;
            rpt.keys = key_current;
        }
        else
            rpt.count -= 1;

        // Time's up: set repeats (for this frame)
        if(rpt.count == 0) {
            rpt.count = rpt.repeat;
            rpt.keys = key_current & rpt.mask;
        }
    }
}

pub inline fn key_transit(key: u32) u32 {
    return ( key_current ^ key_previous) & key;
}
pub inline fn key_hit(key: u32) u32 {
    return ( key_current&~ key_previous) & key;
}
pub inline fn key_released(key: u32) u32 {
    return ( ~key_current & key_previous) & key;
}
pub inline fn key_held(key: u32) u32 {
    return ( key_current & key_previous) & key;
}
