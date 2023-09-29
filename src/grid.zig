const std = @import("std");
const c = @import("c.zig").c;
const DefaultPrng = std.rand.DefaultPrng;

const Pixel = @import("main.zig").Pixel;

pub const Cell = enum { dead, alive };

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const IndexOutOfBoundsError = error{OutOfBounds};

pub const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

pub const Grid = struct {
    pub const Self = @This();
    //width: u32,
    //height: u32,
    //current_cells: []Cell,
    //next_gen_cells: []Cell,
    //pixels: ?[*]Pixel,
    //generation: u32,
    //prng: DefaultPrng,

    width: u32,
    height: u32,
    current_cells: []Cell,
    next_gen_cells: []Cell,
    pixels: ?[*]Pixel,
    generation: u32,
    prng: DefaultPrng,
    rects: [*]c.SDL_Rect,

    pub fn init_with_rects(width: u32, height: u32) !Self {
        var current_cells: []Cell = try allocator.alloc(Cell, width * height);
        var next_gen_cells: []Cell = try allocator.alloc(Cell, width * height);
        var rects: []c.SDL_Rect = try allocator.alloc(c.SDL_Rect, width * height);
        var cells_many_ptr: [*]c.SDL_Rect = @ptrCast(rects);
        _ = cells_many_ptr;

        var prng = DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });

        return Self{
            .width = width,
            .height = height,
            .current_cells = current_cells,
            .next_gen_cells = next_gen_cells,
            .pixels = undefined,
            .generation = 0,
            .prng = prng,
        };
    }

    pub fn init(width: u32, height: u32, pixels: ?[*]Pixel) !Self {
        var current_cells: []Cell = try allocator.alloc(Cell, width * height);
        var next_gen_cells: []Cell = try allocator.alloc(Cell, width * height);
        var prng = DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        return Self{
            .width = width,
            .height = height,
            .current_cells = current_cells,
            .next_gen_cells = next_gen_cells,
            .pixels = pixels,
            .generation = 0,
            .prng = prng,
        };
    }

    pub fn deinit(self: Self) void {
        defer allocator.free(self.current_cells);
        defer allocator.free(self.next_gen_cells);
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
                        if (self.current_cells[idx] == .alive) {
                            count += 1;
                        }
                    }
                }
                col = -1;
            }
        }

        return count;
    }

    fn liveCellsCount(self: Self) u32 {
        var count: u32 = 0;
        for (self.current_cells) |cell| {
            if (cell == .alive) {
                count += 1;
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
        const cells_len: usize = self.current_cells.len;
        _ = cells_len;
        var next_gen_cells_many_ptr: [*]Cell = @ptrCast(self.next_gen_cells);
        clearCellsToDead(next_gen_cells_many_ptr, self.next_gen_cells.len);

        var idx: usize = 0;
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                var live_neighbour_count = try self.liveNeighbourCount(x, y);
                var current_cell = self.current_cells[idx];
                if (current_cell == .alive and live_neighbour_count < 2) {
                    self.next_gen_cells[idx] = .dead;
                } else if (current_cell == .alive and (live_neighbour_count == 2 or live_neighbour_count == 3)) {
                    self.next_gen_cells[idx] = .alive;
                } else if (current_cell == .alive and live_neighbour_count > 3) {
                    self.next_gen_cells[idx] = .dead;
                } else if (self.current_cells[idx] == .dead and live_neighbour_count == 3) {
                    self.next_gen_cells[idx] = .alive;
                }
                idx += 1;
            }
        }

        @memcpy(self.current_cells, self.next_gen_cells);
        self.generation += 1;
    }

    pub fn print(self: *Self) !void {
        var idx: usize = 0;
        for (0..self.height) |y| {
            _ = y;
            for (0..self.width) |x| {
                _ = x;
                const cell = self.current_cells[idx];
                switch (cell) {
                    .alive => {
                        std.debug.print("A ", .{});
                    },
                    .dead => {
                        std.debug.print("D ", .{});
                    },
                }
                idx += 1;
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn draw(self: *Self) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                switch (self.current_cells[y * self.width + x]) {
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

    pub fn clearCellsToDead(cells: [*]Cell, len: usize) void {
        for (0..len) |idx| {
            cells[idx] = .dead;
        }
    }

    pub fn setEveryOtherAlive(cells: [*]Cell, len: usize) void {
        for (0..len) |idx| {
            if (@mod(idx, 2) == 0) {
                cells[idx] = .alive;
            }
        }
    }

    pub fn setCellsRandomlyAlive(prng: *DefaultPrng, cells: [*]Cell, len: usize) void {
        for (0..len) |idx| {
            const rand = prng.random();
            if (@mod(rand.int(u32), 4) == 0) {
                cells[idx] = .alive;
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
    grid.current_cells[3] = .alive;
    grid.current_cells[11] = .alive;
    grid.current_cells[22] = .alive;

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
    grid.current_cells[79] = .alive;
    grid.current_cells[99] = .alive;

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
    grid.current_cells[1] = .alive;
    grid.current_cells[10] = .alive;
    grid.current_cells[11] = .alive;

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
    grid.current_cells[8] = .alive;
    grid.current_cells[19] = .alive;

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
    grid.current_cells[89] = .alive;
    grid.current_cells[98] = .alive;

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
    grid.current_cells[81] = .alive;

    try std.testing.expectEqual(@as(u8, 0), try grid.liveNeighbourCount(0, 9));
}

test "test tick 1" {
    const grid_width: u32 = 4;
    const grid_height: u32 = 4;
    var grid = try Grid.init(grid_width, grid_height, null);
    var new_cells: [*]Cell = @ptrCast(grid.current_cells);
    Grid.clearCellsToDead(new_cells, grid.current_cells.len);

    // Cell to test
    // x = 2, y = 1, .alive
    // A * * *
    // * X * *
    // * * A *
    // * * * *

    grid.current_cells[0] = .alive;
    grid.current_cells[5] = .alive;
    grid.current_cells[10] = .alive;

    try std.testing.expectEqual(@as(u8, 2), try grid.liveNeighbourCount(1, 1));
    var idx = try grid.getIndex(1, 1);

    try std.testing.expectEqual(Cell.alive, grid.current_cells[idx]);

    try grid.tick();

    // Expected outcomefter tick
    // Cell to test
    // x = 2, y = 1, X .alive
    // A * * *
    // * X * *
    // * * A *
    // * * * *

    try std.testing.expectEqual(Cell.alive, grid.current_cells[idx]);
    try std.testing.expectEqual(@as(u32, 1), grid.liveCellsCount());
}

test "test tick 2" {
    const grid_width: u32 = 5;
    const grid_height: u32 = 5;
    var grid = try Grid.init(grid_width, grid_height, null);
    var new_cells: [*]Cell = @ptrCast(grid.current_cells);
    Grid.clearCellsToDead(new_cells, grid.current_cells.len);

    // Cell to test
    // x = 2, y = 2, X is .alive, idx = 12
    // * * * * *
    // * A * A *
    // * * X * *
    // * A * A *
    // * * * * *

    grid.current_cells[6] = .alive;
    grid.current_cells[8] = .alive;
    grid.current_cells[12] = .alive;
    grid.current_cells[16] = .alive;
    grid.current_cells[18] = .alive;

    try std.testing.expectEqual(@as(u8, 4), try grid.liveNeighbourCount(2, 2));
    try std.testing.expectEqual(@as(u32, 5), grid.liveCellsCount());
    var idx = try grid.getIndex(2, 2);

    try std.testing.expectEqual(Cell.alive, grid.current_cells[idx]);
    try grid.tick();

    // Expected outcomefter tick
    // Cell to test
    // x = 2, y = 2, .dead, idx = 12
    // * * * * *
    // * * A * *
    // * A X A *
    // * * A * *
    // * * * * *

    try std.testing.expectEqual(Cell.dead, grid.current_cells[idx]);
    try std.testing.expectEqual(Cell.alive, grid.current_cells[7]);
    try std.testing.expectEqual(Cell.alive, grid.current_cells[11]);
    try std.testing.expectEqual(Cell.alive, grid.current_cells[13]);
    try std.testing.expectEqual(Cell.alive, grid.current_cells[17]);

    try std.testing.expectEqual(@as(u32, 4), grid.liveCellsCount());
}
