pub const KEYINPUT = packed struct(u16) {
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

    inline fn toInt(self: KEYINPUT) u16 {
        return @bitCast(self);
    }

    pub inline fn transit(self: KEYINPUT) bool {
        return ((( key_current.toInt() ^ key_previous.toInt() ) & self.toInt()) != 0);
    }
    pub inline fn hit(self: KEYINPUT) bool {
        return ((( key_current.toInt() & ~key_previous.toInt() ) & self.toInt()) != 0);
    }
    pub inline fn released(self: KEYINPUT) bool {
        return ((( ~key_current.toInt() & key_previous.toInt() ) & self.toInt())) != 0;
    }
    pub inline fn held(self: KEYINPUT) bool {
        return ((( key_current.toInt() & key_previous.toInt() ) & self.toInt())) != 0;
    }

    // inline fn tribool(plus: KEYINPUT, minus: KEYINPUT) i2 {
    //     return @intCast(plus.toInt()&1 - minus.toInt()&1);
    // }
};
const KeyInput: *volatile KEYINPUT = @as(*volatile KEYINPUT, @ptrFromInt( 0x04000130));

const KEYCTL = packed struct(u16) {
    a:      bool = false,
    b:      bool = false,
    select: bool = false,
    start:  bool = false,
    right:  bool = false,
    left:   bool = false,
    up:     bool = false,
    down:   bool = false,
    trgr_r: bool = false,
    trgr_l: bool = false,
    padding:  u4 = 0,
    irq:    bool = false,
    irq_type: u1 = 0,
};
pub const KeyControl: *volatile KEYCTL = @as(*volatile KEYCTL, @ptrFromInt( 0x04000132));
var key_previous: KEYINPUT = .{};
var key_current:  KEYINPUT = .{};
var key_repeat:   REPEATREC = .{};

const REPEATREC = struct {
    keys:   KEYINPUT = .{}, // Repeated keys
    mask:   KEYINPUT = .{}, // Only check repeats for these keys
    count:  u8       = 60,  // Repeat counter
    delay:  u8       = 60,  // Limit for first repeat
    repeat: u8       = 30,  // Limit for successive repeats
};

pub fn poll() linksection(".iwram.irq") void {
    key_previous = key_current;
    key_current = @bitCast(~@as(u16, @bitCast(KeyInput.*)) & 0x03FF);

    const rpt: *REPEATREC = &key_repeat;

    rpt.keys = .{}; // Clear repeats again

    if (rpt.delay > 0) {
        if (rpt.mask.transit()) {
            rpt.count = rpt.delay;
            rpt.keys = key_current;
        }
        else {
            rpt.count -%= 1;
        }

        // Time's up: set repeats (for this frame)
        if (rpt.count == 0) {
            rpt.count = rpt.repeat;
            rpt.keys = @bitCast( key_current.toInt() & rpt.mask.toInt() );
        }
    }
}
