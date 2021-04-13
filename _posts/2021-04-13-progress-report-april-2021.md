---
layout: post
title:  "Progress report on rustc_codegen_cranelift (April 2021)"
date:   2021-04-12
categories: cranelift cg_clif rust
---

Since the [last progress report](https://bjorn3.github.io/2021/02/01/progress-report-jan-2021.html) there have been [135 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/d556c56f792756dd7cfec742b9f2e07612dc10f4...29a4a551eb23969cde9a895d081bee682254974c).

# Achievements in the past three months

#### Removed support for old style Cranelift backends

In the [previous](https://bjorn3.github.io/2021/02/01/progress-report-jan-2021.html) progress report I mentioned that I switched to using the new-style Cranelift backends by default. At the time I kept support for the old-style backends just in case I would find a critical bug. There haven't been any issues with the new backend since, so support for old-style backends has been removed.

* commit [92f765f](https://github.com/bjorn3/rustc_codegen_cranelift/commit/92f765fce96b6344ccfe9b288bbd8b652f5ad0ef): Remove support for x86 oldBE

#### Atomics

Atomic operations are now implemented using native atomic instructions instead of being emulated using a global lock. This is much more efficient and also works when pthreads is not available. As only new-style backends implement them, I couldn't use them until support for the old-style backends was removed.

* commit [f2f5452](https://github.com/bjorn3/rustc_codegen_cranelift/commit/f2f5452089a6cf8eb611badf20118960030f6585): Use real atomic instructions instead of a global lock

#### Cross-compilation to Windows using MinGW

It is now possible to cross-compile to Windows using MinGW. This required implementing a couple of things, like using the right ABI for calling intrinsics defined in compiler_builtins and adding cross-compilation support to the build system of cg_clif.

* [#1145](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1145): Support cross-compiling to Windows using MinGW

#### Run the rustc test suite on CI

The rustc test suite is now run on CI by default to prevent regressions. A [lot](https://github.com/bjorn3/rustc_codegen_cranelift/blob/29a4a551eb23969cde9a895d081bee682254974c/scripts/test_rustc_tests.sh#L13-L85) of tests are currently ignored, but most tests are either LLVM specific (eg asm tests) or require unimplemented features like panicking.

* [#1149](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1149): Run the rustc test suite on CI

# Challenges

While there are several important things currently missing, I am confident that I will be able to implement the most important ones in 2021.

#### Windows support with the MSVC toolchain

Cranelift doesn't yet support TLS for COFF/PE object files. This means that unlike MinGW which uses pthread keys for implementing TLS, it is not currently possible to compile for MSVC.

* issue [wasmtime#1885](https://github.com/bytecodealliance/wasmtime/issues/1885): [Cranelift] Add COFF TLS support
* issue [#997](https://github.com/bjorn3/rustc_codegen_cranelift/issues/977): Windows support

#### SIMD

Many vendor intrinsics remain unimplemented. The new portable SIMD project will however likely exclusively use so called "platform intrinsics" of which there are much fewer, compared to the LLVM intrinsics used to implement all vendor intrinsics in `core::arch`. In addition "platform intrinsics" are the common denominator between platforms supported by rustc, so they only have to be implemented once in cg_clif itself. Cranelift does need a definition for each platform when native SIMD is used, but emulating "platform intrinsics" using scalar instructions is pretty easy.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

# Contributing

Contributions are always appreciated. Feel free to take a look at [good first issues](https://github.com/bjorn3/rustc_codegen_cranelift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) and ping me (@bjorn3) for help on either the relevant github issue or preferably on the [rust lang](https://rust-lang.zulipchat.com) zulip if you get stuck.
