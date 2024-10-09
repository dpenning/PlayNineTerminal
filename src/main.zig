const std = @import("std");
const game = @import("game.zig");
const shuffle = std.Random.shuffle;

const player_count = 4;

pub fn main() !void {
    // Random Number Generator.
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    // Allocator.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Game State.
    var game_state = try {
        var draw_pile = try game.GetNewDrawPile(gpa.allocator());
        shuffle(rand, game.CardValue, draw_pile.items);

        var players = try std.ArrayList(game.Player).initCapacity(
            gpa.allocator(),
            player_count,
        );

        // Add the human Player.
        players.insertAssumeCapacity(0, game.Player{
            .board = game.BuildPlayerBoard(&draw_pile),
            .control_type = game.PlayerType.player,
        });

        // Add the cpu Players.
        for (1..players) |i| {
            players.insertAssumeCapacity(i, game.Player{
                .board = game.BuildPlayerBoard(&draw_pile),
                .control_type = game.PlayerType.cpu,
            });
        }

        const current_card = draw_pile.pop();

        const game_state = try game.GameState{
            .rng = prng.random(),
            .draw_pile = draw_pile,
            .current_card = current_card,
            .current_player = 0,
            .players = players,
            .discard = try game.GetNewDeck(),
        };
        return game_state;
    };

    std.debug.print("{}\n", .{game.DealCard(&game_state)});
}
