---
layout: post
title:  "Progress report on rustc_codegen_cranelift (Jan 2021)"
date:   2021-02-01
categories: cranelift cg_clif rust
---

[Rustc_codegen_cranelift](https://github.com/bjorn3/rustc_codegen_cranelift) (cg_clif) is an alternative backend for rustc that I have been working on for the past two years. It uses the Cranelift code generator. Unlike LLVM which is optimized for output quality at the cost of compilation speed even when optimizations are disabled, Cranelift is optimized for compilation speed while producing executables that are almost as fast as LLVM with optimizations disabled. This has the potential to reduce the compilation times of rustc in debug mode.

Since the [last progress report](https://bjorn3.github.io/2021/01/07/progress-report-dec-2020.html) there have been [54 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/dbee13661efa269cb4cd57bb4c6b99a19732b484...d556c56f792756dd7cfec742b9f2e07612dc10f4).

# Achievements in the past months

#### :tada: ABI compatibility :tada:

The biggest achievement this time is ABI compatibility with cg_llvm and C. This fixed several crashes when linking against C code. This also makes it possible to mix and match crates compile with cg_clif and compiled with cg_llvm. This may be useful for game development by compiling the game engine using cg_llvm with optimizations enabled for runtime performance and then compiling the game logic using cg_clif for incremental compilation time.

There is currently no easy way to mix codegen backends for different crates, but I do have a cargo PR open that would allow it. I do not expect it to land as is, but I hope something like it will be merged.

* [rust#80594](https://github.com/rust-lang/rust/pull/80594): Various ABI refactorings
* issue [#10](https://github.com/bjorn3/rustc_codegen_cranelift/issues/10): C abi compatability
* [#1131](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1131): Full abi compatibilty
* [cargo#9118](https://github.com/rust-lang/cargo/pull/9118): Add a profile option to select the codegen backend

#### Switch to the new backend framework of Cranelift

Cranelift is currently switching to a new backend framework. This framework produces faster code and has support for AArch64. Since the last progress report [@cfallin](https://github.com/cfallin) has landed all features and bug fixes necessary to compile using the x64 backend based on the new framework. This allowed me to switch to it by default. So far no new problems have surfaced, but I plan to retain compatibility with the old backend for a little bit longer just in case.

* <https://cfallin.org/blog/2020/09/18/cranelift-isel-1/>
* <https://cfallin.org/blog/2021/01/22/cranelift-isel-2/>
* [wasmtime#2538](https://github.com/bytecodealliance/wasmtime/pull/2538): Multi-register value support: framework for Values wider than machine registers.
* [wasmtime#2539](https://github.com/bytecodealliance/wasmtime/pull/2539): Support for I128 operations in x64 backend.
* [wasmtime#2540](https://github.com/bytecodealliance/wasmtime/pull/2540): Add ELF TLS support in new x64 backend.
* [wasmtime#2541](https://github.com/bytecodealliance/wasmtime/pull/2541): x64 and aarch64: allow StructArgument and StructReturn args.
* [wasmtime#2558](https://github.com/bytecodealliance/wasmtime/pull/2558): x64: support PC-rel symbol references using the GOT when in PIC mode. 
* [wasmtime#2595](https://github.com/bytecodealliance/wasmtime/pull/2595): Implement Mach-O TLS access for x64 newBE

# Challenges

While there are several important things currently missing, I am confident that I will be able to implement the most important things in 2021.

#### Atomics

Atomic instructions are currently emulated using a global lock. This is very inefficient and only works when pthreads is available. The new style backends for Cranelift have native support for atomic instructions. I will switch to them once I drop support for the old style x86 backend.

* [wasmtime#2077](https://github.com/bytecodealliance/wasmtime/pull/2077): Implement Wasm Atomics for Cranelift/newBE/aarch64.
* [wasmtime#2149](https://github.com/bytecodealliance/wasmtime/pull/2149): This patch fills in the missing pieces needed to support wasm atomics...

#### Windows support

Various issues. See issue [#997](https://github.com/bjorn3/rustc_codegen_cranelift/issues/977) for more information.

* issue [wasmtime#1885](https://github.com/bytecodealliance/wasmtime/issues/1885): [Cranelift] Add COFF TLS support
* issue [#997](https://github.com/bjorn3/rustc_codegen_cranelift/issues/977): Windows support
* branch [wip_windows_support3](https://github.com/bjorn3/rustc_codegen_cranelift/compare/wip_windows_support3)

#### SIMD

Many vendor intrinsics remain unimplemented. The new portable SIMD project will however likely exclusively use platform intrinsics or which there are much fewer compared to the LLVM intrinsics used to implement all vendor intrinsics in `core::arch`. In addition platform intrinsics are architecture independent, so they only have to be implemented once.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

#### Maintenance

While there have been several PR's by other people, I am the only person who has contributed more than a few changes to cg_clif.

* <https://github.com/bjorn3/rustc_codegen_cranelift/pulls?q=is%3Apr+is%3Aclosed+-author%3Aapp%2Fdependabot-preview>
