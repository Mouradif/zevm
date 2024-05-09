const std = @import("std");
const testing = std.testing;
const opcode = @import("opcode.zig");
const Interpreter = @import("interpreter.zig").Interpreter;
const gas = @import("gas.zig");
const host = @import("host.zig");
const Stack = @import("stack.zig").Stack;

const MAX_CODE_SIZE: usize = 0x6000;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var ac = gpa.allocator();
    // defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const ac = arena.allocator();
    defer _ = arena.deinit();

    // TODO: Use turbopool defined in this file to go even faster.

    // TODO: Allocate a fixed buffer for the stack!
    var bytecode = [_]u8{
        opcode.PUSH1,
        0x02,
        opcode.PUSH1,
        0x03,
        opcode.PUSH1,
        0x04,
        opcode.PUSH0,
        opcode.SWAP1,
        opcode.DUP1,
        opcode.ADD,
        opcode.DUP1,
        opcode.EXP,
        opcode.MULMOD,
        opcode.STOP,
    };
    std.debug.print("input bytecode 0x{x}\n", .{
        std.fmt.fmtSliceHexLower(&bytecode),
    });
    const mock = host.Mock.init();
    var interpreter = try Interpreter.init(ac, mock.host, &bytecode);
    defer interpreter.deinit() catch std.debug.print("failed", .{});

    const start = try std.time.Instant.now();
    try interpreter.runLoop();
    const end = try std.time.Instant.now();
    std.debug.print("Elapsed={}, Result={}\n", .{ std.fmt.fmtDuration(end.since(start)), interpreter.inst_result });
}

test "Arithmetic opcodes" {}
test "Bitwise manipulation opcodes" {}
test "Stack manipulation opcodes" {}
test "Control flow opcodes" {}
test "Host opcodes" {}

// Insanely fast arena allocator for a single type using a memory pool.
fn TurboPool(comptime T: type) type {
    return struct {
        const Self = @This();
        const List = std.TailQueue(T);
        arena: std.heap.ArenaAllocator,
        free: List = .{},

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .arena = std.heap.ArenaAllocator.init(allocator),
            };
        }
        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }
        pub fn new(self: *Self) !*T {
            const obj = if (self.free.popFirst()) |item|
                item
            else
                try self.arena.allocator().create(List.Node);
            return &obj.data;
        }
        pub fn delete(self: *Self, obj: *T) void {
            const node: List.Node = @fieldParentPtr("data", obj);
            self.free.append(node);
        }
    };
}
