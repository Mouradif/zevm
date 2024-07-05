const Address = @import("address.zig").Address;

pub const Block = struct {
    number: u64 = 0,
    hash: u256 = 0,
    difficulty: u256 = 0,
    prevrandao: u256 = 0,
    coinbase: Address = 0,
    base_fee: u256 = 0,
    timestamp: u64 = 0,

    fn init() Block {
        return .{};
    }
};
