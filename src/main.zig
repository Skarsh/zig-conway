const std = @import("std");
const c = @import("c.zig").c;

const Grid = @import("grid.zig").Grid;

// Constants
const WINDOW_WIDTH = 2560;
const WINDOW_HEIGHT = 1440;

pub const CELL_WIDTH: u32 = 10;
pub const CELL_HEIGHT: u32 = 10;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn gameLoopRects(grid: *Grid) !void {
    var run_simulation = false;
    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_MOUSEBUTTONDOWN => {
                    var cell_width_cint: c_int = @intCast(CELL_WIDTH);
                    var cell_height_cint: c_int = @intCast(CELL_WIDTH);
                    grid.handleMouseEvent(sdl_event.button, cell_width_cint, cell_height_cint);
                },
                c.SDL_KEYDOWN => {
                    switch (sdl_event.key.keysym.scancode) {
                        c.SDL_SCANCODE_SPACE => {
                            run_simulation = true;
                        },
                        c.SDL_SCANCODE_R => {
                            run_simulation = false;
                            grid.reset();
                        },
                        c.SDL_SCANCODE_ESCAPE => break :mainloop,
                        else => {},
                    }
                },
                else => {},
            }
        }
        if (run_simulation) {
            try grid.tick();
            std.time.sleep(10_000_000);
        }
        grid.draw();
    }
}

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow(
        "Conway's Game of Life, in Zig!",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        0,
    );

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_VIDEO_RENDER_OGL);

    _ = c.SDL_SetHint(c.SDL_HINT_RENDER_BATCHING, "1");
    _ = c.SDL_RenderClear(renderer);

    var num_cells_width = WINDOW_WIDTH / CELL_WIDTH;
    var num_cells_height = WINDOW_HEIGHT / CELL_HEIGHT;

    var grid = try Grid.init(num_cells_width, num_cells_height, renderer);
    defer grid.deinit();

    grid.init_rects();
    grid.setCellsRandomlyAlive();

    try gameLoopRects(&grid);
}
