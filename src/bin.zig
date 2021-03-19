const lib = @import("main.zig");
const std = @import("std");

pub fn main() !void {
    var buf: [1 << 16]u8 = undefined;
    var timer = try std.time.Timer.start();

    const out = lib.etchBuf(&buf, "Hello, { .person.honorific } { .person.name.first } { .person.name.last }", .{ .person = .{ .honorific = "Dr.", .name = .{ .first = "Haze", .last = "Booth" } } });
    const time = timer.lap();

    std.log.warn("out=\"{s}\" in={}ns", .{
        out,
        time,
    });
}
