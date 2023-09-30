# zig-conway

This is basic project for learning Zig, only implements a basic Game of Life.
The the border of the grid are treated as deadzones, just a simple way to prevent dealing with padding etc.

NOTE: Currently only works on Windows out of the box

## Dependencies 
SDL2 are required, under the deps folder, look at `build.zig` for how the path should be needed.

## Building
`zig build` 

## Play
This is fairly limited and tailormade to what I wanted to do.
When startin up there is a board, where each cell can edited by left clicking.
When pressing SPACE bar th simulation will start. Press R to reset to the init edit phase.
