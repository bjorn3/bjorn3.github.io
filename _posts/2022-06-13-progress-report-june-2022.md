---
layout: post
title: "Progress report on rustc_codegen_cranelift (June 2022)"
date: 2022-06-13
categories: cranelift cg_clif rust
---

It's been quite a while since the [last progress report](https://bjorn3.github.io/2021/08/05/progress-report-july-2021.html). There have been [393 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/05677b6bd6c938ed760835d9b1f6514992654ae3...ec841f58d38e5763bc0ad9f405ed5fa075e3fd30) since the last progress report.

# Achievements in the past ten months

#### Migrating away from rust-ar

Since the start archive file reading and writing has been done by the [rust-ar] crate. While is has been very useful, there are a couple of limitations that necessitate moving away from it. First off it doesn't support writing symbol tables. While I managed to implement support for it with the Gnu and BSD variants of the archive format, it doesn't work with macOS, thus requiring usage of `ranlib` on macOS, which is slower than writing the symbol table while creating the archive file. Second my changes to support symbol table writing haven't been merged into rust-ar, which means that cg_clif has to depend on my own fork. This means that if I accidentally delete my fork, cg_clif would be broken. In addition it doesn't play nice with vendoring as necessary for building rust offline. And finally rust-ar is not actively maintained.

To migrate away from I first switched archive file reading from rust-ar to the newly introduced archive file support in the object crate. I'm now working on integrating a port of LLVM's archive writer to rust with rustc so all backends can share the same code.

