const std = @import("std");
const rlz = @import("raylib-zig");

const emc_output_dir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;

const programs = [_]struct {
    name: []const u8,
}{
    .{ .name = "helloworld" },
    .{ .name = "maze2d" },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.query.os_tag == .emscripten and optimize == .Debug) {
        std.debug.print("Emscripten builds can run into 'index out of bounds' in Debug mode. Please use Release mode instead.\n", .{});
    }

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    var last_move_step: ?*std.Build.Step = null;

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
            link_step.addArg("--embed-file");
            link_step.addArg("resources/");
            // Required on NixOS
            // See: https://github.com/NixOS/nixpkgs/issues/323598
            link_step.addArg("-s");
            link_step.addArg("MINIFY_HTML=0");
            // We replace the default shell file with a minimal one that doesn't the full emscripten console.
            link_step.addArg("--shell-file");
            link_step.addArg("scripts/minimal_shell.html");

            if (last_move_step) |*prev_step| {
                link_step.step.dependOn(prev_step.*);
            }
            b.getInstallStep().dependOn(&link_step.step);

            // Unfortunately, rlz.emcc hardcodes the output directory which doesn't work with our weird multi-program setup.
            // After the build, we move the output to the correct location.
            const move_step = b.addInstallDirectory(.{
                .source_dir = b.path(emc_output_dir),
                .install_dir = .prefix,
                .install_subdir = try std.fs.path.join(b.allocator, &.{ "public", program.name }),
            });
            last_move_step = &move_step.step;
            move_step.step.dependOn(&link_step.step);
            b.getInstallStep().dependOn(&move_step.step);

            const run_step = try rlz.emcc.emscriptenRunStep(b);
            run_step.step.dependOn(&link_step.step);

            const run_option = b.step(run_cmd_name, run_desc);
            run_option.dependOn(&run_step.step);
        } else {
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

    if (target.query.os_tag == .emscripten) {
        try installGithubPagesIndexHtml(b);

        // After the last "last move step", we can also remove the temporary emc_output_dir.
        if (last_move_step) |*prev_step| {
            const rm_emc_out = b.addRemoveDirTree(emc_output_dir);
            rm_emc_out.step.dependOn(prev_step.*);
            b.getInstallStep().dependOn(&rm_emc_out.step);
        }
    }
}

// This is kinda horrible but it works for now.
fn installGithubPagesIndexHtml(b: *std.Build) !void {
    var index_html = std.ArrayList(u8).init(b.allocator);
    defer index_html.deinit();

    try index_html.appendSlice("<!DOCTYPE html>\n");
    try index_html.appendSlice("<html>\n");
    try index_html.appendSlice("<head>\n");
    try index_html.appendSlice("<title>zig-raylib-wasm-experiments</title>\n");
    try index_html.appendSlice("</head>\n");

    try index_html.appendSlice("<body>\n");
    try index_html.appendSlice("<h1>zig-raylib-wasm-experiments</h1>\n");
    try index_html.appendSlice("<ul>\n");

    for (programs) |program| {
        const program_name = program.name;
        try index_html.appendSlice("<li><a href=\"");
        try index_html.appendSlice(program_name);
        try index_html.appendSlice("/index.html\">");
        try index_html.appendSlice(program_name);
        try index_html.appendSlice("</a></li>\n");
    }

    try index_html.appendSlice("</ul>\n");
    try index_html.appendSlice("</body>\n");
    try index_html.appendSlice("</html>\n");

    const write_file_step = b.addWriteFiles();
    const generated = write_file_step.add("github_pages_index.html", index_html.items);
    const install_file_step = b.addInstallFile(generated, "public" ++ std.fs.path.sep_str ++ "index.html");
    install_file_step.step.dependOn(&write_file_step.step);
    b.getInstallStep().dependOn(&install_file_step.step);
}
