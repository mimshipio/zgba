const std = @import("std");

pub export fn vBlankIntrWait() linksection(".iwram") void {
    asm volatile ("swi 0x05"
        ::: .{ .r0 = true, .r1 = true, .r2 = true, .r3 = true, .memory = true }
    );
}
pub fn cpuFastSet(src: anytype, dest: anytype, control: u32) linksection(".text") void {
    asm volatile ("swi 0x0C"
        :
        : [src]     "{r0}" (src),
          [dest]    "{r1}" (dest),
          [control] "{r2}" (control),
        : .{ .r0 = true, .r1 = true, .r2 = true, .r3 = true }
    );
}
