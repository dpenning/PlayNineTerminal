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

pub const Player = struct {
    pub const Control = enum {
        local,
        cpu,
    };
    pub const Board = [4][2]Card;

    control: Control,
    board: Board,
};
pub const Players = std.ArrayList(Player);

pub const GameState = struct {
    const Self = @This();

    rng: std.Random,
    draw_pile: Deck,
    current_card: Card.Value,
    discard: Deck,
    players: Players,
    current_player: u8,

    pub fn init(
        player_count: u8,
        allocator: std.mem.Allocator,
        rng: std.Random,
    ) !Self {
        var draw_pile = try GetNewDrawPile(allocator);
        std.Random.shuffle(rng, Card.Value, draw_pile.items);

        var players = try std.ArrayList(Player).initCapacity(
            allocator,
            player_count,
        );

        // Add the human Player.
        players.insertAssumeCapacity(0, Player{
            .board = BuildPlayerBoard(&draw_pile),
            .control = Player.Control.local,
        });

        // Add the cpu Players.
        for (1..player_count) |i| {
            players.insertAssumeCapacity(i, Player{
                .board = BuildPlayerBoard(&draw_pile),
                .control = Player.Control.cpu,
            });
        }

        const current_card = draw_pile.pop();

        const discard = try GetNewDeck(allocator);

        return GameState{
            .rng = rng,
            .draw_pile = draw_pile,
            .current_card = current_card,
            .current_player = 0,
            .players = players,
            .discard = discard,
        };
    }

    pub fn deinit(self: Self) void {
        defer _ = self.draw_pile.deinit();
        defer _ = self.discard.deinit();
        defer _ = self.players.deinit();
    }
};

pub fn BuildPlayerBoard(deck: *Deck) Player.Board {
    return Player.Board{
        [2]Card{
            Card{ .value = deck.pop(), .flipped = false },
            Card{ .value = deck.pop(), .flipped = false },
        },
        [2]Card{
            Card{ .value = deck.pop(), .flipped = false },
            Card{ .value = deck.pop(), .flipped = false },
        },
        [2]Card{
            Card{ .value = deck.pop(), .flipped = false },
            Card{ .value = deck.pop(), .flipped = false },
        },
        [2]Card{
            Card{ .value = deck.pop(), .flipped = false },
            Card{ .value = deck.pop(), .flipped = false },
        },
    };
}

pub fn GetNewDeck(allocator: std.mem.Allocator) !Deck {
    const card_count = (@typeInfo(Card.Value).Enum.fields.len - 1) * 8 + 4;
    return try Deck.initCapacity(
        allocator,
        card_count,
    );
}

pub fn GetNewDrawPile(allocator: std.mem.Allocator) !Deck {
    var deck = try GetNewDeck(allocator);
    for (0..4) |i| {
        deck.insertAssumeCapacity(i, Card.Value.negative_five);
    }

    var insertion_index: u8 = 4;
    inline for (@typeInfo(Card.Value).Enum.fields[1..]) |field| {
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

pub fn DealCard(state: *GameState) Card.Value {
    if (state.draw_pile.items.len == 0) {
        const tmp = state.draw_pile;
        state.draw_pile = state.discard;
        state.discard = tmp;
    }

    return state.draw_pile.pop();
}
