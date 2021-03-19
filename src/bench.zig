// SPDX-License-Identifier: MIT
// Copyright (c) 2021 Haze Booth
// This file is part of [etch](https://github.com/haze/etch), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

/// This file runs etch code `NUM_RUNS` times and prints an average nanosecond time
const std = @import("std");
const lib = @import("main.zig");
pub const NUM_RUNS = 1_000_000;

pub fn main() !void {
    try bench(
        NUM_RUNS,
        "Hello, { .world }",
        .{ .world = "Benchmark" },
    );
}

fn bench(num_runs: usize, comptime template: []const u8, arguments: anytype) !void {
    // assuming we have all of the memory we need upfront...
    var buf: [1 << 16]u8 = undefined;
    var run_count: usize = 0;

    var buf_head: ?usize = null;

    var sum: u64 = 0;
    var avg: f64 = 0.0;
    while (run_count < num_runs) : (run_count += 1) {
        var timer = try std.time.Timer.start();
        var out = lib.etchBuf(&buf, template, arguments);
        if (buf_head == null)
            buf_head = out.len;
        sum += timer.read();
        avg = @divFloor(@intToFloat(f64, sum), @intToFloat(f64, run_count));
        clearLine();
        std.debug.print("{}/{} ({d:.2}ns avg)", .{ run_count, num_runs, avg });
    }
    clearLine();
    std.log.info("{} runs templating '{s}'=>'{s}' took {d:.2}ns on average", .{ num_runs, template, buf[0..buf_head.?], avg });
}

fn clearLine() void {
    std.debug.print("\r\x1B2k\r", .{});
}
