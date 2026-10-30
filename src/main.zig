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
    _ = c.init_pair(@as(c_short, 1), c.COLOR_BLACK, c.COLOR_WHITE);
    _ = c.init_pair(@as(c_short, 2), c.COLOR_WHITE, c.COLOR_BLACK);

    _ = c.noecho();
    _ = c.curs_set(0);
    _ = c.cbreak();
    _ = c.nodelay(stdscr, true);


    const width: usize = @intCast(@divFloor(c.getmaxx(stdscr), 2));
    const height: usize = @intCast(c.getmaxy(stdscr));
    const area = width * height;

    var board: std.bit_set.Dynamic = try .initEmpty(arena, area);
    var next_board: std.bit_set.Dynamic = try .initEmpty(arena, area);
    for (0..area) |i| {
        board.setValue(i, rand.boolean());
    }

    while (true) {
        if (c.getch() == 'q') break;
        _ = c.flushinp();

        generateBoard(&board, &next_board, width, height);
        std.mem.swap(std.bit_set.Dynamic, &board, &next_board);

        for (0..height) |y| {
            for (0..width) |x| {
                const i = y * width + x;
                const is_alive = board.isSet(i);

                const color_pair = if (is_alive) @as(c_int, 1) else @as(c_int, 2);
                _ = c.attrset(c.COLOR_PAIR(color_pair));
                _ = c.mvprintw(@intCast(y), @intCast(x * 2), "  ");
            }
        }
        _ = c.refresh();
        try std.Io.sleep(init.io, .fromMilliseconds(20), .awake);
    }

    _ = c.endwin();
    std.debug.print("Seed: {}\n", .{seed});
}

fn generateBoard(current: *const std.bit_set.Dynamic, next: *std.bit_set.Dynamic, width: usize, height: usize) void {
    next.unsetAll();

    for (0..height) |y| {
        const y_up = if (y == 0) (height - 1) * width else (y - 1) * width;
        const y_curr = y * width;
        const y_down = if (y == height - 1) 0 else (y + 1) * width;

        for (0..width) |x| {
            const x_left = if (x == 0) width - 1 else x - 1;
            const x_right = if (x == width - 1) 0 else x + 1;

            var alive_neighbors: u4 = 0;
            const neighbors = [8]usize{
                y_up + x_left,   y_up + x,   y_up + x_right,
                y_curr + x_left,             y_curr + x_right,
                y_down + x_left, y_down + x, y_down + x_right,
            };

            inline for (neighbors) |idx| {
                if (current.isSet(idx)) alive_neighbors += 1;
            }

            const i = y_curr + x;
            const is_alive = current.isSet(i);

            if ((is_alive and (alive_neighbors == 2 or alive_neighbors == 3)) or (!is_alive and alive_neighbors == 3)) {
                next.set(i);
            }
        }
    }
}
