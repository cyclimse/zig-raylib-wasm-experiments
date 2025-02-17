const std = @import("std");

const math = @import("zlm");
const rl = @import("raylib");

const physics = @import("physics.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const gpa = general_purpose_allocator.allocator();

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    const screen_width = 800;
    const screen_height = 600;
    const aspect_ratio = @as(f32, @floatFromInt(screen_width)) / @as(f32, @floatFromInt(screen_height));

    const bucket_count = 10;

    // As this code is ported over from a "raw" OpenGL project, the coordinates used in the physics engine don't match the screen coordinates.
    // We could change it in the physics engine, but to be honest I find [-1, 1] to be more intuitive compared to raylib's [0, screen_width] and [0, screen_height].
    // To do the conversion, we use a camera with a specific projection matrix.
    const view_mat = rl.Matrix.lookAt(rl.Vector3.init(0, 0, 1), rl.Vector3.init(0, 0, 0), rl.Vector3.init(0, 1, 0));
    const projection_mat = rl.Matrix.perspective(math.toRadians(90.0), aspect_ratio, 0.1, 100);

    var world = physics.World.init(rand, screen_width, screen_height);
    var spatial_hash_map = physics.SpatialHashMap.init(gpa, screen_width, screen_height, bucket_count);
    defer spatial_hash_map.deinit();

    rl.initWindow(screen_width, screen_height, "Ball Pit");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const dt: f64 = 1.0 / 20.0; // 20 FPS physics update

    var current_time: f64 = rl.getTime();
    var accumulator: f64 = 0.0;

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Reference: https://gafferongames.com/post/fix_your_timestep/
        const new_time: f64 = rl.getTime();
        const frame_time = new_time - current_time;
        current_time = new_time;

        accumulator += frame_time;
        while (accumulator >= dt) : (accumulator -= dt) {
            try world.update(&spatial_hash_map, @floatCast(dt));
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        {
            const previous_view = rl.gl.rlGetMatrixModelview();
            const previous_projection = rl.gl.rlGetMatrixProjection();

            rl.gl.rlSetMatrixModelview(view_mat);
            defer rl.gl.rlSetMatrixModelview(previous_view);

            rl.gl.rlSetMatrixProjection(projection_mat);
            defer rl.gl.rlSetMatrixProjection(previous_projection);

            world.draw();
        }

        rl.drawFPS(10, 10);
    }
}
