const std = @import("std");
const os = std.posix;

pub const Terminal = struct {
    tty: std.fs.File,
    original_termios: os.termios,
    raw_termios: os.termios,

    pub fn init() !@This() {
        const tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });

        const original_termios = try os.tcgetattr(tty.handle);

        var raw_termios = original_termios;
        raw_termios.lflag.ECHO = false;
        raw_termios.lflag.ICANON = false;
        raw_termios.lflag.ISIG = false;
        raw_termios.lflag.IEXTEN = false;

        raw_termios.iflag.IXON = false;
        raw_termios.iflag.ICRNL = false;
        raw_termios.iflag.BRKINT = false;
        raw_termios.iflag.INPCK = false;
        raw_termios.iflag.ISTRIP = false;

        raw_termios.cc[@intFromEnum(std.c.V.TIME)] = 1;
        raw_termios.cc[@intFromEnum(std.c.V.MIN)] = 1;
        _ = try os.tcsetattr(tty.handle, .FLUSH, raw_termios);

        return @This(){
            .tty = tty,
            .original_termios = original_termios,
            .raw_termios = raw_termios,
        };
    }

    pub fn deinit(self: *@This()) !void {
        _ = try self.resetScreen();

        // Make the cursor visible again.
        _ = try std.posix.write(self.tty.handle, "\x1b[?25h");

        _ = try os.tcsetattr(self.tty.handle, .FLUSH, self.original_termios);

        self.tty.close();
    }

    pub fn resetScreen(self: *@This()) !void {
        // Clear screen.
        _ = try std.posix.write(self.tty.handle, "\x1b[2J");

        // Reset the cursor to home.
        _ = try std.posix.write(self.tty.handle, "\x1b[H");

        // Make the cursor invisible again.
        _ = try std.posix.write(self.tty.handle, "\x1b[?25l");
    }

    pub const GameInput = enum {
        none,
        left,
        right,
        up,
        down,
        select,
        start,
        cancel,
        exit,
    };

    // read inputs from the terminal.
    pub fn attemptReadForGameInput(self: *@This()) !GameInput {
        var buffer: [1]u8 = undefined;

        _ = try self.tty.read(&buffer);

        if (buffer[0] == '\x1B') {
            var tmp_termios = self.raw_termios;
            tmp_termios.cc[@intFromEnum(os.system.V.TIME)] = 1;
            tmp_termios.cc[@intFromEnum(os.system.V.MIN)] = 0;
            try os.tcsetattr(self.tty.handle, .NOW, tmp_termios);

            var esc_buffer: [8]u8 = undefined;
            const esc_read = try self.tty.read(&esc_buffer);

            try os.tcsetattr(self.tty.handle, .NOW, self.raw_termios);

            if (esc_read == 0) {
                return GameInput.exit;
            } else if (std.mem.eql(u8, esc_buffer[0..esc_read], "[A")) {
                return GameInput.up;
            } else if (std.mem.eql(u8, esc_buffer[0..esc_read], "[B")) {
                return GameInput.down;
            } else if (std.mem.eql(u8, esc_buffer[0..esc_read], "[C")) {
                return GameInput.right;
            } else if (std.mem.eql(u8, esc_buffer[0..esc_read], "[D")) {
                return GameInput.left;
            } else {
                // std.debug.print("input: unknown escape sequence {any}\r\n", .{esc_buffer});
                return GameInput.none;
            }
        } else if (buffer[0] == '\n' or buffer[0] == '\r') {
            return GameInput.start;
        } else if (buffer[0] == ' ') {
            return GameInput.select;
        } else if (buffer[0] == 'w') {
            return GameInput.up;
        } else if (buffer[0] == 'a') {
            return GameInput.left;
        } else if (buffer[0] == 's') {
            return GameInput.down;
        } else if (buffer[0] == 'd') {
            return GameInput.right;
        } else {
            // std.debug.print("input: {} {s}\r\n", .{ buffer[0], buffer });
            return .none;
        }

        unreachable;
    }

    pub fn getWinSize(self: *@This()) os.winsize {
        var w: os.winsize = undefined;
        _ = os.system.ioctl(self.tty.handle, os.system.T.IOCGWINSZ, &w);
        return w;
    }

    // https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
    pub fn positionCursor(self: *@This(), allocator: std.mem.Allocator, col: u8, row: u8) !void {
        const str = try std.fmt.allocPrint(
            allocator,
            "\x1b[{d};{d}H",
            .{ row, col },
        );
        defer allocator.free(str);
        try self.write(str);
    }

    pub fn write(self: *@This(), bytes: []const u8) !void {
        _ = try std.posix.write(self.tty.handle, bytes);
    }
};
