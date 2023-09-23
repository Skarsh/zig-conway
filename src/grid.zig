const std = @import("std");
const WIDTH = 10;
const HEIGHT = 10;

const Cell = enum { dead, alive };

pub const Grid = struct {
    pub const Self = @This();
    cells: [WIDTH * HEIGHT]Cell,
    generation: u32,

    pub fn init() Self {
        return Self{ .cells = undefined, .generation = 0 };
    }

    pub fn tick() void {}

    pub fn print(self: *Self) void {
        std.debug.print("Gen: {}\n, {any}\n", .{ self.generation, self.cells });
    }
};
