const std = @import("std");

pub fn softReset() void {
    asm volatile ("swi 0x00"); // No clobbers because it resets the CPU
}
pub export fn vBlankIntrWait() linksection(".text") void {
    asm volatile ("swi 0x05"
        ::: .{ .r0 = true, .r1 = true, .r2 = true, .r3 = true }
    );
}
pub fn cpuFastSet(src: anytype, dest: anytype) linksection(".text") void {
    asm volatile ("swi 0x0C"
        :
        : [src]     "{r0}" (src),
          [dest]    "{r1}" (dest),
          [control] "{r2}" (src.len / @sizeOf(u32)),
        : .{ .r0 = true, .r1 = true, .r2 = true, .r3 = true }
    );
}
