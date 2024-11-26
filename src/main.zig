const std = @import("std");
const game = @import("game.zig");
const card = @import("card.zig");
const player = @import("player.zig");
const terminal = @import("terminal.zig");

const min_player_count: i8 = 2;
const max_player_count: i8 = 8;
const min_width = 21;
const min_height = 8 * 3;

const bold_esc = "\x1b[1m";
const regular_esc = "\x1b[2m";
const font_reset_esc = "\x1b[22m";

pub fn getPlayerName(
    allocator: std.mem.Allocator,
    games_state: *const game.Game,
    index: usize,
) ![]u8 {
    const fmt = "{s}Player {d} ({s})" ++ font_reset_esc;

    const color_esc = blk: {
        if (games_state.current_player == index) {
            break :blk bold_esc;
        }
        break :blk regular_esc;
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
        .negative_five => return "-5 ",
        .zero => return " 0 ",
        .one => return " 1 ",
        .two => return " 2 ",
        .three => return " 3 ",
        .four => return " 4 ",
        .five => return " 5 ",
        .six => return " 6 ",
        .seven => return " 7 ",
        .eight => return " 8 ",
        .nine => return " 9 ",
        .ten => return "10 ",
        .eleven => return "11 ",
        .twelve => return "12 ",
    }
}

fn getCardStrColored(allocator: std.mem.Allocator, c: *const card.Card, selected: bool) ![]u8 {
    const v_str = getCardStr(c);
    const font_esc = blk: {
        if (selected) {
            break :blk bold_esc;
        }
        break :blk regular_esc;
    };

    return try std.fmt.allocPrint(allocator, "{s}{s}" ++ font_reset_esc, .{
        font_esc,
        v_str,
    });
}

pub fn getCardRow(
    allocator: std.mem.Allocator,
    p: *const player.Player,
    card_row_index: usize,
    selected_index: i8,
) ![]u8 {
    const c1 = try getCardStrColored(
        allocator,
        &p.board[0][card_row_index],
        (0 + 4 * card_row_index) == selected_index,
    );
    defer allocator.free(c1);
    const c2 = try getCardStrColored(
        allocator,
        &p.board[1][card_row_index],
        (1 + 4 * card_row_index) == selected_index,
    );
    defer allocator.free(c2);
    const c3 = try getCardStrColored(
        allocator,
        &p.board[2][card_row_index],
        (2 + 4 * card_row_index) == selected_index,
    );
    defer allocator.free(c3);
    const c4 = try getCardStrColored(
        allocator,
        &p.board[3][card_row_index],
        (3 + 4 * card_row_index) == selected_index,
    );
    defer allocator.free(c4);

    return try std.fmt.allocPrint(
        allocator,
        "│{s}│{s}│{s}│{s}│",
        .{ c1, c2, c3, c4 },
    );
}

