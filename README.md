# Zig Ethereum Virtual Machine

zEVM is an implementation of the Ethereum virtual machine
(EVM) written entirely in Zig. This implementation is
heavily inspired by the work from Revolutionary EVM (rEVM),
written in Rust and highly optimized. The EVM runs 
interpreted bytecode on every Ethereum node, and is arguably
the most critical component of the system's consensus.

zEVM builds on the principles of zig's blazing fast 
performance and simplicity, aiming to be as memory efficient
as possible thanks to Zig's focus on having developers carefully
manage memory and with runtime safety checks for memory usage and
arithmetic operations.

zEVM will aim to be the most memory efficient and fastest EVM implementation.

Rust bindings will be provided for zEVM.

## Installing

Built with [Zig](https://ziglang.org/download/) version `0.13.0`

``` text
git clone https://github.com/rauljordan/zevm && cd zevm
zig run src/main.zig
```

## TODOs

- [x] Arithmetic opcodes
- [x] Stack manipulation opcodes
- [ ] Control flow opcodes
- [x] Host defined
- [ ] Host opcodes 
- [ ] Passing spec tests
- [ ] Benchmarks
- [ ] Rust bindings
