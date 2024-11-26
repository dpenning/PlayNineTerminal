const std = @import("std");

const card = @import("card.zig");
const Card = card.Card;
const Deck = card.Deck;

const player = @import("player.zig");
const Player = player.Player;
const Players = player.Players;
const PlayerTurn = player.PlayerTurn;

pub const PlayerResult = struct {
    score: i8,
    rank: usize,
    player: *Player,
};

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
    discard_pile: Deck,
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
        std.Random.shuffle(rng, Card, draw_pile.items);

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

        var discard_pile = try getNewDeck(allocator);
        var first_card = draw_pile.pop();
        first_card.flipped = true;
        try discard_pile.append(first_card);

        return Game{
            .rng = rng,
            .draw_pile = draw_pile,
            .discard_pile = discard_pile,
            .current_player = 0,
            .current_player_turn = PlayerTurn.init(),
            .players = players,
            .status = Status.starting,
        };
    }

    pub fn deinit(self: *Self) void {
        defer _ = self.draw_pile.deinit();
        defer _ = self.discard_pile.deinit();
        defer _ = self.players.deinit();
    }

    pub fn dealCard(self: *Self) card.Card {
        if (self.draw_pile.items.len == 0) {
            const tmp = self.draw_pile;
            self.draw_pile = self.discard_pile;
            for (self.draw_pile.items) |*draw_card| {
                draw_card.flipped = false;
            }
            self.discard_pile = tmp;
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
            deck.insertAssumeCapacity(i, Card{ .value = .negative_five, .flipped = false });
        }

        var insertion_index: u8 = 4;
        inline for (@typeInfo(Card.Value).Enum.fields[1..]) |field| {
            for (0..8) |_| {
                deck.insertAssumeCapacity(insertion_index, Card{ .value = @enumFromInt(field.value), .flipped = false });
                insertion_index += 1;
            }
        }

        return deck;
    }

    fn buildPlayerBoard(deck: *Deck) Player.Board {
        return Player.Board{
            [2]Card{ deck.pop(), deck.pop() },
            [2]Card{ deck.pop(), deck.pop() },
            [2]Card{ deck.pop(), deck.pop() },
            [2]Card{ deck.pop(), deck.pop() },
        };
    }

    pub fn moveToNextPlayerTurn(self: *Self) void {
        self.current_player = (self.current_player + 1) % self.players.items.len;
        self.current_player_turn = PlayerTurn.init();
    }

    fn otherResultLowerRank(_: void, first: PlayerResult, second: PlayerResult) bool {
        return second.rank > first.rank;
    }

    pub fn getPlayerResults(self: *const Self, allocator: std.mem.Allocator) !std.ArrayList(PlayerResult) {
        var player_scores = try std.ArrayList(i8).initCapacity(
            allocator,
            self.players.items.len,
        );
        defer player_scores.deinit();

        for (self.players.items) |*p| {
            player_scores.appendAssumeCapacity(try p.getScore());
        }

        var player_results = try std.ArrayList(PlayerResult).initCapacity(
            allocator,
            self.players.items.len,
        );

        for (self.players.items, 0..) |*p, i| {
            const score = player_scores.items[i];

            var rank: usize = 1;
            for (player_scores.items) |other_score| {
                if (other_score < score) {
                    rank += 1;
                }
            }

            player_results.appendAssumeCapacity(.{
                .score = score,
                .rank = rank,
                .player = p,
            });

            std.mem.sort(
                PlayerResult,
                player_results.items,
                {},
                comptime otherResultLowerRank,
            );
        }

        return player_results;
    }
};