pub fn drawGameState(
    allocator: std.mem.Allocator,
    ts: *terminal.Terminal,
    gs: *const game.Game,
) !void {
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

    var current_col: u8 = 0;
    var current_row: u8 = 1;
    for (gs.players.items, 0..) |*p, index| {
        const is_current_player = gs.current_player == index;
        var selection_index = gs.current_player_turn.selection_index;
        if (!is_current_player) {
            selection_index = -1;
        }

        // draw each of the rows
        // top padding row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_top___);
            try ts.positionCursor(
                allocator,
                current_col + padding_char_size.width + deck_char_size.width,
                current_row,
            );
            try ts.write(padding_right_top___);
            current_row += 1;
            current_col = 0;
        }
        // player name row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_middle);
            current_col += padding_char_size.width;

            const player_name_str = try getPlayerName(allocator, gs, index);
            defer allocator.free(player_name_str);
            try ts.write(player_name_str);

            try ts.positionCursor(
                allocator,
                current_col + deck_char_size.width,
                current_row,
            );

            try ts.write(padding_right_middle);
            current_row += 1;
            current_col = 0;
        }
        // cards top row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_middle);
            current_col += padding_char_size.width;

            try ts.write(deck_top____);
            try ts.positionCursor(
                allocator,
                current_col + deck_char_size.width,
                current_row,
            );
            try ts.write(padding_right_middle);
            current_row += 1;
            current_col = 0;
        }
        // cards first row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_middle);

            const str = try getCardRow(allocator, p, 0, selection_index);
            try ts.write(str);
            defer allocator.free(str);

            try ts.positionCursor(
                allocator,
                current_col + padding_char_size.width + deck_char_size.width,
                current_row,
            );
            try ts.write(padding_right_middle);
            current_row += 1;
            current_col = 0;
        }
        // cards middle row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_middle);
            try ts.write(deck_center_);
            try ts.positionCursor(
                allocator,
                current_col + padding_char_size.width + deck_char_size.width,
                current_row,
            );
            try ts.write(padding_right_middle);
            current_row += 1;
            current_col = 0;
        }
        // cards second row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_middle);

            const str = try getCardRow(allocator, p, 1, selection_index);
            try ts.write(str);
            defer allocator.free(str);

            try ts.positionCursor(
                allocator,
                current_col + padding_char_size.width + deck_char_size.width,
                current_row,
            );
            try ts.write(padding_right_middle);
            current_row += 1;
            current_col = 0;
        }
        // cards bottom row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_middle);
            try ts.write(deck_bottom_);
            try ts.positionCursor(
                allocator,
                current_col + padding_char_size.width + deck_char_size.width,
                current_row,
            );
            try ts.write(padding_right_middle);
            current_row += 1;
            current_col = 0;
        }
        // bottom padding row
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(padding_left_bottom);
            try ts.positionCursor(
                allocator,
                current_col + padding_char_size.width + deck_char_size.width,
                current_row,
            );

            try ts.write(padding_right_bottom);

            // If we are skipping flip, then also render the option with
            // selection bolded.
            if (is_current_player and
                gs.current_player_turn.phase == .flip_card_choice and
                p.hasAlmostCompletedBoard())
            {
                const bold = gs.current_player_turn.selection_index == @intFromEnum(player.TurnSelectionOption.skip_flip);
                try ts.positionCursor(
                    allocator,
                    3,
                    current_row,
                );
                try ts.write(if (bold) (bold_esc ++ "Skip Flip" ++ font_reset_esc) else "Skip Flip");
            } else {
                try ts.positionCursor(
                    allocator,
                    3,
                    current_row,
                );
                try ts.write("          ");
            }

            current_row += 1;
            current_col = 0;
        }
    }

    { // write out draw pile
        // now draw the draw pile and discard pile
        // if the draw pile has been used this turn,
        // display it as... x instead of ?
        // ┌             ┐
        // │  Draw Pile  │
        // │ ┌ ─ ┐ ┌ ─ ┐ │
        // │ │ ? │ │ 1 │ │
        // │ └ ─ ┘ └ ─ ┘ │
        // └             ┘

        const draw_pile_title = " Draw Pile";
        const inner_padding_size = 3;
        const draw_pile_padding_top___ = "┌             ┐";
        const draw_pile_padding_middle = "│             │";
        const draw_pile_padding_bottom = "└             ┘";
        const draw_pile_top_______ = "┌ ─ ┐ ┌ ─ ┐";
        const draw_pile_bottom____ = "└ ─ ┘ └ ─ ┘";
        // const draw_pile_padding_size = 15;

        // Draw top padding row.
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_padding_top___);
            current_row += 1;
            current_col = 0;
        }
        // Draw title row.
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_padding_middle);
            current_col += inner_padding_size;
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_title);
            current_row += 1;
            current_col = 0;
        }
        // Draw card_top_row.
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_padding_middle);
            current_col += inner_padding_size;
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_top_______);
            current_row += 1;
            current_col = 0;
        }
        // Draw card_middle_row.
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_padding_middle);
            current_col += inner_padding_size;
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );

            const draw_pile_esc = blk: {
                if (gs.current_player_turn.selection_index == @intFromEnum(player.TurnSelectionOption.draw_pile)) {
                    break :blk bold_esc;
                }
                break :blk regular_esc;
            };

            const draw_pile_value = blk: {
                if (gs.current_player_turn.card_was_drawn_from_draw) {
                    break :blk " X ";
                }
                break :blk " ? ";
            };

            const c = gs.discard_pile.items[gs.discard_pile.items.len - 1];

            const discard_value_display = try getCardStrColored(
                allocator,
                &c,
                gs.current_player_turn.selection_index == @intFromEnum(
                    player.TurnSelectionOption.discard_pile,
                ),
            );
            defer allocator.free(discard_value_display);

            const str = try std.fmt.allocPrint(
                allocator,
                "│{s}{s}" ++ font_reset_esc ++ "│ │{s}│",
                .{
                    draw_pile_esc,
                    draw_pile_value,
                    discard_value_display,
                },
            );
            defer allocator.free(str);
            try ts.write(str);
            current_row += 1;
            current_col = 0;
        }
        // Draw card_bottom_row.
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_padding_middle);
            current_col += inner_padding_size;
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_bottom____);
            current_row += 1;
            current_col = 0;
        }
        // Draw bottom padding row.
        {
            try ts.positionCursor(
                allocator,
                current_col,
                current_row,
            );
            try ts.write(draw_pile_padding_bottom);
            current_row += 1;
            current_col = 0;
        }
    }

    { // for debug write out current game phase
        // also write out the current game phase
        try ts.positionCursor(
            allocator,
            current_col,
            current_row,
        );
        // clear line.
        try ts.write("                              ");
        try ts.positionCursor(
            allocator,
            current_col,
            current_row,
        );

        const player_name = try getPlayerName(allocator, gs, gs.current_player);
        const str = try std.fmt.allocPrint(
            allocator,
            "{s} is {s}",
            .{
                player_name,
                switch (gs.current_player_turn.phase) {
                    .draw_pile_choice => "Drawing",
                    .replace_card_choice => "Replacing",
                    .flip_card_choice => "Flipping",
                },
            },
        );
        defer allocator.free(str);
        defer allocator.free(player_name);
        try ts.write(str);
    }
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
    errdefer terminal_state.deinit() catch {};
    defer terminal_state.deinit() catch {};

    // Start Game Loop
    app: while (true) {
        // Ask the player if they want to continue playing the game.
        const size = terminal_state.getWinSize();
        const center_col: u8 = @truncate(size.ws_col / 2);
        const center_row: u8 = @truncate(size.ws_row / 2);
        if ((size.ws_col < min_width) or (size.ws_row < min_height)) {
            std.debug.print("terminal too small ({d}, {d})", .{ size.ws_col, size.ws_row });
            break :app;
        }

        var num_players: u8 = 4;
        menu: while (true) {
            try terminal_state.resetScreen();
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
            switch (input) {
                .left => {
                    num_players = blk: {
                        if (num_players <= min_player_count) {
                            break :blk max_player_count;
                        } else {
                            break :blk num_players - 1;
                        }
                    };
                },
                .right => {
                    num_players = blk: {
                        if (num_players >= max_player_count) {
                            break :blk min_player_count;
                        } else {
                            break :blk num_players + 1;
                        }
                    };
                },
                .select, .start => {
                    break :menu;
                },
                .exit => {
                    break :app;
                },
                .up, .down, .cancel, .none => {},
            }
        }

        // Create a game state owned by the top level program.
        var game_state = try game.Game.init(
            num_players,
            gpa.allocator(),
            prng.random(),
        );
        defer game_state.deinit();
        try terminal_state.resetScreen();

        game: while (game_state.status != game.Game.Status.ended) {
            // Get a ref to the current player, and then manipulate that player and the game state.
            var current_player: *player.Player =
                &game_state.players.items[game_state.current_player];

            // if current player has completed their board, the game is now over.
            if (current_player.hasCompletedBoard()) {
                game_state.status = game.Game.Status.ended;
                break :game;
            }

            try drawGameState(gpa.allocator(), &terminal_state, &game_state);

            // make the move for the player.
            const input = try terminal_state.attemptReadForGameInput();
            {
                const si = game_state.current_player_turn.selection_index;
                switch (game_state.current_player_turn.phase) {
                    .draw_pile_choice => {
                        switch (input) {
                            .left, .right, .up, .down => {
                                if (si == @intFromEnum(player.TurnSelectionOption.draw_pile)) {
                                    game_state.current_player_turn.selection_index =
                                        @intFromEnum(player.TurnSelectionOption.discard_pile);
                                } else {
                                    game_state.current_player_turn.selection_index =
                                        @intFromEnum(player.TurnSelectionOption.draw_pile);
                                }
                            },
                            .exit => {
                                try terminal_state.resetScreen();
                                break :game;
                            },
                            .select => {
                                if (si == @intFromEnum(player.TurnSelectionOption.draw_pile)) {
                                    var drawn_card = game_state.dealCard();
                                    drawn_card.flipped = true;
                                    game_state.current_player_turn.card_was_drawn_from_draw = true;
                                    try game_state.discard_pile.append(drawn_card);
                                } else {
                                    game_state.current_player_turn.card_was_drawn_from_draw = false;
                                }
                                game_state.current_player_turn.phase = .replace_card_choice;

                                const board = &game_state.players.items[game_state.current_player].board;
                                var card_choice: u8 = 0;
                                while (card_choice <= 7 and board[card_choice % 4][card_choice / 4].flipped) {
                                    card_choice += 1;
                                }
                                if (card_choice > 7) {
                                    game_state.status = .ending;
                                }
                                game_state.current_player_turn.selection_index = @intCast(card_choice);
                            },
                            .start, .cancel, .none => {},
                        }
                    },
                    .replace_card_choice => {
                        switch (input) {
                            .up => {
                                game_state.current_player_turn.selection_index = switch (si) {
                                    @intFromEnum(player.TurnSelectionOption.discard_pile) => 4,
                                    0...3 => @intFromEnum(player.TurnSelectionOption.discard_pile),
                                    4...7 => si - 4,
                                    else => 0,
                                };
                            },
                            .down => {
                                game_state.current_player_turn.selection_index = switch (si) {
                                    @intFromEnum(player.TurnSelectionOption.discard_pile) => 0,
                                    0...3 => si + 4,
                                    4...7 => @intFromEnum(player.TurnSelectionOption.discard_pile),
                                    else => 0,
                                };
                            },
                            .left => {
                                game_state.current_player_turn.selection_index =
                                    switch (si) {
                                    0, 4 => @intFromEnum(player.TurnSelectionOption.discard_pile),
                                    1...3, 5...7 => si - 1,
                                    else => 3,
                                };
                            },
                            .right => {
                                game_state.current_player_turn.selection_index =
                                    switch (si) {
                                    3, 7 => @intFromEnum(player.TurnSelectionOption.discard_pile),
                                    0...2, 4...6 => si + 1,
                                    else => 0,
                                };
                            },
                            .select => {
                                switch (si) {
                                    0...7 => {
                                        const v: usize = @intCast(si);
                                        const col: usize = v % 4;
                                        const row: usize = @divFloor(v, 4);

                                        var replace_card = current_player.replaceCard(col, row, game_state.discard_pile.pop());
                                        replace_card.flipped = true;
                                        try game_state.discard_pile.append(replace_card);
                                        game_state.moveToNextPlayerTurn();
                                    },
                                    @intFromEnum(player.TurnSelectionOption.discard_pile) => {
                                        if (game_state.current_player_turn.card_was_drawn_from_draw) {
                                            game_state.current_player_turn.phase = .flip_card_choice;
                                            game_state.current_player_turn.selection_index = 0;
                                        }
                                    },
                                    else => {},
                                }
                            },
                            .cancel => {
                                if (!game_state.current_player_turn.card_was_drawn_from_draw) {
                                    game_state.current_player_turn.phase = .draw_pile_choice;
                                }
                            },
                            .exit => {
                                try terminal_state.resetScreen();
                                break :game;
                            },
                            .start, .none => {},
                        }
                    },
                    .flip_card_choice => {
                        const can_skip_flip = current_player.hasAlmostCompletedBoard();
                        const skip_flip_si = @intFromEnum(player.TurnSelectionOption.skip_flip);
                        switch (input) {
                            .left => {
                                game_state.current_player_turn.selection_index = switch (si) {
                                    0 => if (can_skip_flip) skip_flip_si else 3,
                                    4 => if (can_skip_flip) skip_flip_si else 7,
                                    1...3, 5...7 => si - 1,
                                    else => 3,
                                };
                            },
                            .right => {
                                game_state.current_player_turn.selection_index = switch (si) {
                                    3 => if (can_skip_flip) skip_flip_si else 0,
                                    7 => if (can_skip_flip) skip_flip_si else 4,
                                    0...2, 4...6 => si + 1,
                                    else => 3,
                                };
                            },
                            .up => {
                                game_state.current_player_turn.selection_index = switch (si) {
                                    0...3 => if (can_skip_flip) skip_flip_si else si + 4,
                                    4...7 => si - 4,
                                    else => 4,
                                };
                            },
                            .down => {
                                game_state.current_player_turn.selection_index = switch (si) {
                                    0...3 => si + 4,
                                    4...7 => if (can_skip_flip) skip_flip_si else si - 4,
                                    else => 4,
                                };
                            },
                            .select => {
                                switch (si) {
                                    0...7 => {
                                        const v: usize = @intCast(si);
                                        const col: usize = v % 4;
                                        const row: usize = @divFloor(v, 4);

                                        if (!current_player.board[col][row].flipped) {
                                            current_player.flipCard(col, row);
                                            game_state.moveToNextPlayerTurn();
                                        }
                                    },
                                    @intFromEnum(player.TurnSelectionOption.skip_flip) => {
                                        game_state.moveToNextPlayerTurn();
                                    },
                                    else => {},
                                }
                            },
                            .start => {},
                            .cancel => {},
                            .exit => {
                                try terminal_state.resetScreen();
                                break :game;
                            },
                            .none => {},
                        }
                    },
                }
            }

            // if the game is ending, flip over the rest of the cards.
            if (game_state.status == game.Game.Status.ended) {
                current_player.flipAllCards();
            }

            // if current player has completed their board, the game is now ending.
            if (current_player.hasCompletedBoard()) {
                game_state.status = game.Game.Status.ending;
            }
        }

        // Overlay on top of the game a score screen
        score_screen: {
            // "                        "
            // " ┌────────────────────┐ "
            // " │ Winner             │ "
            // " │ Player x : <score> │ " // bolded
            // " │                    │ "
            // " │ Player x : <score> │ "
            // " │ Player x : <score> │ "
            // " │ Player x : <score> │ "
            // " └────────────────────┘ "
            // "                        ";

            const rect_for_score_screen: struct { x: u8, y: u8, width: u8, height: u8 } = .{
                .x = center_col - (3 + @as(u8, @intCast(game_state.players.items.len / 2))),
                .y = center_row - 12,
                .width = 24,
                .height = 6 + @as(u8, @intCast(game_state.players.items.len)),
            };

            // try ts.positionCursor(
            //     allocator,
            //     current_col + deck_char_size.width,
            //     current_row,
            // );
            // try ts.write(padding_right_middle);

            const starting_col: u8 = rect_for_score_screen.x;
            var current_row: u8 = rect_for_score_screen.y;
            const player_results = try game_state.getPlayerResults(gpa.allocator());
            defer player_results.deinit();

            { // "                        "
                try terminal_state.positionCursor(
                    gpa.allocator(),
                    starting_col,
                    current_row,
                );
                try terminal_state.write("                        ");
                current_row += 1;
            }

            { // " ┌────────────────────┐ "
                try terminal_state.positionCursor(
                    gpa.allocator(),
                    starting_col,
                    current_row,
                );
                try terminal_state.write(" ┌────────────────────┐ ");
                current_row += 1;
            }
            { // " │ Winner             │ "
                try terminal_state.positionCursor(
                    gpa.allocator(),
                    starting_col,
                    current_row,
                );
                try terminal_state.write(" │ Winner             │ ");
                current_row += 1;
            }
            { // " │                    │ "
                try terminal_state.positionCursor(
                    gpa.allocator(),
                    starting_col,
                    current_row,
                );
                try terminal_state.write(" │                    │ ");
                current_row += 1;
            }
            { // " │ Player x : <score> │ "
                for (player_results.items) |*player_result| {
                    const allocator = gpa.allocator();

                    var player_index: usize = 0;
                    for (game_state.players.items, 0..) |*p, i| {
                        if (p == player_result.player) {
                            player_index = i;
                            break;
                        }
                    }

                    const player_name = try getPlayerName(
                        allocator,
                        &game_state,
                        player_index,
                    );
                    defer allocator.free(player_name);

                    const str = try std.fmt.allocPrint(
                        allocator,
                        " │ {d}. {s} : {d} │ ",
                        .{
                            player_result.rank,
                            player_name,
                            player_result.score,
                        },
                    );
                    defer allocator.free(str);

                    try terminal_state.positionCursor(
                        gpa.allocator(),
                        starting_col,
                        current_row,
                    );
                    try terminal_state.write(str);
                    current_row += 1;
                }
            }
            { // " └────────────────────┘ "
                try terminal_state.positionCursor(
                    gpa.allocator(),
                    starting_col,
                    current_row,
                );
                try terminal_state.write(" └────────────────────┘ ");
                current_row += 1;
            }
            { // "                        ";
                try terminal_state.positionCursor(
                    gpa.allocator(),
                    starting_col,
                    current_row,
                );
                try terminal_state.write("                        ");
                current_row += 1;
            }

            while (true) {
                const input = try terminal_state.attemptReadForGameInput();
                switch (input) {
                    .select, .start, .cancel, .exit => {
                        break :score_screen;
                    },
                    .left, .right, .up, .down, .none => {},
                }
            }
        }
    }
}
