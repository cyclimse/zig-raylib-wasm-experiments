const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;

const rl = @import("raylib");
const math = @import("zlm");

pub const SpatialHashMap = struct {
    const Point = struct { x: i32, y: i32 }; // Coordinates in bucket grid
    const Map = std.AutoHashMap(Point, std.ArrayList(*Particle));

    pub const ParticlePair = struct { a: *Particle, b: *Particle };

    allocator: Allocator,

    screen_width: i32,
    screen_height: i32,
    aspect_ratio: f32,
    bucket_count: i32,

    buckets: Map,
    result: std.AutoHashMap(ParticlePair, bool),

    pub fn init(allocator: Allocator, screen_width: i32, screen_height: i32, bucket_count: i32) SpatialHashMap {
        return SpatialHashMap{
            .allocator = allocator,
            .bucket_count = bucket_count,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .aspect_ratio = @as(f32, @floatFromInt(screen_width)) / @as(f32, @floatFromInt(screen_height)),
            .buckets = Map.init(allocator),
            .result = std.AutoHashMap(ParticlePair, bool).init(allocator),
        };
    }

    pub fn deinit(self: *SpatialHashMap) void {
        var iterator = self.buckets.valueIterator();
        while (iterator.next()) |arr| {
            arr.deinit();
        }
        self.buckets.deinit();
        self.result.deinit();
    }

    /// Checks for collisions between particles using the configured bucket size
    /// Note: not sure why we return non-colliding pairs as well
    pub fn getCollisions(self: *SpatialHashMap, particles: *[World.N]Particle) !std.AutoHashMap(ParticlePair, bool).Iterator {
        self.clear();

        for (particles) |*p| {
            // The clamping is there as a safety precaution in case the particle is outside the screen
            const x = std.math.clamp(p.pos.x, -self.aspect_ratio, self.aspect_ratio);
            const y = std.math.clamp(p.pos.y, -1.0, 1.0);

            var xmin = @divFloor(@as(i32, @intFromFloat(@as(f32, @floatFromInt(self.screen_width)) * (x - p.radius))), self.bucket_count);
            const xmax = @divFloor(@as(i32, @intFromFloat(@as(f32, @floatFromInt(self.screen_width)) * (x + p.radius))), self.bucket_count);

            while (xmin <= xmax) : (xmin += 1) {
                var ymin = @divFloor(@as(i32, @intFromFloat(@as(f32, @floatFromInt(self.screen_height)) * (y - p.radius))), self.bucket_count);
                const ymax = @divFloor(@as(i32, @intFromFloat(@as(f32, @floatFromInt(self.screen_height)) * (y + p.radius))), self.bucket_count);

                while (ymin <= ymax) : (ymin += 1) {
                    const vec = Point{ .x = xmin, .y = ymin };

                    if (!self.buckets.contains(vec)) {
                        try self.buckets.put(vec, std.ArrayList(*Particle).init(self.allocator));
                    } else {
                        for (self.buckets.get(vec).?.items) |a| {
                            try self.result.put(ParticlePair{ .a = a, .b = p }, a.isColliding(p.*));
                        }
                    }

                    try (self.buckets.getPtr(vec).?).append(p);
                }
            }
        }

        return self.result.iterator();
    }

    pub fn clear(self: *SpatialHashMap) void {
        // Clear the buckets arrays
        var iterator = self.buckets.valueIterator();
        while (iterator.next()) |arr| {
            arr.clearRetainingCapacity();
        }
        // Clear the result array
        self.result.clearRetainingCapacity();
    }
};

fn mix(a: f32, b: f32, amount: f32) f32 {
    return (1 - amount) * a + amount * b;
}

fn randomFloat(rand: std.rand.Random, min: f32, max: f32) f32 {
    const desired_mean = (min + max) / 2;
    const desired_stddev = (max - min) / 4;
    return std.math.clamp(rand.floatNorm(f32) * desired_stddev + desired_mean, min, max);
}

