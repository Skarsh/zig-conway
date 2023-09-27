const std = @import("std");

const c = @cImport({
    @cInclude("SDL.h");
});

const Cell = @import("grid.zig").Cell;
const Grid = @import("grid.zig").Grid;

// Constants
const HEIGHT = 1920;
const WIDTH = 1080;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn gameLoop(grid: *Grid, window: *c.SDL_Window) !void {
    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }

        try grid.tick();
        grid.draw();
        _ = c.SDL_UpdateWindowSurface(window);
    }
}

fn gameLoopSurface() void {}

/// BGRA, since that seems to be the default from SDL2
pub const Pixel = struct { b: u8, g: u8, r: u8, a: u8 };

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("Conway's Game of Life, in Zig!", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, HEIGHT, WIDTH, 0);
    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);

    var surface = c.SDL_GetWindowSurface(window);

    // Pixel format
    //var pixel_format = surface.*.format;
    //std.debug.print("format: {}\n", .{pixel_format.*.format});
    //std.debug.print("bytes per pixel: {}\n", .{pixel_format.*.BytesPerPixel});

    var pixels: ?[*]Pixel = @ptrCast(surface.*.pixels);

    var grid = try Grid.init(WIDTH, HEIGHT, pixels);
    defer grid.deinit();
    var current_gen_cells: [*]Cell = @ptrCast(grid.current_cells);
    var next_gen_cells: [*]Cell = @ptrCast(grid.next_gen_cells);
    Grid.clearCellsToDead(current_gen_cells, grid.current_cells.len);
    Grid.clearCellsToDead(next_gen_cells, grid.next_gen_cells.len);

    // Setting the initial conditions of the simulation
    //Grid.setEveryOtherAlive(new_cells, grid.cells.len);
    Grid.setCellsRandomlyAlive(&grid.prng, current_gen_cells, grid.current_cells.len);

    try gameLoop(&grid, window.?);
}
