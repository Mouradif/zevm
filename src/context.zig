const std = @import("std");
const Address = @import("types/address.zig").Address;
const Block = @import("types/block.zig").Block;
const Chain = @import("types/chain.zig").Chain;
const State = @import("types/state.zig").State;

const ContextInitializer = struct {
    block: ?*Block = null,
    state: ?*State = null,
    chain: ?*Chain = null,
};

pub const Context = struct {
    address: Address = 0,
    caller: Address = 0,
    origin: Address = 0,
    block: *Block,
    state: *State,
    chain: *Chain,
    call_value: u256 = 0,
    status: ?bool = null,
    return_data: []const u8,
    gas_limit: u64 = 30_000_000,
    gas_price: u256 = 0,
    gas_used: u64 = 0,
    gas_left: u64 = 0,

    fn init(allocator: std.mem.Allocator, initializer: ContextInitializer) Context {
        const block: *Block = if (initializer.block) |b| b else &Block.init();
        const state: *State = if (initializer.state) |s| s else &State.init(allocator);
        const chain: *State = if (initializer.chain) |s| s else &Chain.init();
        return .{
            .block = block,
            .state = state,
            .chain = chain,
        };
    }
};
