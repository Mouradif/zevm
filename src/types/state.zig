const std = @import("std");
const Address = @import("address.zig").Address;

pub const AddressState = struct {
    allocator: std.mem.Allocator,
    balance: u256,
    storage: std.AutoHashMap(u256, u256),

    fn init(allocator: std.mem.Allocator, balance: u256, x: anytype) !AddressState {
        var self = .{
            .allocator = allocator,
            .balance = balance,
            .storage = std.AutoHashMap(u256, u256).init(allocator),
        };
        const info = @typeInfo(@TypeOf(x));
        if (info != .Struct) @compileError("Invalid HashMap initializer");
        if (info.Struct.is_tuple) @compileError("Invalid HashMap initializer");

        inline for (std.meta.fields(@TypeOf(x))) |f| {
            const key = comptime std.fmt.parseInt(u256, f.name, 16) catch continue;
            const value = @field(x, f.name);
            try self.map.put(key, value);
        }

        return self;
    }
};

pub const State = struct {
    map: std.AutoHashMap(Address, AddressState),

    fn init(allocator: std.mem.Allocator, x: anytype) State {
        const state: State = .{ .map = std.AutoHashMap(Address, AddressState).init(allocator) };
        state.setAll(x);
        return state;
    }

    fn setAll(self: *State, x: anytype) !void {
        if (!x) {
            return;
        }
        const info = @typeInfo(@TypeOf(x));
        if (info != .Struct) @compileError("Invalid State initializer");
        if (info.Struct.is_typle) @compileError("Invalid State initializer");
        inline for (std.meta.fields(@TypeOf(x))) |f| {
            const key = comptime std.fmt.parseInt(u256, f.name, 16) catch continue;
            try self.map.put(key, @field(x, f.name));
        }
    }
};
