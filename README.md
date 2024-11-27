# Dependencies

- Zig: zig is the language/compiler/and build system for this project
    - Install with `brew install zig`
    - https://ziglang.org/learn/getting-started

- termios: No install required (sorry windows, this isnt included in libc)

# Install

`zig build-exe src/main.zig -O ReleaseFast -femit-bin="playnine"`

# Play

`./playnine`

Thats it, give it a shot. controls are at the start of the game.

The draw pile has the card that is being replaced.