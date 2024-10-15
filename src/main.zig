const std = @import("std");
const game = @import("game.zig");
const card = @import("card.zig");
const player = @import("player.zig");
const terminal = @import("terminal.zig");

const min_player_count: i8 = 2;
const max_player_count: i8 = 8;
const min_width = 21;
const min_height = 8 * 3;

pub fn getPlayerName(
    allocator: std.mem.Allocator,
    games_state: *game.Game,
    index: usize,
) ![]u8 {
    const fmt = "{s}Player {d} ({s})\x1b[22m";
    const bold = "\x1b[1m";
    const regular = "\x1b[2m";

    const color_esc = blk: {
        if (games_state.current_player == index) {
            break :blk bold;
        }
        break :blk regular;
    };

    const ident = blk: {
        if (games_state.players.items[index].control == player.Player.Control.cpu) {
            break :blk "cpu";
        }
        break :blk "local";
    };

    return try std.fmt.allocPrint(
        allocator,
        fmt,
        .{ color_esc, index, ident },
    );
}

fn getCardStr(c: *const card.Card) *const [3:0]u8 {
    if (!c.flipped) {
        return " ? ";
    }

    switch (c.value) {
        .negative_five => {
            return "-5 ";
        },
        .zero => {
            return " 0 ";
        },
        .one => {
            return " 1 ";
        },
        .two => {
            return " 2 ";
        },
        .three => {
            return " 3 ";
        },
        .four => {
            return " 4 ";
        },
        .five => {
            return " 5 ";
        },
        .six => {
            return " 6 ";
        },
        .seven => {
            return " 7 ";
        },
        .eight => {
            return " 8 ";
        },
        .nine => {
            return " 9 ";
        },
        .ten => {
            return "10 ";
        },
        .eleven => {
            return "11 ";
        },
        .twelve => {
            return "12 ";
        },
    }
}

pub fn getCardRow(
    allocator: std.mem.Allocator,
    p: *const player.Player,
    card_row_index: usize,
) ![]u8 {
    return try std.fmt.allocPrint(
        allocator,
        "│{s}│{s}│{s}│{s}│",
        .{
            getCardStr(&p.board[0][card_row_index]),
            getCardStr(&p.board[1][card_row_index]),
            getCardStr(&p.board[2][card_row_index]),
            getCardStr(&p.board[3][card_row_index]),
        },
    );
}

