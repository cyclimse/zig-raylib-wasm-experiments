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
    const screen_height = 600;
    const cell_size = 20;
    const width = screen_width / cell_size;
    const height = screen_height / cell_size;

    rl.initWindow(screen_width, screen_height, "Maze 2D");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var maze = try Maze.init(gpa, rand, width, height);
    defer maze.deinit(gpa);

    // We will draw the last 10 positions of the player as a trail
    var lastPositions = [_]struct { i32, i32, f32 }{.{ 0, 0, 0.0 }} ** 20;
    lastPositions[0] = .{ maze.x, maze.y, 1.0 };
    var lastPositionsIndex: usize = 1;

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update

        // Decrease the alpha of the last positions
        for (0..lastPositions.len) |i| {
            lastPositions[i][2] = @max(0.0, lastPositions[i][2] - 0.02);
        }

        if (maze.stepOnce(rand)) {
            maze.clear(rand);
        }
        lastPositions[lastPositionsIndex] = .{ maze.x, maze.y, 1.0 };
        lastPositionsIndex = (lastPositionsIndex + 1) % lastPositions.len;

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        drawPositions(&lastPositions, cell_size);
        drawMaze(maze, cell_size);

        rl.drawFPS(10, 10);
    }
}

fn drawPositions(lastPositions: []struct { i32, i32, f32 }, cell_size: i32) void {
    for (lastPositions) |pos| {
        const x, const y, const alpha = pos;
        if (x == 0 and y == 0) {
            continue;
        }

        const cell_x = x * cell_size;
        const cell_y = y * cell_size;
        rl.drawRectangle(cell_x, cell_y, cell_size, cell_size, rl.fade(rl.Color.red, alpha));
    }
}

fn drawMaze(maze: Maze, cell_size: i32) void {
    // Draw the maze
    var iter = maze.grid.cellIterator();

    while (iter.next()) |tuple| {
        const x, const y, const cell = tuple;
        const cell_x = x * cell_size;
        const cell_y = y * cell_size;

        if (cell.visited()) {
            rl.drawRectangle(cell_x, cell_y, cell_size, cell_size, rl.fade(rl.Color.gray, 0.2));
        } else {
            rl.drawRectangle(cell_x, cell_y, cell_size, cell_size, rl.fade(rl.Color.gray, 0.8));
        }

        if (cell.hasWall(.North) or !cell.visited()) {
            rl.drawLine(cell_x, cell_y, cell_x + cell_size, cell_y, rl.Color.black);
        }
        if (cell.hasWall(.South) or !cell.visited()) {
            rl.drawLine(cell_x, cell_y + cell_size, cell_x + cell_size, cell_y + cell_size, rl.Color.black);
        }
        if (cell.hasWall(.East) or !cell.visited()) {
            rl.drawLine(cell_x + cell_size, cell_y, cell_x + cell_size, cell_y + cell_size, rl.Color.black);
        }
        if (cell.hasWall(.West) or !cell.visited()) {
            rl.drawLine(cell_x, cell_y, cell_x, cell_y + cell_size, rl.Color.black);
        }
    }
}
