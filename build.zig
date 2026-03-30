const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.arm7tdmi },
    });

    const optimize = b.standardOptimizeOption(.{});

    const gba_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const elf = b.addExecutable(.{
        .name = "a.bin",
        .root_module = gba_mod,
    });

    elf.setLinkerScript(b.path("gba.ld"));

    const bin = elf.addObjCopy(.{ .format = .bin });
    const gba_file = bin.getOutput();

    const fixer_tool = b.addExecutable(.{
        .name = "gbafix",
        .root_module = b.createModule(
            .{
                .root_source_file = b.path("tools/gbafix.zig"),
                .target = b.graph.host,
            }),
    });

    const run_fixer = b.addRunArtifact(fixer_tool);
    run_fixer.step.dependOn(&bin.step);
    run_fixer.addFileArg(gba_file);

    const install_rom = b.addInstallFile(gba_file, "my_game.gba");
    install_rom.step.dependOn(&run_fixer.step);
    
    b.getInstallStep().dependOn(&install_rom.step);
}
