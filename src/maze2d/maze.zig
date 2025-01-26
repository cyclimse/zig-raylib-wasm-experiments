const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub fn Grid(comptime Cell: type) type {
    const Index = i32;

    return struct {
        const Self = @This();

        width: Index,
        height: Index,
        cells: []Cell,

        pub fn init(allocator: Allocator, width: Index, height: Index) !Self {
            var grid = Self{
                .width = width,
                .height = height,
                .cells = try allocator.alloc(Cell, @intCast(width * height)),
            };
            grid.clear();
            return grid;
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.cells);
        }

        pub fn clear(self: *Self) void {
            for (self.cells) |*cell| {
                cell.* = Cell{};
            }
        }

        pub fn get(self: Self, x: Index, y: Index) Cell {
            return self.cells[@intCast(self.width * y + x)];
        }

        pub fn set(self: *Self, x: Index, y: Index, value: Cell) void {
            self.cells[@intCast(self.width * y + x)] = value;
        }

        pub const CellIterator = struct {
            grid: Self,
            x: Index,
            y: Index,

            pub fn next(self: *CellIterator) ?struct { Index, Index, Cell } {
                const n = self.grid.width * self.y + self.x;
                if (n >= self.grid.width * self.grid.height) {
                    return null;
                }

                const cell = self.grid.get(self.x, self.y);
                const x = self.x;
                const y = self.y;

                self.x += 1;
                if (self.x >= self.grid.width) {
                    self.x = 0;
                    self.y += 1;
                }

                return .{ x, y, cell };
            }
        };

        pub fn cell_iterator(self: Self) CellIterator {
            return .{ .grid = self, .y = 0, .x = 0 };
        }
    };
}

const Direction = enum(u4) {
    North = 1,
    South = 2,
    East = 4,
    West = 8,

    pub fn opposite(direction: Direction) Direction {
        switch (direction) {
            .North => return .South,
            .South => return .North,
            .East => return .West,
            .West => return .East,
        }
    }

    pub fn dx(direction: Direction) i32 {
        switch (direction) {
            .North => return 0,
            .South => return 0,
            .East => return 1,
            .West => return -1,
        }
    }

    pub fn dy(direction: Direction) i32 {
        switch (direction) {
            .North => return -1,
            .South => return 1,
            .East => return 0,
            .West => return 0,
        }
    }
};

pub const AllDirections = [_]Direction{ .North, .South, .East, .West };

pub const MazeCell = struct {
    walls: u4 = 0,

    pub fn visited(self: MazeCell) bool {
        return self.walls != 0;
    }

    pub fn set_wall(self: *MazeCell, direction: Direction) void {
        self.walls |= @intFromEnum(direction);
    }

    pub fn has_wall(self: MazeCell, direction: Direction) bool {
        return (self.walls & @intFromEnum(direction)) != 0;
    }
};

pub const Maze = Grid(MazeCell);

fn random_step(rand: std.rand.Random, maze: *Maze, x: i32, y: i32) ?struct { i32, i32 } {
    var directions = AllDirections;
    rand.shuffle(Direction, &directions);

    for (directions) |dir| {
        const nx = x + dir.dx();
        const ny = y + dir.dy();

        if (nx >= 0 and nx < maze.width and ny >= 0 and ny < maze.height) {
            // Check if the cell has already been visited
            if (maze.get(nx, ny).visited()) {
                continue;
            }

            var cell = maze.get(x, y);
            cell.set_wall(dir);
            maze.set(x, y, cell);
            cell = maze.get(nx, ny);
            cell.set_wall(dir.opposite());
            maze.set(nx, ny, cell);

            return .{ nx, ny };
        }
    }

    return null;
}

// Look for unvisited cells with visited neighbors
fn hunt(rand: std.rand.Random, maze: *Maze) ?struct { i32, i32 } {
    var iter = maze.cell_iterator();

    while (iter.next()) |tuple| {
        const x, const y, const c = tuple;
        if (c.visited()) {
            continue;
        }

        var neighbors = [_]?Direction{null} ** 4;
        var neighbors_count: usize = 0;

        // Set neighbors
        if (x > 0 and maze.get(x - 1, y).visited()) {
            neighbors[neighbors_count] = .West;
            neighbors_count += 1;
        }
        if (x < maze.width - 1 and maze.get(x + 1, y).visited()) {
            neighbors[neighbors_count] = .East;
            neighbors_count += 1;
        }
        if (y > 0 and maze.get(x, y - 1).visited()) {
            neighbors[neighbors_count] = .North;
            neighbors_count += 1;
        }
        if (y < maze.height - 1 and maze.get(x, y + 1).visited()) {
            neighbors[neighbors_count] = .South;
            neighbors_count += 1;
        }
        if (neighbors_count == 0) {
            continue;
        }

        // Shuffle neighbors
        rand.shuffle(?Direction, neighbors[0..neighbors_count]);
        for (neighbors) |opt_dir| {
            const dir = opt_dir orelse continue;
            const nx = x + dir.dx();
            const ny = y + dir.dy();

            var cell = maze.get(x, y);
            cell.set_wall(dir);
            maze.set(x, y, cell);
            cell = maze.get(nx, ny);
            cell.set_wall(dir.opposite());
            maze.set(nx, ny, cell);

            return .{ x, y };
        }

        return null;
    }

    return null;
}

pub fn randomize_maze(rand: std.rand.Random, maze: *Maze) void {
    maze.clear();

    var x = rand.intRangeLessThan(i32, 0, maze.width);
    var y = rand.intRangeLessThan(i32, 0, maze.height);

    while (true) {
        x, y = random_step(rand, maze, x, y) orelse hunt(rand, maze) orelse break;
    }
}
