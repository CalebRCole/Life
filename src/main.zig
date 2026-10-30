const std = @import("std");
const c = @import("c");


// Rules:
// 1. Any live cell with fewer than two live neighbors dies, as if by under-population.
// 2. Any live cell with two or three live neighbors lives on to the next generation.
// 3. Any live cell with more than three live neighbors dies, as if by overpopulation.
// 4. Any dead cell with exactly three live neighbors becomes a live cell, as if by reproduction.
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    
    const seed = std.Io.Timestamp.now(init.io, .real).toMicroseconds();
    var prng = std.Random.DefaultPrng.init(@intCast(seed));
    const rand = prng.random();
    
    const stdscr: *c.WINDOW = c.initscr() orelse return error.InitscrFailed;
    _ = if (c.has_colors()) c.start_color();

    // White and black color pairs attributes to represent cells.
    _ = c.init_pair(@as(c_short, 1), c.COLOR_WHITE, c.COLOR_BLACK);
    _ = c.init_pair(@as(c_short, 2), c.COLOR_BLACK, c.COLOR_WHITE);
    
    _ = c.noecho();
    _ = c.curs_set(0);
    _ = c.cbreak();
    _ = c.nodelay(stdscr, true);

    
    const width: usize = @intCast(@divFloor(c.getmaxx(stdscr), 2));
    const height: usize = @intCast(c.getmaxy(stdscr));
    const area = width * height;
    
    var board = try arena.alloc(bool, area);
    var next_board = try arena.alloc(bool, area);
    for (board) |*cell| {
        cell.* = rand.boolean();
    }
    
    while (true) {
        if (c.getch() == 'q') break;
        _ = c.flushinp();
        
        generateBoard(board, next_board, width, height);
        std.mem.swap([]bool, &board, &next_board);

        for (0..area) |i| {
            // Living cells are white, dead are black.
            if (board[i]) {
                _ = c.attrset(c.COLOR_PAIR(@as(c_int, 2)));
            } else {
                _ = c.attrset(c.COLOR_PAIR(@as(c_int, 1)));
            }
            _ = c.mvprintw(@intCast(i / width), @intCast((i % width) * 2), "  ");
        }
        _ = c.refresh();
        try std.Io.sleep(init.io, .fromMilliseconds(20), .awake);
    }

    _ = c.endwin();
    std.debug.print("Seed: {}\n", .{seed});
}

fn generateBoard(current: []bool, next: []bool, width: usize, height: usize) void {
    for (0..height) |y| {
        for (0..width) |x| {
            var alive_neighbors: u4 = 0;

            // Toroidal (wrapping) coordinate math
            const x_left = if (x == 0) width - 1 else x - 1;
            const x_right = if (x == width - 1) 0 else x + 1;
            const y_up = if (y == 0) height - 1 else y - 1;
            const y_down = if (y == height - 1) 0 else y + 1;

            const neighbors = [8]usize{
                y_up * width + x_left,   y_up * width + x,   y_up * width + x_right,
                y * width + x_left,                          y * width + x_right,
                y_down * width + x_left, y_down * width + x, y_down * width + x_right,
            };

            for (neighbors) |idx| {
                if (current[idx]) alive_neighbors += 1;
            }

            const i = y * width + x;
            const is_alive = current[i];

            next[i] = if (is_alive)
                (alive_neighbors == 2 or alive_neighbors == 3)
            else
                (alive_neighbors == 3);
        }
    }
}
