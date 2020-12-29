---
layout: post
title:  "Progress report on rustc_codegen_cranelift (Sep 2020)"
date:   2020-09-28
categories: cranelift cg_clif rust
---

[Rustc_codegen_cranelift](https://github.com/bjorn3/rustc_codegen_cranelift) (cg_clif) is an alternative backend for rustc that I have been working on for the past two years. It uses the Cranelift code generator. Unlike LLVM which is optimized for output quality at the cost of compilation speed even when optimizations are disabled, Cranelift is optimized for compilation speed while producing executables that are almost as fast as LLVM with optimizations disabled. This has the potential to reduce the compilation times of rustc in debug mode.

I recently looked back at the [notes](https://hackmd.io/VnVX5bEHR268SDH4R7izLw) for the [design meeting](https://rust-lang.zulipchat.com/#narrow/stream/131828-t-compiler/topic/design.20meeting.202020-04-03.20compiler-team.23257/near/192806450) ([meeting proposal](https://github.com/rust-lang/compiler-team/issues/257)) about integrating cg_clif into rustc. I noticed that several of the challenges that needed to be solved have since been solved. Because of this I decided to give an overview of the achievements in the past six months and what the current challenges are.

# Achievements in the past six months

#### :tada: Building rustc :tada:

Fixing an ABI incompatibility for proc-macros (see next section) combined with several small fixes to the 128bit support made it possible to compile rustc using cg_clif.

* issue [#743](https://github.com/bjorn3/rustc_codegen_cranelift/issues/743): Compile rustc using cg_clif
* commit [cd684e3](https://github.com/bjorn3/rustc_codegen_cranelift/commit/cd684e39e0d27513d21f15e7cc65273ec5883e1b): Fix saturated_* intrinsics for 128bit ints
* commit [ef4186a](https://github.com/bjorn3/rustc_codegen_cranelift/commit/ef4186a85b4c9bd94d258e3280cb239f26b8436e): Use Cranelift legalization for icmp.i128
* commit [8d639cd](https://github.com/bjorn3/rustc_codegen_cranelift/commit/8d639cd778bb11fed2c230d8071664e24d30a84f): Test signed 128bit discriminants
* commit [e87651c](https://github.com/bjorn3/rustc_codegen_cranelift/commit/e87651c3f23e6ad63cc1ee359115ad72e50d3ba9): Add test for SwitchInt on 128bit integers

#### ABI compatibility

Proc-macro support has been implemented by fixing an ABI incompatibility.

* [#1068](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1068): Pass ByRef values at fixed stack offset for extern "C"
* [wasmtime#1559](https://github.com/bytecodealliance/wasmtime/pull/1559): SystemV struct arguments

#### Inline assembly

The new style `asm!` inline assembly and `global_asm!` have been implemented on Linux by compiling a separate object file using an assembler and linking the main object file for the codegen unit and the assembly object file together. On macOS linking both object files together gives a linker error. Linking both object files together is necessary as rustc expects a single object file for each codegen unit.

* [#1062](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1062): Implement global_asm! using an external assembler
* [#1064](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1064): Basic inline asm support

#### SIMD

The cpuid x86 instruction is now emulated using code that pretends the current CPU is an Intel cpu with SSE and SSE2 support. This fixes ppv-lite86 and by extension c2-chacha and rand. It is not yet possible to use the inline assembly support as corearch uses `llvm_asm!` for the cpuid invocation. I didn't implement this as it is currently being replaced with `asm!`.

* [#1070](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1070): Emulate cpuid

Stdarch has been changed to use constify on all x86 intrinsics that use `rustc_args_required_const`. This was necessary to support `simd_insert` and `simd_extract` based intrinsics.

* [stdarch#876](https://github.com/rust-lang/stdarch/pull/876): Constify all x86 rustc_args_required_const intrinsics
* issue [#669](https://github.com/bjorn3/rustc_codegen_cranelift/issues/669): Support simd_insert platform intrinsic

#### Fixing linking with lld and sysroot and executable size

I assumed the sysroot and executables are much bigger for cg_clif than cg_llvm because of missing optimizations. While fixing linking with lld I discovered that for executables most of this is caused by per function sections not being used by cg_clif. Using this does significantly reduce the size of executables at the cost of significantly slowing down the linker. For this reason I put it behind the `CG_CLIF_FUNCTION_SECTIONS` env var.

* [#1083](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1083): Fix lld
* [wasmtime#2212](https://github.com/bytecodealliance/wasmtime/pull/2212): Fix relocated readonly data in custom sections
* [wasmtime#2218](https://github.com/bytecodealliance/wasmtime/pull/2218): cranelift-object: Support per function sections

#### Unsized locals

rust#77170 changed the MIR of `<Box<F> as FnOnce>::call_once` such that it doesn't need an alloca anymore. 27a46ff removed the hack to workaround the missing alloca support for this.

* commit [27a46ff](https://github.com/bjorn3/rustc_codegen_cranelift/commit/27a46ff765c26eab7b1e1f7d419cec8f5051df00): Rustup to rustc 1.44.0-nightly (45d050cde 2020-04-21)
* [rust#71170](https://github.com/rust-lang/rust/pull/71170): Make `Box<dyn FnOnce>` respect self alignment

#### Rust test suite

There has been significant improvements on the amount of passing rustc tests with the previously mentioned #1068 fixing 82 tests. Except for abi incompatibilities all miscompilations seem to be fixed. There are some unimplemented features, but those are not very important for most use cases.

* issue [#381](https://github.com/bjorn3/rustc_codegen_cranelift/issues/381): Make rustc test suite pass

# Challenges

#### SIMD

Many intrinsics remain unimplemented.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### ABI compatibility

There are many remaining ABI incomptibilities. I will need to rework cg_clif to reuse `rustc_target::abi::call::FnAbi`.

* [#10](https://github.com/bjorn3/rustc_codegen_cranelift/issues/10): C abi compatability

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding.

* [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

#### Atomics

Atomic instructions are currently emulated using a global lock. This is very inefficient and only works when pthreads is available. The new style backend for Cranelift support native atomic instructions. There are several missing features before I can switch cg_clif to use the new style backends.

* [wasmtime#2077](https://github.com/bytecodealliance/wasmtime/pull/2077): Implement Wasm Atomics for Cranelift/newBE/aarch64.
* [wasmtime#2149](https://github.com/bytecodealliance/wasmtime/pull/2149): This patch fills in the missing pieces needed to support wasm atomics...

#### Windows support

Various issues

* [#997](https://github.com/bjorn3/rustc_codegen_cranelift/issues/977): Windows support
* branch [wip_windows_support](https://github.com/bjorn3/rustc_codegen_cranelift/compare/wip_windows_support)

#### `git subtree`

The plan for integration with rustc was to use `git subtree`. This git command currently has a bug for which a fix has not yet been upstreamed. It would be nice if for example `git submodule` could be used for the time being instead.

* [rust-clippy#5565](https://github.com/rust-lang/rust-clippy/issues/5565): git subtree crashes: can't sync rustc clippy changes into rust-lang/rust-clippy
* [compiler-team#270](https://github.com/rust-lang/compiler-team/issues/270): Integration of the Cranelift backend with rustc

#### Maintenance

While there have been several PR's by other people like @osa1, @vi, @spastorino and @CohenArthur, I am the only person who has contributed more than a few changes to cg_clif.

* <https://github.com/bjorn3/rustc_codegen_cranelift/pulls?q=is%3Apr+is%3Aclosed+-author%3Aapp%2Fdependabot-preview>

# How can I help?

The easiest way to help is by trying to compile and run any project and reporting any issues. You could also try to fix one of the above issues or any other issues in the issue tracker. They are not easy though. Contributing to Cranelift will also help with cg_clif.

# Thanks

I would like to thank each and every person that has supported me while working on cg_clif for the past 2 years. Whether by contributing, donating or simply mentioning cg_clif.

I would also like to thank @eddyb and @cfallin for reviewing a draft of this post.
