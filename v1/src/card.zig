const std = @import("std");

pub const Card = struct {
    pub const Value = enum(i8) {
        negative_five = -5,
        zero = 0,
        one,
        two,
        three,
        four,
        five,
        six,
        seven,
        eight,
        nine,
        ten,
        eleven,
        twelve,
    };

    value: Value,
    flipped: bool,
};
pub const Deck = std.ArrayList(Card.Value);
