// SPDX-License-Identifier: MIT
// Copyright (c) 2021 Haze Booth
// This file is part of [etch](https://github.com/haze/etch), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const testing = std.testing;

const VARIABLE_START_CHAR: u8 = '{';
const VARIABLE_END_CHAR: u8 = '}';
const VARIABLE_PATH_CHAR: u8 = '.';

const EtchTokenScanner = struct {
    const Self = @This();
    const State = enum { TopLevel, BeginReadingVariable, ReadingVariable };

    const Token = union(enum) {
        /// Copy `n` bytes to the output buffer
        RawSequence: usize,
        /// Append the variable to the output buffer
        Variable: struct {
            /// Variable path to trace through the provided arguments struct
            path: []const u8,
            /// Size of the variable definition to skip in the original input string
            size: usize,
        },
        /// Insert the literal char for the variable start sequence
        EscapedVariableToken,
    };

    state: State = .TopLevel,
    head: usize = 0,
    input: []const u8,

    current_variable_begin_idx: ?usize = null,
    current_variable_path_idx: ?usize = null,

    fn cur(self: Self) u8 {
        return self.input[self.head];
    }

    fn isDone(self: Self) bool {
        return self.head >= self.input.len;
    }

    fn next(comptime self: *Self) !?Token {
        while (!self.isDone()) {
            switch (self.state) {
                .ReadingVariable => {
                    while (!self.isDone()) {
                        const cur_char = self.cur();
                        const hit_end_char = cur_char == VARIABLE_END_CHAR;
                        const hit_space = std.ascii.isSpace(cur_char);
                        if (hit_end_char or hit_space) {
                            const var_end_idx = self.head;
                            if (hit_space) {
                                comptime var found_end = false;
                                while (!self.isDone()) {
                                    if (self.cur() == VARIABLE_END_CHAR) {
                                        found_end = true;
                                        break;
                                    }
                                    self.head += 1;
                                }
                                if (!found_end)
                                    return error.UnfinishedVariableDeclaration;
                            }
                            self.state = .TopLevel;
                            self.head += 1;
                            if (self.current_variable_begin_idx) |var_beg_idx| {
                                if (self.current_variable_path_idx) |var_path_beg_idx| {
                                    const token = Token{ .Variable = .{ .path = self.input[var_path_beg_idx..var_end_idx], .size = self.head - var_beg_idx } };
                                    self.current_variable_begin_idx = null;
                                    self.current_variable_path_idx = null;
                                    return token;
                                } else return error.NoVariablePathProvided;
                            } else return error.TemplateVariableEndWithoutBeginning;
                        }
                        self.head += 1;
                    }
                },
                .BeginReadingVariable => {
                    if (self.cur() == VARIABLE_START_CHAR) {
                        self.head += 1;
                        self.state = .TopLevel;
                        return .EscapedVariableToken;
                    } else {
                        while (!self.isDone()) {
                            const cur_char = self.cur();
                            if (cur_char == VARIABLE_END_CHAR)
                                return error.NoVariablePathProvided;
                            if (cur_char == VARIABLE_PATH_CHAR) {
                                self.current_variable_path_idx = self.head;
                                self.state = .ReadingVariable;
                                self.head += 1;
                                break;
                            }
                            self.head += 1;
                        }
                    }
                },
                .TopLevel => {
                    var bytes: usize = 0;
                    while (!self.isDone()) {
                        if (self.cur() == VARIABLE_START_CHAR) {
                            self.state = .BeginReadingVariable;
                            self.current_variable_begin_idx = self.head;
                            self.head += 1;
                            break;
                        }
                        self.head += 1;
                        bytes += 1;
                    }
                    return Token{ .RawSequence = bytes };
                },
            }
        }
        return null;
    }
};

const EtchTemplateError = error{
    InvalidPath,
} || std.mem.Allocator.Error;

const StructVariable = union(enum) {
    String: []const u8,
};