pub const World = struct {
    const N = 100;
    pub const Stiffness = 0.5;
    const Gravity = -0.2;
    const Iterations = 4;
    const Density = 10;

    screen_width: i32,
    screen_height: i32,
    aspect_ratio: f32,

    particles: [N]Particle,
    rand: std.rand.Random,

    pub fn init(rand: std.rand.Random, screen_width: i32, screen_height: i32) World {
        var world = World{
            .screen_width = screen_width,
            .screen_height = screen_height,
            .aspect_ratio = @as(f32, @floatFromInt(screen_width)) / @as(f32, @floatFromInt(screen_height)),
            .particles = [_]Particle{Particle{}} ** N,
            .rand = rand,
        };
        world.setRandomParticles();

        return world;
    }

    pub fn update(self: *World, spm: *SpatialHashMap, dt: f32) !void {
        // Move the particle that follows the cursor
        var cursor_particle = &self.particles[0];

        const mouse = rl.getMousePosition();
        const target_x = mix(-self.aspect_ratio, self.aspect_ratio, (mouse.x / @as(f32, @floatFromInt(self.screen_width))));
        const target_y = -mix(-1.0, 1.0, (mouse.y / @as(f32, @floatFromInt(self.screen_height))));
        cursor_particle.pos.x = mix(cursor_particle.pos.x, target_x, Stiffness);
        cursor_particle.pos.y = mix(cursor_particle.pos.y, target_y, Stiffness);

        var tmp: math.Vec2 = math.Vec2.zero;

        for (&self.particles) |*p| {
            tmp = p.pos;
            p.pos.x = 2 * p.pos.x - p.pre_pos.x;
            p.pos.y = 2 * p.pos.y - p.pre_pos.y + dt * dt * Gravity;
            p.pre_pos = tmp;
        }

        var k: u32 = 0;

        while (k < Iterations) : (k += 1) {
            var iterator = try spm.getCollisions(&self.particles);

            // Compute collisions
            while (iterator.next()) |item| {
                if (item.value_ptr.*) {
                    const a = item.key_ptr.*.a;
                    const b = item.key_ptr.*.b;
                    Particle.updateOnCollision(a, b);
                }
            }

            // Stay on screen
            for (&self.particles) |*p| {
                const clamped_x = std.math.clamp(p.pos.x, p.radius - self.aspect_ratio, self.aspect_ratio - p.radius);
                const clamped_y = std.math.clamp(p.pos.y, p.radius - 1.0, 1.0 - p.radius);

                if (clamped_x != p.pos.x) {
                    p.pos.x = mix(p.pos.x, clamped_x, Stiffness);
                }
                if (clamped_x != p.pos.y) {
                    p.pos.y = mix(p.pos.y, clamped_y, Stiffness);
                }
            }
        }
    }

    pub fn draw(self: *World) void {
        for (self.particles) |p| {
            rl.drawSphere(
                rl.Vector3{ .x = p.pos.x, .y = p.pos.y, .z = 0.0 },
                p.radius,
                p.color,
            );
        }
    }

    fn setRandomParticles(self: *World) void {
        const base_hue = randomFloat(self.rand, 0.0, 360.0);

        // Set up the particle that will follow the cursor.
        // This is to interact with the particles in the world.
        var cursor_particle = &self.particles[0];
        // This is a "hack" so that the cursor particle can push other particles but not be pushed itself
        cursor_particle.mass = std.math.floatMax(f32);
        cursor_particle.radius = 0.1;
        // We want the cursor particle to be visible so we take the complementary color of the base hue
        const complementary_hue = std.math.mod(f32, base_hue + 180.0, 360.0) catch unreachable;
        cursor_particle.color = rl.colorFromHSV(complementary_hue, 0.8, 0.8);

        for (self.particles[1..self.particles.len]) |*p| {
            const hue = std.math.mod(f32, base_hue + randomFloat(self.rand, -30.0, 30.0), 360.0) catch unreachable;
            const saturation = randomFloat(self.rand, 0.6, 0.9);
            const value = randomFloat(self.rand, 0.6, 0.9);
            p.color = rl.colorFromHSV(hue, saturation, value);

            p.radius = randomFloat(self.rand, 0.02, 0.15);
            p.mass = Density * p.radius * p.radius;

            p.pos.x = randomFloat(self.rand, -self.aspect_ratio + p.radius, self.aspect_ratio - p.radius);
            p.pos.y = randomFloat(self.rand, -1.0 + p.radius, 1.0 - p.radius);
            p.pre_pos = p.pos;
        }
    }
};

const Particle = struct {
    pos: math.Vec2 = math.Vec2.zero,
    pre_pos: math.Vec2 = math.Vec2.zero,

    color: rl.Color = rl.Color.white,
    radius: f32 = 1.0,
    mass: f32 = 1.0,

    pub fn isColliding(a: Particle, b: Particle) bool {
        return (a.pos.x - b.pos.x) * (a.pos.x - b.pos.x) + (a.pos.y - b.pos.y) * (a.pos.y - b.pos.y) <= (a.radius + b.radius) * (a.radius + b.radius);
    }

    pub fn updateOnCollision(a: *Particle, b: *Particle) void {
        var a2b = math.Vec2.new(b.pos.x - a.pos.x, b.pos.y - a.pos.y);
        const a2b_norm = std.math.sqrt(a2b.x * a2b.x + a2b.y * a2b.y);
        a2b.x = (1.0 / a2b_norm) * a2b.x;
        a2b.y = (1.0 / a2b_norm) * a2b.y;
        const overlap = (a.radius + b.radius) - a2b_norm;
        const ab_mass = a.mass + b.mass;
        a.pos.x = a.pos.x - a2b.x * (World.Stiffness * overlap * b.mass / ab_mass);
        a.pos.y = a.pos.y - a2b.y * (World.Stiffness * overlap * b.mass / ab_mass);
        b.pos.x = b.pos.x + a2b.x * (World.Stiffness * overlap * a.mass / ab_mass);
        b.pos.y = b.pos.y + a2b.y * (World.Stiffness * overlap * a.mass / ab_mass);
    }
};
