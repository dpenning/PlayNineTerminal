const std = @import("std");

pub const CardValue = enum(i8) {
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

pub const Card = struct {
    value: CardValue,
    flipped: bool,
};
pub const Deck = std.ArrayList(CardValue);

pub const PlayerType = enum {
    local,
    cpu,
};
pub const Player = struct {
    control_type: PlayerType,
    board: [4][2]Card,
};

pub const Players = std.ArrayList(Player);

pub const GameState = struct {
    rng: std.Random,
    draw_pile: Deck,
    current_card: CardValue,
    discard: Deck,
    players: Players,
    current_player: u8,
};

pub fn BuildPlayerBoard(deck: *Deck) Player.board {
    return Player.board{
        [2]Card{ deck.pop(), deck.pop() },
        [2]Card{ deck.pop(), deck.pop() },
        [2]Card{ deck.pop(), deck.pop() },
        [2]Card{ deck.pop(), deck.pop() },
    };
}

pub fn GetNewDeck(allocator: std.mem.Allocator) !Deck {
    const card_count = (@typeInfo(CardValue).Enum.fields.len - 1) * 8 + 4;
    return try Deck.initCapacity(
        allocator,
        card_count,
    );
}

pub fn GetNewDrawPile(allocator: std.mem.Allocator) !Deck {
    var deck = try GetNewDeck(allocator);
    for (0..4) |i| {
        deck.insertAssumeCapacity(i, CardValue.negative_five);
    }

    var insertion_index: u8 = 4;
    inline for (@typeInfo(CardValue).Enum.fields[1..]) |field| {
        for (0..8) |_| {
            deck.insertAssumeCapacity(
                insertion_index,
                @enumFromInt(field.value),
            );
            insertion_index += 1;
        }
    }

    return deck;
}

pub fn DealCard(state: *GameState) CardValue {
    if (state.deck.items.len() == 0) {
        const tmp = state.deck;
        state.deck = state.discard;
        state.discard = tmp;
    }

    return state.deck.pop();
}
