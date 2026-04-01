const std = @import("std");

pub fn build(b: *std.Build) void {
    const target_arm = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.arm7tdmi },
    });
    const target_thumb = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.arm7tdmi },
    });

    const optimize = b.standardOptimizeOption(.{});

    const gba_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target_thumb,
        .optimize = optimize,
    });

    const tonc_arm_mod = b.createModule(.{
        .root_source_file = b.path("tonc/arm/root.zig"),
        .target = target_arm,
        .optimize = optimize,
    });

    const tonc_mod = b.createModule(.{
        .root_source_file = b.path("tonc/root.zig"),
        .target = target_thumb,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gba", .module = gba_mod },
            .{ .name = "arm", .module = tonc_arm_mod },
        },
    });

    const main_mod = b.createModule(.{
        // .root_source_file = b.path("tonc/second/main.zig"),
        // .root_source_file = b.path("tonc/key_demo/main.zig"),
        .root_source_file = b.path("tonc/m3_demo/main.zig"),
        .target = target_thumb,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "tonc", .module = tonc_mod },
            .{ .name = "gba", .module = gba_mod },
        },
    });

    const elf = b.addExecutable(.{
        .name = "a.bin",
        .root_module = main_mod,
    });

    elf.setLinkerScript(b.path("gba.ld"));

    const installAssembly = b.addInstallBinFile(elf.getEmittedAsm(), "gba.s");
    b.getInstallStep().dependOn(&installAssembly.step);

    const bin = elf.addObjCopy(.{ .format = .bin });
    const gba_file = bin.getOutput();
    const install_bin = b.addInstallFile(gba_file, "my_game.bin");

    const fixer_tool = b.addExecutable(.{
        .name = "gbafix",
        .root_module = b.createModule(
            .{
                .root_source_file = b.path("tools/gbafix.zig"),
                .target = b.standardTargetOptions(.{}),
            }),
    });

    b.installArtifact(fixer_tool);
    const run_fixer = b.addRunArtifact(fixer_tool);
    run_fixer.step.dependOn(&bin.step);
    run_fixer.addFileArg(gba_file);

    const install_rom = b.addInstallFile(gba_file, "my_game.gba");
    install_rom.step.dependOn(&run_fixer.step);
    
    b.getInstallStep().dependOn(&install_bin.step);
    b.getInstallStep().dependOn(&install_rom.step);
}
