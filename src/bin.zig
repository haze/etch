const etch = @import("main.zig").etch;
const std = @import("std");

pub fn main() !void {
    var buf: [120000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);

    var allocator = &fba.allocator;

    // var arena = std.heap.ArenaAllocator.init(&fba.allocator);
    // var allocator = &arena.allocator;

    var timer = try std.time.Timer.start();
    const out = try etch(allocator, "Hello, { .person.name.first }{ .person.name.last }", .{ .person = .{ .name = .{ .first = "Haze", .last = "Booth" } } });
    const time = timer.lap();
    defer allocator.free(out);

    std.log.warn("out=\"{s}\" in={}ns", .{
        out,
        time,
    });
}
