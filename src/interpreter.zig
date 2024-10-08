const std = @import("std");
const opcode = @import("opcode.zig");
const gas = @import("gas.zig");
const host = @import("host.zig");
const Stack = @import("stack.zig").Stack;
const BigInt = std.math.big.int.Managed;

pub const Status = enum {
    Break,
    Continue,
    OutOfGas,
    StackUnderflow,
    StackOverflow,
};

pub const InterpreterError = error{
    DisallowedHostCall,
};

pub const Interpreter = struct {
    const This = @This();
    ac: std.mem.Allocator,
    inst: [*]u8,
    gas_tracker: gas.Tracker,
    bytecode: []u8,
    eth_host: host.Host,
    stack: Stack(u256),
    inst_result: Status,
    // TODO: Validate inputs.
    pub fn init(
        alloc: std.mem.Allocator,
        eth_host: host.Host,
        bytecode: []u8,
    ) !This {
        return .{
            .ac = alloc,
            .eth_host = eth_host,
            .inst = bytecode.ptr,
            .bytecode = bytecode,
            .stack = try Stack(u256).init(alloc),
            .gas_tracker = gas.Tracker.init(100),
            .inst_result = Status.Continue,
        };
    }
    pub fn deinit(self: *This) !void {
        try self.stack.deinit();
    }
    fn programCounter(self: This) usize {
        // Subtraction of pointers is safe here
        const inst: *u8 = @ptrCast(self.inst);
        return @intFromPtr(self.bytecode.ptr - inst.*);
    }
    pub fn runLoop(self: *This) !void {
        while (self.inst_result == Status.Continue) {
            const op: *u8 = @ptrCast(self.inst);
            std.debug.print("Running 0x{x}\n", .{op.*});
            try self.eval(op.*);
            self.stack.print();
            self.inst = self.inst + 1;
        }
    }
    fn subGas(self: *This, cost: u64) void {
        if (!self.gas_tracker.recordGasCost(cost)) {
            self.inst_result = Status.OutOfGas;
        }
    }
    fn push0(self: *This) !void {
        self.subGas(2);
        try self.stack.push(0);
    }
    fn pushN(self: *This, comptime n: u8) !void {
        self.subGas(3);
        const start: *u8 = @ptrCast(self.inst + n);
        const x = @as(u256, start.*);
        try self.stack.push(x);
        self.inst += n;
    }
    fn dupN(self: *This, comptime n: u8) !void {
        self.subGas(3);
        self.inst_result = try self.stack.dup(n);
    }
    fn swapN(self: *This, comptime n: u8) !void {
        self.subGas(3);
        return try self.stack.swap(n);
    }
    fn eval(self: *This, op: u8) !void {
        switch (op) {
        // Control.
        opcode.STOP => {
            self.inst_result = Status.Break;
        },
        // Arithmetic.
        opcode.ADD => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            var r = try BigInt.init(self.ac);
            defer r.deinit();
            _ = try r.addWrap(&x, &y, .unsigned, 256);
            const result = try r.to(u256);
            try self.stack.push(result);
        },
        opcode.MUL => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            var r = try BigInt.init(self.ac);
            defer r.deinit();
            _ = try r.mulWrap(&x, &y, .unsigned, 256);
            const result = try r.to(u256);
            try self.stack.push(result);
        },
        opcode.SUB => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            var r = try BigInt.init(self.ac);
            defer r.deinit();
            _ = try r.subWrap(&x, &y, .unsigned, 256);
            const result = try r.to(u256);
            try self.stack.push(result);
        },
        opcode.DIV => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            var quotient = try BigInt.init(self.ac);
            defer quotient.deinit();
            var remainder = try BigInt.init(self.ac);
            defer remainder.deinit();
            _ = try quotient.divFloor(&remainder, &x, &y);
            const result = try quotient.to(u256);
            try self.stack.push(result);
        },
        opcode.SDIV => {},
        opcode.MOD => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            try self.stack.push(@mod(a, b));
        },
        opcode.SMOD => {},
        opcode.ADDMOD => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            const c = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            var r = try BigInt.init(self.ac);
            defer r.deinit();
            _ = try r.addWrap(&x, &y, .unsigned, 256);
            const result = try r.to(u256);
            try self.stack.push(@mod(result, c));
        },
        opcode.MULMOD => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            const c = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            var r = try BigInt.init(self.ac);
            defer r.deinit();
            _ = try r.mulWrap(&x, &y, .unsigned, 256);
            const result = try r.to(u256);
            try self.stack.push(@mod(result, c));
        },
        opcode.EXP => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            const exponent = try y.to(u32);
            _ = try x.pow(&x, exponent);
            const result = try x.to(u256);
            try self.stack.push(result);
        },
        opcode.SIGNEXTEND => {},
        // Comparisons.
        opcode.LT => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            if (a < b) {
                try self.stack.push(1);
            } else {
                try self.stack.push(0);
            }
        },
        opcode.GT => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            if (a > b) {
                try self.stack.push(1);
            } else {
                try self.stack.push(0);
            }
        },
        opcode.SLT => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            if (x.order(y) == .lt) {
                try self.stack.push(1);
            } else {
                try self.stack.push(0);
            }
        },
        opcode.SGT => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            var x = try BigInt.initSet(self.ac, a);
            defer x.deinit();
            var y = try BigInt.initSet(self.ac, b);
            defer y.deinit();
            if (x.order(y) == .gt) {
                try self.stack.push(1);
            } else {
                try self.stack.push(0);
            }
        },
        opcode.EQ => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            if (a == b) {
                try self.stack.push(1);
            } else {
                try self.stack.push(0);
            }
        },
        opcode.ISZERO => {
            self.subGas(5);
            const a = self.stack.pop();
            if (a == 0) {
                try self.stack.push(1);
            } else {
                try self.stack.push(0);
            }
        },
        opcode.AND => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            try self.stack.push(a & b);
        },
        opcode.OR => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            try self.stack.push(a | b);
        },
        opcode.XOR => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            try self.stack.push(a ^ b);
        },
        opcode.NOT => {
            self.subGas(5);
            const a = self.stack.pop();
            try self.stack.push(~a);
        },
        opcode.BYTE => {},
        opcode.SHL => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            const rhs: u8 = @truncate(b);
            try self.stack.push(a << rhs);
        },
        opcode.SHR => {
            self.subGas(5);
            const a = self.stack.pop();
            const b = self.stack.pop();
            const rhs: u8 = @truncate(b);
            try self.stack.push(a >> rhs);
        },
        opcode.SAR => {},
        opcode.SHA3 => {
            self.subGas(5);
            // var a = self.stack.pop();
            // var input = try BigInt.initSet(self.ac, a);
            // defer input.deinit();
            // var out: [32]u8 = undefined;
            // var input_bytes = try input.to([32]u8);
            // std.crypto.hash.sha3.Keccak256.hash(&input_bytes, &out, .{});
            // const result = try BigInt.initSet(self.ac, out);
            // defer result.deinit();
            // try self.stack.push(try result.to(u256));
        },
        opcode.ADDRESS => {
            self.subGas(100);
            const env = try self.eth_host.env();
            const addr = switch (env.tx.purpose) {
            .Call => |address| address,
            else => return InterpreterError.DisallowedHostCall,
            };
            try self.stack.push(@as(u256, addr));
        },
        opcode.BALANCE => {
            // TODO: Charge host functions depending on cold results.
            self.subGas(100);
            const a = self.stack.pop();
            const addr: u160 = @truncate(a);
            const result = try self.eth_host.balance(addr);
            const balance = if (result) |r|
            r.data
            else
            0;
            try self.stack.push(balance);
        },
        opcode.ORIGIN => {},
        opcode.CALLER => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(@as(u256, env.tx.caller));
        },
        opcode.CALLVALUE => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.tx.value);
        },
        opcode.CALLDATALOAD => {},
        opcode.CALLDATASIZE => {},
        opcode.CALLDATACOPY => {},
        opcode.CODESIZE => {},
        opcode.GASPRICE => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.tx.gas_price);
        },
        opcode.EXTCODESIZE => {},
        opcode.EXTCODECOPY => {},
        opcode.RETURNDATASIZE => {},
        opcode.RETURNDATACOPY => {},
        opcode.EXTCODEHASH => {},
        opcode.BLOCKHASH => {
            self.subGas(100);
            const a = self.stack.pop();
            if (a > 256) {
                // TODO: Revert instead.
                return InterpreterError.DisallowedHostCall;
            }
        },
        opcode.COINBASE => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.block.coinbase);
        },
        opcode.TIMESTAMP => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.block.timestamp);
        },
        opcode.NUMBER => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.block.number);
        },
        opcode.PREVRANDAO => {
            // self.subGas(100);
            // const env = try self.eth_host.env();
            // try self.stack.push(env.block.prev_randao orelse 0);
        },
        opcode.GASLIMIT => {},
        opcode.CHAINID => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.chain.chain_id);
        },
        opcode.SELFBALANCE => {},
        opcode.BASEFEE => {
            self.subGas(100);
            const env = try self.eth_host.env();
            try self.stack.push(env.block.basefee);
        },
        opcode.POP => {
            self.subGas(3);
            _ = self.stack.pop();
        },
        opcode.MLOAD => {},
        opcode.MSTORE => {},
        opcode.MSTORE8 => {},
        opcode.SLOAD => {},
        opcode.SSTORE => {},
        opcode.JUMP => {
            // TODO: JUMPDEST checks.
            // self.subGas(gas.LOW);
            const a = self.stack.pop();
            _ = a;
            //self.inst = @ptrCast([*]u8, &@truncate(u8, a));
        },
        opcode.JUMPI => {},
        opcode.PC => {
            try self.stack.push(@as(u256, self.programCounter()));
        },
        opcode.MSIZE => {},
        opcode.GAS => {
            try self.stack.push(@as(u256, self.gas_tracker.total_used));
        },
        opcode.JUMPDEST => {},
        // Pushes.
        opcode.PUSH0 => try self.push0(),
        opcode.PUSH1 => try self.pushN(1),
        opcode.PUSH2 => try self.pushN(2),
        opcode.PUSH3 => try self.pushN(3),
        opcode.PUSH4 => try self.pushN(4),
        opcode.PUSH5 => try self.pushN(5),
        opcode.PUSH6 => try self.pushN(6),
        opcode.PUSH7 => try self.pushN(7),
        opcode.PUSH8 => try self.pushN(8),
        opcode.PUSH9 => try self.pushN(9),
        opcode.PUSH10 => try self.pushN(10),
        opcode.PUSH11 => try self.pushN(11),
        opcode.PUSH12 => try self.pushN(12),
        opcode.PUSH13 => try self.pushN(13),
        opcode.PUSH14 => try self.pushN(14),
        opcode.PUSH15 => try self.pushN(15),
        opcode.PUSH16 => try self.pushN(16),
        opcode.PUSH17 => try self.pushN(17),
        opcode.PUSH18 => try self.pushN(18),
        opcode.PUSH19 => try self.pushN(19),
        opcode.PUSH20 => try self.pushN(20),
        opcode.PUSH21 => try self.pushN(21),
        opcode.PUSH22 => try self.pushN(22),
        opcode.PUSH23 => try self.pushN(23),
        opcode.PUSH24 => try self.pushN(24),
        opcode.PUSH25 => try self.pushN(25),
        opcode.PUSH26 => try self.pushN(26),
        opcode.PUSH27 => try self.pushN(27),
        opcode.PUSH28 => try self.pushN(28),
        opcode.PUSH29 => try self.pushN(29),
        opcode.PUSH30 => try self.pushN(30),
        opcode.PUSH31 => try self.pushN(31),
        opcode.PUSH32 => try self.pushN(32),
        // Dups.
        opcode.DUP1 => try self.dupN(1),
        opcode.DUP2 => try self.dupN(2),
        opcode.DUP3 => try self.dupN(3),
        opcode.DUP4 => try self.dupN(4),
        opcode.DUP5 => try self.dupN(5),
        opcode.DUP6 => try self.dupN(6),
        opcode.DUP7 => try self.dupN(7),
        opcode.DUP8 => try self.dupN(8),
        opcode.DUP9 => try self.dupN(9),
        opcode.DUP10 => try self.dupN(10),
        opcode.DUP11 => try self.dupN(11),
        opcode.DUP12 => try self.dupN(12),
        opcode.DUP13 => try self.dupN(13),
        opcode.DUP14 => try self.dupN(14),
        opcode.DUP15 => try self.dupN(15),
        opcode.DUP16 => try self.dupN(16),
        // Swaps.
        opcode.SWAP1 => try self.swapN(1),
        opcode.SWAP2 => try self.swapN(2),
        opcode.SWAP3 => try self.swapN(3),
        opcode.SWAP4 => try self.swapN(4),
        opcode.SWAP5 => try self.swapN(5),
        opcode.SWAP6 => try self.swapN(6),
        opcode.SWAP7 => try self.swapN(7),
        opcode.SWAP8 => try self.swapN(8),
        opcode.SWAP9 => try self.swapN(9),
        opcode.SWAP10 => try self.swapN(10),
        opcode.SWAP11 => try self.swapN(11),
        opcode.SWAP12 => try self.swapN(12),
        opcode.SWAP13 => try self.swapN(13),
        opcode.SWAP14 => try self.swapN(14),
        opcode.SWAP15 => try self.swapN(15),
        opcode.SWAP16 => try self.swapN(16),
        opcode.LOG0 => {
            // self.subGas(100);
            // const env = try self.eth_host.env();
            // try self.stack.push(env.chain.chain_id);
        },
        opcode.LOG1 => {},
        opcode.LOG2 => {},
        opcode.LOG3 => {},
        opcode.CREATE => {},
        opcode.CALL => {},
        opcode.CALLCODE => {},
        opcode.RETURN => {},
        opcode.DELEGATECALL => {},
        opcode.CREATE2 => {},
        opcode.STATICCALL => {},
        opcode.REVERT => {},
        opcode.INVALID => {},
        opcode.SELFDESTRUCT => {},
        else => {
            std.debug.print("Unhandled opcode 0x{x}\n", .{op});
            self.inst_result = Status.Break;
        },
        }
    }
};

