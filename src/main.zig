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

    // Allocator.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Game State.
    var game_state = try game.GameState.init(
        player_count,
        gpa.allocator(),
        prng.random(),
    );
    defer game_state.deinit();

    // Start Game Loop
}
