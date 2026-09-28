# ZGBA: a GameBoy Advance SDK written in Zig
Why Zig? Simpler and more ergonomic than C, and has an actual build system out of the box.

# Examples (libtonc reimplementations)
To build the examples, run
`zig build`
This will output several .gba file in `zig-out/` that can be run with an emulator.
I would strongly discourage anyone from trying to run any of the examples on actual hardware,
as my GBA knowledge is quite limited and I cannot guarantee that you won't damage your device.

# Note
Not much has been implemented to make an actual game yet.

# Roadmap
- [ ] Reimplement all libtonc examples
- [ ] Implement
    - [ ] All BIOS `swi` functions
    - [ ] std.Io
    - [ ] std.Reader/Writer
    - [ ] std.mem.Allocator
    - [ ] Panic handler
    - [ ] Logger
    - [ ] Vector Maths
