const std = @import("std");
const c = @import("c.zig").c;

const Cell = @import("grid.zig").Cell;
const Grid = @import("grid.zig").Grid;

// Constants
const WINDOW_WIDTH = 1920;
const WINDOW_HEIGHT = 1080;

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

    //var window = c.SDL_CreateWindow(
    //    "Conway's Game of Life, in Zig!",
    //    c.SDL_WINDOWPOS_CENTERED,
    //    c.SDL_WINDOWPOS_CENTERED,
    //    HEIGHT,
    //    WIDTH,
    //    0,
    //);
    //var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);

    //defer c.SDL_DestroyRenderer(renderer);

    //var surface = c.SDL_GetWindowSurface(window);

    //// Pixel format
    ////var pixel_format = surface.*.format;
    ////std.debug.print("format: {}\n", .{pixel_format.*.format});
    ////std.debug.print("bytes per pixel: {}\n", .{pixel_format.*.BytesPerPixel});

    //var pixels: ?[*]Pixel = @ptrCast(surface.*.pixels);

    //var grid = try Grid.init(WIDTH, HEIGHT, pixels);
    //defer grid.deinit();
    //var current_gen_cells: [*]Cell = @ptrCast(grid.current_cells);
    //var next_gen_cells: [*]Cell = @ptrCast(grid.next_gen_cells);
    //Grid.clearCellsToDead(current_gen_cells, grid.current_cells.len);
    //Grid.clearCellsToDead(next_gen_cells, grid.next_gen_cells.len);

    //// Setting the initial conditions of the simulation
    ////Grid.setEveryOtherAlive(new_cells, grid.cells.len);
    //Grid.setCellsRandomlyAlive(&grid.prng, current_gen_cells, grid.current_cells.len);

    //try gameLoop(&grid, window.?);

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

    var cell_width: u32 = 20;
    var cell_height: u32 = 20;
    const cell_width_cint: c_int = @intCast(cell_width);
    const cell_height_cint: c_int = @intCast(cell_width);

    var num_cells_horizontal = WINDOW_WIDTH / cell_width;
    var num_cells_vertical = WINDOW_HEIGHT / cell_height;
    const num_cells_horizontal_cint: c_int = @intCast(num_cells_horizontal);
    const num_cells_vertical_cint: c_int = @intCast(num_cells_vertical);
    _ = num_cells_vertical_cint;
    const num_cells = num_cells_horizontal * num_cells_vertical;

    var cells: []c.SDL_Rect = try allocator.alloc(c.SDL_Rect, num_cells_horizontal * num_cells_vertical);
    var cells_many_ptr: [*]c.SDL_Rect = @ptrCast(cells);
    _ = cells_many_ptr;
    var marked_cells: []bool = try allocator.alloc(bool, num_cells);

    defer allocator.free(cells);
    defer allocator.free(marked_cells);

    // TODO: Add padding between each cell
    var border_size: c_int = 2;
    for (0..num_cells_vertical) |y| {
        for (0..num_cells_horizontal) |x| {
            const y_cint: c_int = @intCast(y);
            const x_cint: c_int = @intCast(x);
            cells[y * num_cells_horizontal + x] = c.SDL_Rect{
                .x = (x_cint * cell_width_cint) + border_size,
                .y = (y_cint * cell_height_cint) + border_size,
                .w = cell_width_cint - (border_size * 2),
                .h = cell_height_cint - (border_size * 2),
            };
        }
    }

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_MOUSEBUTTONDOWN => {
                    switch (sdl_event.button.button) {
                        c.SDL_BUTTON_LEFT => {
                            std.debug.print("button!\n", .{});
                            var x: c_int = 0;
                            var y: c_int = 0;
                            _ = c.SDL_GetMouseState(&x, &y);
                            std.debug.print("x: {}, y: {}\n", .{ x, y });
                            var rect_x = @divFloor(x, cell_width_cint);
                            var rect_y = @divFloor(y, cell_height_cint);
                            std.debug.print("rect_x: {}, rect_y: {}\n", .{ rect_x, rect_y });
                            var cell_idx = (rect_y * num_cells_horizontal_cint) + rect_x;
                            var cell_idx_usize: usize = @intCast(cell_idx);
                            if (marked_cells[cell_idx_usize]) {
                                marked_cells[cell_idx_usize] = false;
                            } else {
                                marked_cells[cell_idx_usize] = true;
                            }
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
        var idx: usize = 0;
        for (cells) |cell| {
            if (marked_cells[idx]) {
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
                _ = c.SDL_RenderFillRect(renderer, &cell);
            } else {
                _ = c.SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);
                _ = c.SDL_RenderDrawRect(renderer, &cell);
            }
            idx += 1;
        }

        // Batching draw calls to rects
        //_ = c.SDL_SetRenderDrawColor(renderer, 100, 100, 100, 255);
        //_ = c.SDL_RenderDrawRects(renderer, cells_many_ptr, num_cells_horizontal_cint * num_cells_vertical_cint);
        //_ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        //_ = c.SDL_RenderFillRects(renderer, cells_many_ptr, num_cells_horizontal_cint * num_cells_vertical_cint);
        //_ = c.SDL_RENDERDrawRe

        //_ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderPresent(renderer);
    }
}
