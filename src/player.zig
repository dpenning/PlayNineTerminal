const std = @import("std");
const Card = @import("card.zig").Card;

pub const Player = struct {
    const Self = @This();
    pub const Control = enum {
        local,
        cpu,
    };
    pub const Board = [4][2]Card;

    control: Control,
    board: Board,

    pub fn numFlippedCards(self: *const Self) u8 {
        var i: u8 = 0;
        for (self.board) |col| {
            for (col) |card| {
                if (card.flipped) {
                    i += 1;
                }
            }
        }
        return i;
    }

    pub fn hasAlmostCompletedBoard(self: *Self) bool {
        return self.numFlippedCards() == 7;
    }

    pub fn hasCompletedBoard(self: *Self) bool {
        return self.numFlippedCards() == 8;
    }

    pub fn replaceCard(self: *Self, col: usize, row: usize, new_card: Card) Card {
        const card = self.board[col][row];
        self.board[col][row] = new_card;
        return card;
    }

    pub fn flipCard(self: *Self, col: usize, row: usize) void {
        self.board[col][row].flipped = true;
    }

    pub fn flipAllCards(self: *Self) void {
        for (&self.board) |*col| {
            for (col) |*card| {
                card.flipped = true;
            }
        }
    }

    pub fn getScore(self: *Self) !i8 {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        var rank_match_count_map = std.AutoHashMap(Card.Value, u8).init(gpa.allocator());
        defer rank_match_count_map.deinit();

        var score: i8 = 0;
        // get the score with non -5 matches removed
        for (&self.board) |*col| {
            if (col[0].value == col[1].value) {
                try rank_match_count_map.put(col[0].value, (rank_match_count_map.get(col[0].value) orelse 0) + 1);
                if (col[0].value == .negative_five) {
                    score -= 10;
                }
            } else {
                score += @intFromEnum(col[0].value) + @intFromEnum(col[1].value);
            }
        }

        var rmc_iter = rank_match_count_map.iterator();
        while (rmc_iter.next()) |entry| {
            const value: *u8 = entry.value_ptr;
            score += switch (value.*) {
                2 => 10,
                3 => 20,
                4 => 40,
                else => 0,
            };
        }

        return score;
    }
};
pub const Players = std.ArrayList(Player);

pub const TurnSelectionOption = enum(i8) {
    draw_pile = -4,
    discard_pile = -3,
    skip_flip = -2,
    none = -1,
    // 0-7 are cards.
};

pub const PlayerTurn = struct {
    const Phase = enum {
        draw_pile_choice,
        replace_card_choice,
        flip_card_choice,
    };

    // Current phase of the turn.
    phase: Phase,

    // refer to TurnSelectionOption for values.
    selection_index: i8,

    // marks whether the card was pulled from discard or not,
    // effects whether the player can revert drawn_card_value.
    card_was_drawn_from_draw: bool,

    // value can be -1 -> 8.
    // -1 represents no choice made yet.
    // where 0-7 is the index of the card that will be replaced.
    // 8 marks that the pulled card was discarded.
    replaced_card_choice: i8,

    // value can be -1 -> 8.
    // -1 represents no choice made yet.
    // where 0-7 is the index of the card that will be replaced.
    // 8 marks that no flip was needed, or flip was denied.
    flip_card_choice: i8,

    pub fn init() @This() {
        return PlayerTurn{
            .phase = .draw_pile_choice,
            .selection_index = @intFromEnum(TurnSelectionOption.draw_pile),
            .card_was_drawn_from_draw = false,
            .replaced_card_choice = -1,
            .flip_card_choice = -1,
        };
    }
};
