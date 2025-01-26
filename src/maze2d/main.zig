const std = @import("std");
const builtin = @import("builtin");
pub const os = if (builtin.os.tag != .wasi and builtin.os.tag != .emscripten) std.os else struct {
    pub const heap = struct {
        pub const page_allocator = std.heap.c_allocator;
    };
};

const rl = @import("raylib");
const Allocator = std.mem.Allocator;

const mazelib = @import("maze.zig");
const Maze = mazelib.Maze;

pub fn main() anyerror!void {
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
    const screen_height = 450;
    const cell_size = 10;
    const width = screen_width / cell_size;
    const height = screen_height / cell_size;

    rl.initWindow(screen_width, screen_height, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var maze = try Maze.init(gpa, width, height);
    defer maze.deinit(gpa);
    mazelib.randomize_maze(rand, &maze);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            const start = std.time.milliTimestamp();
            mazelib.randomize_maze(rand, &maze);
            const took = std.time.milliTimestamp() - start;
            std.debug.print("Randomized maze in {}ms\n", .{took});
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        draw_maze(maze, cell_size);

        rl.drawFPS(10, 10);
    }
}

fn draw_maze(maze: Maze, cell_size: i32) void {
    var iter = maze.cell_iterator();

    while (iter.next()) |tuple| {
        const x, const y, const cell = tuple;
        const cell_x = x * cell_size;
        const cell_y = y * cell_size;

        if (cell.has_wall(.North)) {
            rl.drawLine(cell_x, cell_y, cell_x + cell_size, cell_y, rl.Color.black);
        }
        if (cell.has_wall(.South)) {
            rl.drawLine(cell_x, cell_y + cell_size, cell_x + cell_size, cell_y + cell_size, rl.Color.black);
        }
        if (cell.has_wall(.East)) {
            rl.drawLine(cell_x + cell_size, cell_y, cell_x + cell_size, cell_y + cell_size, rl.Color.black);
        }
        if (cell.has_wall(.West)) {
            rl.drawLine(cell_x, cell_y, cell_x, cell_y + cell_size, rl.Color.black);
        }
    }
}
