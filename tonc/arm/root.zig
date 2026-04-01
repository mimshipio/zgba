pub const Vram: [*]volatile u32 = @ptrFromInt(0x06000000);

pub fn bmp32Fill(color: u16) linksection(".text.arm") void {
    // 1. Prepare the 32-bit word (two 16-bit pixels)
    // We must cast clr to u32 before shifting, otherwise it overflows
    const wd: u32 = (@as(u32, color) << 16) | color;

    // 2. Fill the memory
    // M3_SIZE / 4 in C represents the number of 32-bit words
    // (240 * 160 * 2 bytes total / 4 bytes per u32 = 19,200 iterations)
    var i: usize = 0;
    while (i < (240 * 160) / 2) : (i += 1) {
        Vram[i] = wd;
    }
}
