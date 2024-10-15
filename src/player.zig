const std = @import("std");
const Card = @import("card.zig").Card;

pub const Player = struct {
    pub const Control = enum {
        local,
        cpu,
    };
    pub const Board = [4][2]Card;

    control: Control,
    board: Board,

    pub fn hasCompletedBoard(self: @This()) bool {
        for (self.board) |col| {
            for (col) |card| {
                if (!card.flipped) {
                    return false;
                }
            }
        }
        return true;
    }

    pub fn flipCard(self: *@This(), col: u8, row: u8) void {
        std.assert(col < self.board.len);
        std.assert(row < self.board[0].len);

        self.board[col][row].flipped = true;
    }

    pub fn flipAllCards(self: *@This()) void {
        for (&self.board) |*col| {
            for (col) |*card| {
                card.flipped = true;
            }
        }
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
        done,
    };

    // Current phase of the turn.
    phase: Phase,

    // a value that represents what the user wants to
    // perform the turn action on.
    // -1 means not selected.
    // 0-7 is the card option.
    // 8 is the draw pile.
    // 9 is the discard pile.
    // 10 is skip flip.
    selection_index: i8,

    // The card that was pulled for  placing in the board.
    drawn_card_value: Card.Value,

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
            .drawn_card_value = undefined,
            .card_was_drawn_from_draw = false,
            .replaced_card_choice = -1,
            .flip_card_choice = -1,
        };
    }
};
