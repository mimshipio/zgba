export const _header linksection(".gba_header") = init.Header{};

pub const bios    = @import("bios.zig");
pub const display = @import("display.zig");
pub const init    = @import("init.zig");
pub const input   = @import("input.zig");
pub const sys     = @import("sys.zig");
pub const oam     = @import("oam.zig");
