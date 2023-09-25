const std = @import("std");

const Pixel = @import("main.zig").Pixel;

pub const Cell = enum { dead, alive };

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const IndexOutOfBoundsError = error{OutOfBounds};

pub const Grid = struct {
    pub const Self = @This();
    width: u32,
    height: u32,
    cells: []Cell,
    pixels: ?[*]Pixel,
    generation: u32,

    pub fn init(width: u32, height: u32, pixels: ?[*]Pixel) !Self {
        var cells: []Cell = try allocator.alloc(Cell, width * height);
        return Self{ .width = width, .height = height, .cells = cells, .pixels = pixels, .generation = 0 };
    }

    /// Formula index(x, y) = y * width + x
    fn getIndex(self: Self, x: usize, y: usize) IndexOutOfBoundsError!usize {
        if (y >= 0 and y < self.height and x >= 0 and x < self.width) {
            return y * self.width + x;
        } else {
            return error.OutOfBounds;
        }
    }

    fn checkIndexOutOfBounds(self: Self, idx: usize) IndexOutOfBoundsError!void {
        if (idx < 0 or idx >= self.width * self.height) {
            return error.OutOfBounds;
        }
    }

    fn getX(self: Self, idx: usize) IndexOutOfBoundsError!u32 {
        try self.checkIndexOutOfBounds(idx);

        var idx_u32: u32 = @intCast(idx);
        return @mod(idx_u32, self.width);
    }

    fn getY(self: Self, idx: usize) IndexOutOfBoundsError!u32 {
        try self.checkIndexOutOfBounds(idx);

        return @intCast(idx / self.width);
    }

    /// Assumes that there is a finite board, so there are special
    /// check for the corner and top, right, bottom and left cases.
    fn liveNeighbourCount(self: Self, x: usize, y: usize) IndexOutOfBoundsError!u8 {
        var count: u8 = 0;

        // We skip calculating alive neighbours for the outer border of the board.
        if (y > 0 and y < self.height - 1 and x > 0 and x < self.width - 1) {
            // Every cell has 8 neigbours
            // TODO: This whole thing is pretty dogwater, need to find a better way
            var col: i32 = -1;
            var row: i32 = -1;
            while (row <= 1) : (row += 1) {
                while (col <= 1) : (col += 1) {
                    if (row == 0 and col == 0) {
                        //continue;
                    } else {
                        // TODO: This is sooo soo bad, find a better way
                        var x_i32: i32 = @intCast(x);
                        var y_i32: i32 = @intCast(y);

                        var neighbour_x_idx = x_i32 + col;
                        var neighbour_y_idx = y_i32 + row;

                        var neighbour_x_idx_usize: usize = @intCast(neighbour_x_idx);
                        var neighbour_y_idx_usize: usize = @intCast(neighbour_y_idx);

                        var idx = try self.getIndex(neighbour_x_idx_usize, neighbour_y_idx_usize);
                        if (self.cells[idx] == .alive) {
                            count += 1;
                        }
                    }
                }
                col = -1;
            }
        }

        return count;
    }

    /// The universe of the Game of Life is an infinite two-dimensional orthogonal grid of square cells,
    /// each of which is in one of two possible states, alive or dead, or "populated" or "unpopulated".
    /// Every cell interacts with its eight neighbours, which are the cells that are horizontally, vertically,
    /// or diagonally adjacent. At each step in time, the following transitions occur:
    /// 1. Any live cell with fewer than two live neighbours dies, as if caused by underpopulation.
    /// 2. Any live cell with two or three live neighbours lives on to the next generation.
    /// 3. Any live cell with more than three live neighbours dies, as if by overpopulation.
    /// 4. Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
    pub fn tick(self: *Self) !void {

        // Make copy of the old cells state, this allocates each tick, which is pretty unecessary
        const cells_len: usize = self.cells.len;
        var new_cells: []Cell = try allocator.alloc(Cell, cells_len);
        defer allocator.free(new_cells);
        @memcpy(new_cells, self.cells);

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                var live_neighbour_count = try self.liveNeighbourCount(x, y);
                if (live_neighbour_count < 2) {
                    new_cells[y * self.width + x] = .dead;
                } else if (live_neighbour_count == 2 or live_neighbour_count == 3) {
                    new_cells[y * self.width + x] = .alive;
                } else if (live_neighbour_count > 3) {
                    new_cells[y * self.width + x] = .dead;
                } else if (self.cells[y * self.width + x] == .dead and live_neighbour_count == 3) {
                    new_cells[y * self.width + x] = .alive;
                }
            }
        }

        @memcpy(self.cells, new_cells);
    }

    pub fn print(self: *Self) void {
        std.debug.print("width: {}\n height: {}\n cells_len: {}, generation: {}", .{ self.width, self.height, self.cells.len, self.generation });
    }

    pub fn draw(self: *Self) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                switch (self.cells[y * self.width + x]) {
                    .alive => {
                        self.pixels.?[y * self.width + x].b = 255;
                        self.pixels.?[y * self.width + x].g = 255;
                        self.pixels.?[y * self.width + x].r = 255;
                        self.pixels.?[y * self.width + x].a = 255;
                    },
                    .dead => {
                        self.pixels.?[y * self.width + x].b = 0;
                        self.pixels.?[y * self.width + x].g = 0;
                        self.pixels.?[y * self.width + x].r = 0;
                        self.pixels.?[y * self.width + x].a = 0;
                    },
                }
            }
        }
    }
};

