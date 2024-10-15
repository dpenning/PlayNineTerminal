const std = @import("std");

const card = @import("card.zig");
const Card = card.Card;
const Deck = card.Deck;

const player = @import("player.zig");
const Player = player.Player;
const Players = player.Players;
const PlayerTurn = player.PlayerTurn;

pub const Game = struct {
    const Self = @This();

    pub const Status = enum {
        starting,
        playing,
        ending, // if any player has flipped their last card.
        ended, // if all players have flipped their last card.
    };

    rng: std.Random,
    draw_pile: Deck,
    current_card: Card.Value,
    discard: Deck,
    players: Players,
    current_player: usize,
    current_player_turn: PlayerTurn,
    status: Status,

    pub fn init(
        player_count: u8,
        allocator: std.mem.Allocator,
        rng: std.Random,
    ) !Self {
        var draw_pile = try getNewDrawPile(allocator);
        std.Random.shuffle(rng, Card.Value, draw_pile.items);

        var players = try std.ArrayList(Player).initCapacity(
            allocator,
            player_count,
        );

        // Add the human Player.
        players.insertAssumeCapacity(0, Player{
            .board = buildPlayerBoard(&draw_pile),
            .control = Player.Control.local,
        });

        // Add the cpu Players.
        for (1..player_count) |i| {
            players.insertAssumeCapacity(i, Player{
                .board = buildPlayerBoard(&draw_pile),
                .control = Player.Control.cpu,
            });
        }

        const current_card = draw_pile.pop();

        const discard = try getNewDeck(allocator);

        return Game{
            .rng = rng,
            .draw_pile = draw_pile,
            .current_card = current_card,
            .current_player = 0,
            .current_player_turn = PlayerTurn.init(),
            .players = players,
            .discard = discard,
            .status = Status.starting,
        };
    }

    pub fn deinit(self: *Self) void {
        defer _ = self.draw_pile.deinit();
        defer _ = self.discard.deinit();
        defer _ = self.players.deinit();
    }

    pub fn dealCard(self: *Self) Card.Value {
        if (self.draw_pile.items.len == 0) {
            const tmp = self.draw_pile;
            self.draw_pile = self.discard;
            self.discard = tmp;
        }

        return self.draw_pile.pop();
    }

    fn getNewDeck(allocator: std.mem.Allocator) !Deck {
        const card_count = (@typeInfo(Card.Value).Enum.fields.len - 1) * 8 + 4;
        return try Deck.initCapacity(
            allocator,
            card_count,
        );
    }

    fn getNewDrawPile(allocator: std.mem.Allocator) !Deck {
        var deck = try getNewDeck(allocator);
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

    fn buildPlayerBoard(deck: *Deck) Player.Board {
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
};
