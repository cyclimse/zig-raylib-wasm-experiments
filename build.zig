const std = @import("std");
const rlz = @import("raylib-zig");

const programs = [_]struct {
    name: []const u8,
}{
    .{ .name = "maze2d" },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    for (programs) |program| {
        const path_to_main = try std.mem.concat(b.allocator, u8, &.{ "src/", program.name, "/main.zig" });
        const run_cmd_name = try std.mem.concat(b.allocator, u8, &.{ "run_", program.name });
        const run_desc = try std.mem.concat(b.allocator, u8, &.{ "Run '", program.name, "'" });

        if (target.query.os_tag == .emscripten) {
            const exe_lib = try rlz.emcc.compileForEmscripten(b, program.name, path_to_main, target, optimize);

            exe_lib.linkLibrary(raylib_artifact);
            exe_lib.root_module.addImport("raylib", raylib);

            // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
            const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
            //this lets your program access files like "resources/my-image.png":
            link_step.addArg("--embed-file");
            link_step.addArg("resources/");
            link_step.addArg("-s");
            // Required on NixOS
            // See: https://github.com/NixOS/nixpkgs/issues/323598
            link_step.addArg("MINIFY_HTML=0");
            // We don't even use the provided shell file.
            // Instead, we use a minimal shell file that doesn't have any UI.
            link_step.addArg("--shell-file");
            link_step.addArg("scripts/minimal_shell.html");

            b.getInstallStep().dependOn(&link_step.step);

            // Unfortunately, rlz.emcc hardcodes the output directory which doesn't work with our weird multi-program setup.
            // After the build, we move the output to the correct location.
            const emc_output_dir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
            const wanted_output_dir = try std.mem.concat(b.allocator, u8, &.{
                emc_output_dir,
                program.name,
            });
            // TODO: handle windows?
            var create_dir_step = b.addSystemCommand(&.{
                "mkdir",
                "-p",
                wanted_output_dir,
            });
            create_dir_step.step.dependOn(&link_step.step);
            var move_step = b.addSystemCommand(&.{
                "mv",
                emc_output_dir ++ "index.html",
                emc_output_dir ++ "index.js",
                emc_output_dir ++ "index.wasm",
                wanted_output_dir,
            });
            move_step.step.dependOn(&create_dir_step.step);
            b.getInstallStep().dependOn(&move_step.step);

            const run_step = try rlz.emcc.emscriptenRunStep(b);
            run_step.step.dependOn(&link_step.step);

            const run_option = b.step(run_cmd_name, run_desc);
            run_option.dependOn(&run_step.step);
            return;
        }

        const exe = b.addExecutable(.{
            .name = program.name,
            .root_source_file = b.path(path_to_main),
            .optimize = optimize,
            .target = target,
        });

        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step(run_cmd_name, run_desc);
        run_step.dependOn(&run_cmd.step);

        b.installArtifact(exe);
    }
}