test "test getX" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    try std.testing.expectEqual(@as(u32, 0), try grid.getX(0));
    try std.testing.expectEqual(@as(u32, 3), try grid.getX(3));
    try std.testing.expectEqual(@as(u32, 9), try grid.getX(9));
    try std.testing.expectEqual(@as(u32, 0), try grid.getX(10));
    try std.testing.expectEqual(@as(u32, 3), try grid.getX(13));
    try std.testing.expectEqual(@as(u32, 9), try grid.getX(19));
    try std.testing.expectEqual(@as(u32, 9), try grid.getX(99));

    // Test OutOfIndexError cases
    try std.testing.expectError(error.OutOfBounds, grid.getX(100));
}

test "test getY" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    try std.testing.expectEqual(@as(u32, 0), try grid.getY(0));
    try std.testing.expectEqual(@as(u32, 0), try grid.getY(9));
    try std.testing.expectEqual(@as(u32, 1), try grid.getY(11));
    try std.testing.expectEqual(@as(u32, 9), try grid.getY(99));

    // Test OutOfIndexError cases
    try std.testing.expectError(error.OutOfBounds, grid.getY(100));
}

test "test getIndex" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    // a: row = 1, col = 2, idx = 12
    // b: row = 0, col = 0, idx = 0
    // c: row = 8, col = 4, idx = 84
    // d: row = 9, col = 9, idx = 99

    // b * * * * * * * * *
    // * * a * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * c * * * * *
    // * * * * * * * * * d

    try std.testing.expectEqual(@as(usize, 0), try grid.getIndex(0, 0));
    try std.testing.expectEqual(@as(usize, 12), try grid.getIndex(2, 1));
    try std.testing.expectEqual(@as(usize, 84), try grid.getIndex(4, 8));
    try std.testing.expectEqual(@as(usize, 99), try grid.getIndex(9, 9));

    // Test OutOfIndexError cases
    try std.testing.expectError(error.OutOfBounds, grid.getIndex(10, 0));
}

test "test liveNeighbourCount" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    // x= 2, y = 1
    // * D D A * * * * * *
    // * A x D * * * * * *
    // * D A D * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    grid.cells[3] = .alive;
    grid.cells[11] = .alive;
    grid.cells[22] = .alive;

    try std.testing.expectEqual(@as(u8, 3), try grid.liveNeighbourCount(2, 1));

    // x = 8, y = 8
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * A
    // * * * * * * * * x *
    // * * * * * * * * * A
    grid.cells[79] = .alive;
    grid.cells[99] = .alive;

    try std.testing.expectEqual(@as(u8, 2), try grid.liveNeighbourCount(8, 8));

    // Corner cases, all of these should return zero
    // x = 0, y = 0
    // X * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * A
    // * * * * * * * * x *
    // * * * * * * * * * A

}

test "test liveNeighbourCount upper left corner" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    // x = 0, y = 0
    // X A * * * * * * * *
    // A A * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    grid.cells[1] = .alive;
    grid.cells[10] = .alive;
    grid.cells[11] = .alive;

    try std.testing.expectEqual(@as(u8, 0), try grid.liveNeighbourCount(0, 0));
}

test "test liveNeighbourCount upper right corner" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    // x = 9, y = 0
    // * * * * * * * * A X
    // * * * * * * * * * A
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    grid.cells[8] = .alive;
    grid.cells[19] = .alive;

    try std.testing.expectEqual(@as(u8, 0), try grid.liveNeighbourCount(9, 0));
}

test "test liveNeighbourCount lower right corner" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    // x = 9, y = 9
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * A
    // * * * * * * * * A X
    grid.cells[89] = .alive;
    grid.cells[98] = .alive;

    try std.testing.expectEqual(@as(u8, 0), try grid.liveNeighbourCount(9, 9));
}

test "test liveNeighbourCount lower left corner" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height, null);

    // x = 0, y = 9
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * * * * * * * * * *
    // * A * * * * * * * *
    // x * * * * * * * * *
    grid.cells[81] = .alive;

    try std.testing.expectEqual(@as(u8, 0), try grid.liveNeighbourCount(0, 9));
}
