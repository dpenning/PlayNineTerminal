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
