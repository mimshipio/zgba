const std = @import("std");
const Compile = std.Build.Step.Compile;

pub fn build(b: *std.Build) !void {
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

    const target_native = b.standardTargetOptions(.{});
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
            .{ .name = "tonc_arm", .module = tonc_arm_mod },
        },
    });

    var elfs: std.ArrayList(*Compile) = .empty;
    defer elfs.deinit(b.allocator);
    const elf_imports: [2]std.Build.Module.Import = .{
        .{ .name = "tonc", .module = tonc_mod },
        .{ .name = "gba", .module = gba_mod },
    };

    const tonc_examples: [6]struct { name: []const u8, root_source_file: std.Build.LazyPath } = .{
        .{ .name = "second",    .root_source_file = b.path("tonc/second/main.zig") },
        .{ .name = "m3_demo",   .root_source_file = b.path("tonc/m3_demo/main.zig") },
        .{ .name = "bm_modes",  .root_source_file = b.path("tonc/bm_modes/main.zig") },
        .{ .name = "key_demo",  .root_source_file = b.path("tonc/key_demo/main.zig") },
        .{ .name = "brin_demo", .root_source_file = b.path("tonc/brin_demo/main.zig") },
        .{ .name = "obj_demo",  .root_source_file = b.path("tonc/obj_demo/main.zig") },
    };

    for (tonc_examples) |example| {
        try elfs.append(b.allocator, b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = example.root_source_file,
                .target        = target_thumb,
                .optimize      = optimize,
                .imports       = &elf_imports,
                .strip         = true,
                .error_tracing = false,
                .unwind_tables = .none,
            })
        }));
    }

    // maybe not necessary?
    const fixer_tool = b.addExecutable(.{
        .name = "gbafix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gbafix.zig"),
            .target = target_native,
            .optimize = .ReleaseSafe,
        }),
    });

    b.installArtifact(fixer_tool);

    for (elfs.items) |e| {
        e.setLinkerScript(b.path("gba.ld"));

        const bin = e.addObjCopy(.{ .format = .bin });
        const run_fixer = b.addRunArtifact(fixer_tool);
        run_fixer.addFileArg(bin.getOutput());
        run_fixer.step.dependOn(&bin.step);

        const install_rom = b.addInstallFile(bin.getOutput(), b.fmt("{s}.gba", .{e.name}));
        install_rom.step.dependOn(&run_fixer.step);

        b.getInstallStep().dependOn(&install_rom.step);

        std.debug.print("installed {s}\n", .{e.name});
    }
}