* [#1155](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1155): Remove the ar git dependency
* [1da5054](https://github.com/bjorn3/rustc_codegen_cranelift/commit/1da50543dd6d1778856e24433d186fd39327def1): Use the object crate for archive reading during archive building
* [rust-lang/rust#97485](https://github.com/rust-lang/rust/pull/97485): Rewrite LLVM's archive writer in Rust

[rust-ar]: https://github.com/mdsteele/rust-ar

#### Multi-threading support

Currently cg_clif does everything on a single thread, unlike cg_llvm which does optimizations and emitting object files in parallel. This means that depending on how many codegen units can be compiled in parallel cg_llvm can finish in less time than cg_clif. I have been slowly working on refactorings that will allow Cranelift to compile codegen units on background threads. These refactorings are necessary as currently a function is immediately compiled after it has been translated to cranelift ir.

* [9089c30](https://github.com/bjorn3/rustc_codegen_cranelift/commit/9089c305dad582cf0da4b84cad27b6fab54434b9): Remove TyCtxt dependency from UnwindContext
* [5f6c59e](https://github.com/bjorn3/rustc_codegen_cranelift/commit/5f6c59e63faf0705d4c6e1fbd7a66ffc59b9ae1f): Pass only the Function to write_clif_file
* [78b6571](https://github.com/bjorn3/rustc_codegen_cranelift/commit/78b65718bce8d7f8b2e1d1af74141cebbd78cf5f): Split compile_fn out of codegen_fn

#### SIMD

There have been a lot of fixes for portable-simd (the unstable `core::simd` module). Part of these also benefit stdarch (the `core::arch` module).

* [a8be7ea](https://github.com/bjorn3/rustc_codegen_cranelift/commit/a8be7ea503211115d7e6339942544268de99bf17): Implement new simd_shuffle signature
* [d288c69](https://github.com/bjorn3/rustc_codegen_cranelift/commit/d288c6924d15e3202f006997167be0e54d307079): Implement simd_reduce_{min,max} for floats
* [dd288d2](https://github.com/bjorn3/rustc_codegen_cranelift/commit/dd288d27de23e2f2180e71b6e9b36789ba388e6f): Fix vector types containing an array field with mir opts enabled
* [037aafb](https://github.com/bjorn3/rustc_codegen_cranelift/commit/037aafbbaf2ee41a11807a1abdec24eb23f505c2): Fix simd type validation
* [f3d97cc](https://github.com/bjorn3/rustc_codegen_cranelift/commit/f3d97cce279fd2372aafec3761791b4110d70bf5): Fix saturating float casts test
* [3c030e2](https://github.com/bjorn3/rustc_codegen_cranelift/commit/3c030e2425bb1fdb165ac87797076072ec991970): Fix NaN handling of simd float min and max operations
* [11007c0](https://github.com/bjorn3/rustc_codegen_cranelift/commit/11007c02f70130cdc70b98f0909e5c150a2751a6): Use fma(f) libm function for simd_fma intrinsic

#### Inline assembly

[`@nbdd0121`](https://github.com/nbdd0121) implemented support for register classes in PR #1206. Previously only fixed register constraints were supported.

I also fixed a couple of bugs in an attempt to compile Philipp Oppermann's [blog os]. There are still many things missing for that to work though.

* [#1206](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1206): Improve inline asm support
* [1222192](https://github.com/bjorn3/rustc_codegen_cranelift/commit/122219237437ee1deee33df9806a4316194a6f76): Use cgu name instead of function name as base for inline asm wrapper name
* [efdbd88](https://github.com/bjorn3/rustc_codegen_cranelift/commit/efdbd88a741074a799563ef08c96ff92905fbc1c): Ensure inline asm wrapper name never starts with a digit
* [#1204](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1204): Full asm!() support
* [#1208](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1208): Support compiling blog os

[blog os]: https://os.phil-opp.com/

#### Misc bug fixes

* [f74cf39](https://github.com/bjorn3/rustc_codegen_cranelift/commit/f74cf39a7434c73424b9e5fddaf78996bd2b06c1): Fix crash when struct argument size is not a multiple of the pointer size
* [97e5045](https://github.com/bjorn3/rustc_codegen_cranelift/commit/97e504549371d7640cf011d266e3c17394fdddac): Fix taking address of truly unsized type field of unsized adt
* [f3fc94f](https://github.com/bjorn3/rustc_codegen_cranelift/commit/f3fc94f2399e8244bb78af8e0e5f462b884083ac): Fix #[track_caller] with MIR inlining
* [f52162f](https://github.com/bjorn3/rustc_codegen_cranelift/commit/f52162f75c640618637e265d005f0f5f25811af5): Fix #[track_caller] location for function chains
* [74b9232](https://github.com/bjorn3/rustc_codegen_cranelift/commit/74b9232ee8001b6204a3c357a7793a6d152bd8ca): Fix assert_assignable for array types
* [7a10059](https://github.com/bjorn3/rustc_codegen_cranelift/commit/7a10059268e456ec89aa05e4df23a2b19b4d8395): Fix symbol tables in case of multiple object files with the same name

#### Usage changes

There have two big changes to the way cg_clif is used. First of the cargo wrapper executable has been renamed to cargo-clif. This is necessary on windows as otherwise the cargo wrapper would invoke itself when running cargo due to windows putting the current working directory in the search path for executables. It also allows invoking the wrapper as `cargo clif` in case you add the cg_clif build directory to your `$PATH`. The second change is that cg_clif is now always run using the `-Zcodegen-backend` rustc argument. This matches what happens when building cg_clif as part of rustc. Previously a wrapper `cg_clif` executable was used which uses rustc_driver to run rustc with cg_clif as backend. This change is only visible when you are directly using cg_clif/rustc without the `cargo-clif` wrapper. Usage of `cargo-clif` is advised.

* [0dd3d28](https://github.com/bjorn3/rustc_codegen_cranelift/commit/0dd3d28cff91ed450e296efa4b9e7db9fb91373b): Rename cargo executable to cargo-clif
* [#1225](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1225): Use -Zcodegen-backend instead of a custom rustc driver

#### Perf optimizations

Both build time and runtime performance should be improved by several percent due to a couple of optimizations. A small improvement is the new support of Cranelift for cold blocks. These are placed at the end of the function to enable more efficient usage of the instruction cache and to reduce branch mispredictions, which slightly improves runtime performance. A much bigger improvement is the replacement of a lot of print+trap combinations with just a trap. While the prints have been very useful for debugging miscompilations, they also bloat compiled binaries a lot (up to ~30% improvement from removing them!). Given that miscompilations in cg_clif are quite rare nowadays, I removed most debug prints. The final improvement is caused by Cranelift switching to a new register allocator. This has improved build time by up to 7% and should also have improved runtime performance a bit.

* [90f8aef](https://github.com/bjorn3/rustc_codegen_cranelift/commit/90f8aefe7142d23a64ae95b5ae5a292a6e0519db): Mark cold blocks
* [#1220](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1220): Replace a lot of print+trap with plain trap
* [bytecodealliance/wasmtime#3989](https://github.com/bytecodealliance/wasmtime/pull/3989): Switch Cranelift over to regalloc2

# Challenges

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