pub fn main() !void {
    // Create an RNG owned by the top level program.
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    // Create an Allocator owned by the top level program.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Prep the terminal to be the right state to show the text version of the game.
    var terminal_state = try terminal.Terminal.init();

    // Start Game Loop
    app: while (true) {
        // Ask the player if they want to continue playing the game.
        try terminal_state.resetScreen();
        const size = terminal_state.getWinSize();
        const center_col: u8 = @truncate(size.ws_col / 2);
        const center_row: u8 = @truncate(size.ws_row / 2);
        if ((size.ws_col < min_width) or (size.ws_row < min_height)) {
            std.debug.print("terminal too small ({d}, {d})", .{ size.ws_col, size.ws_row });
            break :app;
        }

        var num_players: u8 = 4;
        menu: while (true) {
            // Render the screen with the number of players to select first
            try terminal_state.positionCursor(
                gpa.allocator(),
                center_col - (@as(u8, @truncate(("select number of players").len)) / 2),
                center_row,
            );
            try terminal_state.write("select number of players");

            // Write the player count.
            var player_count = min_player_count;
            const allocator: std.mem.Allocator = gpa.allocator();
            try terminal_state.positionCursor(
                gpa.allocator(),
                center_col - (@as(u8, @truncate(("2  3  4  5  6  7  8").len)) / 2) - 1,
                center_row + 1,
            );
            while (player_count <= max_player_count) {
                var str: []u8 = undefined;
                if (num_players == player_count) {
                    str = try std.fmt.allocPrint(
                        allocator,
                        "\x1b[1m {d} \x1b[22m",
                        .{player_count},
                    );
                } else {
                    str = try std.fmt.allocPrint(
                        allocator,
                        "\x1b[2m {d} \x1b[22m",
                        .{player_count},
                    );
                }
                defer allocator.free(str);

                try terminal_state.write(str);

                player_count += 1;
            }

            // make the move for the player.
            const input = try terminal_state.attemptReadForGameInput();
            const GI = terminal.Terminal.GameInput;
            switch (input) {
                GI.left => {
                    num_players = blk: {
                        if (num_players <= min_player_count) {
                            break :blk max_player_count;
                        } else {
                            break :blk num_players - 1;
                        }
                    };
                    try terminal_state.resetScreen();
                },
                GI.right => {
                    num_players = blk: {
                        if (num_players >= max_player_count) {
                            break :blk min_player_count;
                        } else {
                            break :blk num_players + 1;
                        }
                    };
                    try terminal_state.resetScreen();
                },
                GI.start => {
                    break :menu;
                },
                GI.exit => {
                    break :app;
                },
                GI.up, GI.down, GI.select, GI.cancel, GI.none => {},
            }
        }

        // Create a game state owned by the top level program.
        var game_state = try game.Game.init(
            num_players,
            gpa.allocator(),
            prng.random(),
        );
        defer game_state.deinit();

        game: while (game_state.status != game.Game.Status.ended) {
            // Get a ref to the current player, and then manipulate that player and the game state.
            var current_player: *player.Player = &game_state.players.items[game_state.current_player];

            // if current player has completed their board, the game is now over.
            if (current_player.hasCompletedBoard()) {
                game_state.status = game.Game.Status.ended;

                // break out of the while loop to move to the next game loop, deciding whether to exit the program.
                break :game;
            }

            // display the state for the game.
            {
                // show the cpu players above the user in the order they will play
                // player will be on bottom
                // card will look like: {width: 21 height: 8}
                // http://xahlee.info/comp/unicode_drawing_shapes.html
                // ┌                   ┐
                // │ Player x          │
                // │ ┌ ─ ┬ ─ ┬ ─ ┬ ─ ┐ │
                // │ │ 1 │10 │-5 │ 0 │ │
                // │ ├ ─ ┼ ─ ┼ ─ ┼ ─ ┤ │
                // │ │ 1 │-5 │ ? │ ? │ │
                // │ └ ─ ┴ ─ ┴ ─ ┴ ─ ┘ │
                // └                   ┘

                const deck_top____ = "┌ ─ ┬ ─ ┬ ─ ┬ ─ ┐";
                // const deck_num_row = "│{s}│{s}│{s}│{s}│";
                const deck_center_ = "├ ─ ┼ ─ ┼ ─ ┼ ─ ┤";
                const deck_bottom_ = "└ ─ ┴ ─ ┴ ─ ┴ ─ ┘";
                const padding_left_top___ = "┌ ";
                const padding_left_middle = "│ ";
                const padding_left_bottom = "└ ";
                const padding_right_top___ = " ┐";
                const padding_right_middle = " │";
                const padding_right_bottom = " ┘";

                const padding_char_size = .{ .width = 2, .height = 1 };
                const deck_char_size = .{ .width = 18, .height = 5 };

                try terminal_state.resetScreen();

                var current_col: u8 = 0;
                var current_row: u8 = 1;
                for (game_state.players.items, 0..) |p, index| {
                    // draw each of the rows
                    // top padding row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_top___);
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + padding_char_size.width + deck_char_size.width,
                            current_row,
                        );
                        try terminal_state.write(padding_right_top___);
                        current_row += 1;
                        current_col = 0;
                    }
                    // player name row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_middle);
                        current_col += padding_char_size.width;

                        const player_name_str = try getPlayerName(gpa.allocator(), &game_state, index);
                        defer gpa.allocator().free(player_name_str);
                        try terminal_state.write(player_name_str);

                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + deck_char_size.width,
                            current_row,
                        );

                        try terminal_state.write(padding_right_middle);
                        current_row += 1;
                        current_col = 0;
                    }
                    // cards top row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_middle);
                        current_col += padding_char_size.width;

                        try terminal_state.write(deck_top____);
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + deck_char_size.width,
                            current_row,
                        );
                        try terminal_state.write(padding_right_middle);
                        current_row += 1;
                        current_col = 0;
                    }
                    // cards first row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_middle);

                        const str = try getCardRow(gpa.allocator(), &p, 0);
                        try terminal_state.write(str);
                        defer gpa.allocator().free(str);

                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + padding_char_size.width + deck_char_size.width,
                            current_row,
                        );
                        try terminal_state.write(padding_right_middle);
                        current_row += 1;
                        current_col = 0;
                    }
                    // cards middle row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_middle);
                        try terminal_state.write(deck_center_);
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + padding_char_size.width + deck_char_size.width,
                            current_row,
                        );
                        try terminal_state.write(padding_right_middle);
                        current_row += 1;
                        current_col = 0;
                    }
                    // cards second row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_middle);

                        const str = try getCardRow(gpa.allocator(), &p, 1);
                        try terminal_state.write(str);
                        defer gpa.allocator().free(str);

                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + padding_char_size.width + deck_char_size.width,
                            current_row,
                        );
                        try terminal_state.write(padding_right_middle);
                        current_row += 1;
                        current_col = 0;
                    }
                    // cards bottom row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_middle);
                        try terminal_state.write(deck_bottom_);
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + padding_char_size.width + deck_char_size.width,
                            current_row,
                        );
                        try terminal_state.write(padding_right_middle);
                        current_row += 1;
                        current_col = 0;
                    }
                    // bottom padding row
                    {
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col,
                            current_row,
                        );
                        try terminal_state.write(padding_left_bottom);
                        try terminal_state.positionCursor(
                            gpa.allocator(),
                            current_col + padding_char_size.width + deck_char_size.width,
                            current_row,
                        );

                        try terminal_state.write(padding_right_bottom);
                        current_row += 1;
                        current_col = 0;
                    }
                }
            }

            // make the move for the player.
            const input = try terminal_state.attemptReadForGameInput();
            {
                const GI = terminal.Terminal.GameInput;
                switch (input) {
                    GI.left => {},
                    GI.right => {},
                    GI.up => {},
                    GI.down => {},
                    GI.select => {},
                    GI.start => {},
                    GI.cancel => {},
                    GI.exit => {
                        break :app;
                    },
                    GI.none => {},
                }
            }

            // if the game is ending, flip over the rest of the cards.
            if (game_state.status == game.Game.Status.ending) {
                current_player.flipAllCards();
            }

            // if current player has completed their board, the game is now ending.
            if (current_player.hasCompletedBoard()) {
                game_state.status = game.Game.Status.ending;
            }
        }
    }

    try terminal_state.deinit();
}
