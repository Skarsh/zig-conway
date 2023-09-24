const std = @import("std");

pub const Cell = enum { dead, alive };

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const IndexOutOfBoundsError = error{OutOfBounds};

pub const Grid = struct {
    pub const Self = @This();
    width: u32,
    height: u32,
    cells: []Cell,
    generation: u32,

    pub fn init(width: u32, height: u32) !Self {
        var cells: []Cell = try allocator.alloc(Cell, width * height);
        return Self{ .width = width, .height = height, .cells = cells, .generation = 0 };
    }

    /// Formula index(row, column) = row * width + column
    fn getIndex(self: Self, row: u32, column: u32) IndexOutOfBoundsError!usize {
        if (row >= 0 and row < self.height and column >= 0 and column < self.width) {
            return row * self.width + column;
        } else {
            return error.OutOfBounds;
        }
    }

    fn checkIndexOutOfBounds(self: Self, idx: usize) IndexOutOfBoundsError!void {
        if (idx < 0 or idx >= self.width * self.height) {
            return error.OutOfBounds;
        }
    }

    /// row idx / width
    /// floor(1 / 10) = 0
    /// floor(9/10) = 0
    /// floor(11 / 10) = 1
    fn getRow(self: Self, idx: usize) IndexOutOfBoundsError!u32 {
        try self.checkIndexOutOfBounds(idx);

        return @intCast(idx / self.width);
    }

    // column = row * width
    fn getColumn(self: Self, idx: usize) IndexOutOfBoundsError!u32 {
        try self.checkIndexOutOfBounds(idx);
    }

    fn liveNeighbourCount(self: Self, row: u32, column: u32) u8 {
        var count: u8 = 0;

        var idx = self.getIndex(row, column);
        _ = idx;

        return count;
    }

    fn liveNeighbourCountByIdx(self: Self, idx: usize) u8 {
        _ = self;
        // First row is special
        if (idx) {}
        // First column is special
        // Last column is special
        // Last row is special
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

        // Update the new cells with the next generation
        for (self.cells, 0..) |cell, idx| {
            std.debug.print("Cell: {}, idx: {}\n", .{ cell, idx });
        }
    }

    pub fn print(self: *Self) void {
        std.debug.print("width: {}\n height: {}\n cells_len: {}, generation: {}", .{ self.width, self.height, self.cells.len, self.generation });
    }
};

test "test getRow" {
    const grid_width: u32 = 10;
    const grid_height: u32 = 10;
    var grid = try Grid.init(grid_width, grid_height);

    try std.testing.expectEqual(@as(u32, 0), try grid.getRow(0));
    try std.testing.expectEqual(@as(u32, 0), try grid.getRow(9));
    try std.testing.expectEqual(@as(u32, 1), try grid.getRow(11));
    try std.testing.expectEqual(@as(u32, 9), try grid.getRow(99));

    // Test OutOfIndexError cases
    try std.testing.expectError(error.OutOfBounds, grid.getRow(100));
}
