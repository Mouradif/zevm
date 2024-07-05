const Fork = @import("fork.zig").Fork;

pub const Chain = struct {
    id: u64 = 0,
    fork: Fork = .Dencun,
    gas_limit: u64 = 30_000_000,
};