/// Return the builtin.StructField for the provided `path` at `arguments`
fn lookupPath(comptime arguments: anytype, comptime path: []const u8) StructVariable {
    comptime var items: [std.mem.count(u8, path, ".")][]const u8 = undefined;
    comptime var item_idx: usize = 0;

    comptime var head: usize = 1;
    inline while (comptime std.mem.indexOfScalarPos(u8, path, head, VARIABLE_PATH_CHAR)) |idx| {
        items[item_idx] = path[head..idx];
        item_idx += 1;
        head = idx + 1;
    }
    items[item_idx] = path[head..];

    comptime var struct_field_ptr: ?std.builtin.TypeInfo.StructField = null;
    inline for (items) |item, i| {
        if (struct_field_ptr) |*ptr| {
            if (std.meta.fieldIndex(ptr.field_type, item)) |idx| {
                ptr.* = std.meta.fields(ptr.field_type)[idx];
            } else @compileError("Item '" ++ item ++ "' does not exist on provided struct");
        } else {
            if (std.meta.fieldIndex(@TypeOf(arguments), item)) |idx| {
                struct_field_ptr = std.meta.fields(@TypeOf(arguments))[idx];
            } else @compileError("Item '" ++ item ++ "' does not exist on provided struct");
        }

        if (struct_field_ptr) |ptr| {
            if (i == items.len - 1) {
                if (comptime std.mem.eql(u8, ptr.name, item)) {
                    if (ptr.default_value) |val| {
                        return StructVariable{ .String = val };
                    } else @compileError("Unable to get length of field '" ++ item ++ "', is it null?");
                } else @compileError("Item '" ++ item ++ "' does not exist on provided struct");
            }
        }
    }

    @compileError("Item '" ++ item ++ "' does not exist on provided struct");
}

fn getSizeNeededForTemplate(comptime input: []const u8, arguments: anytype) !usize {
    var bytesNeeded: usize = 0;
    var scanner = EtchTokenScanner{
        .input = input,
    };

    while (try scanner.next()) |token| {
        bytesNeeded += switch (token) {
            .RawSequence => |s| s,
            .Variable => |v| switch (lookupPath(arguments, v.path)) {
                .String => |item| item.len,
            },
            .EscapedVariableToken => 1,
        };
    }

    return bytesNeeded;
}

pub fn etchBuf(buf: []u8, comptime input: []const u8, arguments: anytype) []u8 {
    comptime var scanner = EtchTokenScanner{
        .input = input,
    };
    comptime var input_ptr: usize = 0;
    comptime var buf_ptr: usize = 0;
    inline while (comptime try scanner.next()) |token| {
        comptime var input_move_amt = 0;
        comptime var buf_move_amt = 0;
        switch (token) {
            .RawSequence => |s| {
                input_move_amt = s;
                buf_move_amt = s;
                std.mem.copy(u8, buf[buf_ptr .. buf_ptr + s], input[input_ptr .. input_ptr + s]);
            },
            .Variable => |v| {
                comptime const variable = lookupPath(arguments, v.path);
                input_move_amt = v.size;
                switch (variable) {
                    .String => |item| {
                        buf_move_amt = item.len;
                        std.mem.copy(u8, buf[buf_ptr .. buf_ptr + item.len], item[0..]);
                    },
                }
            },
            .EscapedVariableToken => {
                input_move_amt = 2;
                buf_move_amt = 1;
                buf[buf_ptr] = VARIABLE_START_CHAR;
            },
        }
        input_ptr += input_move_amt;
        buf_ptr += buf_move_amt;
    }
    return buf[0..buf_ptr];
}

pub fn etch(allocator: *std.mem.Allocator, comptime input: []const u8, arguments: anytype) ![]u8 {
    const bytesNeeded = comptime getSizeNeededForTemplate(input, arguments) catch |e| {
        switch (e) {
            .UnfinishedVariableDeclaration => @compileError("Reached end of template input, but found unfinished variable declaration"),
            .TemplateVariableEndWithoutBeginning => @compileError("Found template variable end without finding a beginning"),
            .NoVariablePathProvided => @compileError("No variable definition path provided"),
        }
    };
    var buf = try allocator.alloc(u8, bytesNeeded);
    return etchBuf(buf, input, arguments);
}

test "basic interpolation" {
    std.debug.print("\n", .{});

    var timer = try std.time.Timer.start();

    const out = try etch(
        testing.allocator,
        "Hello, { .person.name.first } {{ { .person.name.last }",
        .{ .butt = "cumsicle", .person = .{ .name = .{ .first = "Haze", .last = "Booth" } } },
    );
    defer testing.allocator.free(out);

    testing.expectEqualStrings(out, "Hello, Haze { Booth");
}
