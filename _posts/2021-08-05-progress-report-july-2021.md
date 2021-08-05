---
layout: post
title:  "Progress report on rustc_codegen_cranelift (July 2021)"
date:   2021-08-05
categories: cranelift cg_clif rust
---

Since the [last progress report](https://bjorn3.github.io/2021/04/13/progress-report-april-2021.html) there have been [242 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/29a4a551eb23969cde9a895d081bee682254974c...05677b6bd6c938ed760835d9b1f6514992654ae3).

# Achievements in the past four months

#### SIMD

Almost all integer tests and float tests of [portable-simd](https://github.com/rust-lang/portable-simd/) (formerly stdsimd) now pass. A couple of operations are not yet implemented, but other than that it now works just fine.

In addition [@shamatar](https://github.com/shamatar) implemented the `llvm.x86.addcarry.64` and `llvm.x86.subborrow.64` instrinsics as their first contribution. They are used by some of the `core::arch` SIMD intrinsics that the `num-bigint` crate uses.

* [#1189](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1189): Improve stdsimd support
* [#1178](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1178): Implement llvm.x86.addcarry.64 and llvm.x86.subborrow.64

#### AArch64 support on Linux

It is now possible to cross-compile to AArch64 Linux. Native compilation should work too, but isn't tested. At the moment there does seem to be an ABI incompatibility around proc-macros though, so those don't work when using native compilation.

* [#1183](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1183): AArch64 support on Linux

#### `-Ctarget-cpu` support

Thanks to [`@mominul`](https://github.com/mominul) it is now possible to use `-Ctarget-cpu` with cg_clif. The given value is passed directly to Cranelift, so not every target cpu supported by LLVM is allowed, but `-Ctarget-cpu=native` works fine as well as the list of target cpus [supported] by Cranelift.

* [#1163](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1163): Support `-Ctarget-cpu`

[supported]: https://github.com/bytecodealliance/wasmtime/blob/85f16f488d4a0047e40a885fdacda832d46815e8/cranelift/codegen/meta/src/isa/x86/settings.rs#L168-L212

#### Rust build system

The most important parts of the build system have been rewritten from bash scripts to rust code. This allows it to run on systems that don't have bash like Windows. It is still necessary for git to be available though.

* [#1180](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1180): Rewrite part of the build system in rust

#### Multithreading support for the JIT mode

[`@eggyal`](https://github.com/eggyal) implemented multithreading support for the lazy-jit mode. When a function is called that still needs to be lazily compiled, this compilation happens on the main rustc thread. This blocks compilation of other functions, but doesn't interrupt other threads if they don't need any function to be compiled.

* [#1166](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1166): Multithreading support for lazy-jit
* [bytecodealliance/wasmtime#2786](https://github.com/bytecodealliance/wasmtime/pull/2786): Atomic hotswapping in JIT mode

# Challenges

While there are several important things currently missing, I am confident that I will be able to implement the most important ones in 2021.

#### Windows support with the MSVC toolchain

Cranelift doesn't yet support TLS for COFF/PE object files. This means that unlike MinGW which uses pthread keys for implementing TLS, it is not currently possible to compile for MSVC.

* issue [wasmtime#1885](https://github.com/bytecodealliance/wasmtime/issues/1885): [Cranelift] Add COFF TLS support
* issue [#997](https://github.com/bjorn3/rustc_codegen_cranelift/issues/977): Windows support

#### SIMD

Many vendor intrinsics remain unimplemented. The new portable SIMD project will however likely exclusively use so called "platform intrinsics" of which there are much fewer, compared to the LLVM intrinsics used to implement all vendor intrinsics in `core::arch`. In addition "platform intrinsics" are the common denominator between platforms supported by rustc, so they only have to be implemented once in cg_clif itself and in fact most have already been implemented. Cranelift does need a definition for each platform when native SIMD is used, but emulating "platform intrinsics" using scalar instructions is pretty easy.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

# Contributing

Contributions are always appreciated. Feel free to take a look at [good first issues](https://github.com/bjorn3/rustc_codegen_cranelift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) and ping me (@bjorn3) for help on either the relevant github issue or preferably on the [rust lang](https://rust-lang.zulipchat.com) zulip if you get stuck.

Thanks to [@cfallin](https://github.com/cfallin) for giving feedback on this progress report.
