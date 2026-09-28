const DmaControl = packed struct(u16) {
    _padding: u5 = 0,
    dst_control: enum(u2) { increment, decrement, fixed, inc_reload } = .increment,
    src_control: enum(u2) { increment, decrement, fixed, prohib } = .increment,
    repeat:  bool = false,
    bitness: enum(u1) { @"16", @"32" } = .@"16",
    game_pak_drq: enum(u1) { normal, drq } = .normal,
    /// .start = special: DMA0=Prohibited, DMA1/DMA2=Sound FIFO, DMA3=Video Capture
    start: enum(u2) { immediately, vblank, hblank, special } = .immediately,
    irq_on_finish: bool = false,
    dma_enable: bool = false,
};
const DmaChan = packed struct(u96) {
    src:       u32 = 0,
    dst:       u32 = 0,
    control_l: u16 = 0, // word count
    control_h: DmaControl = .{},
};
pub const DmaChannels: *volatile [4]DmaChan = @ptrFromInt(0x40000b0);
