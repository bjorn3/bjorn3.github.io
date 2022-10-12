---
layout: post
title: "Progress report on rustc_codegen_cranelift (Okt 2022)"
date: 2022-10-12
categories: cranelift cg_clif rust
---

There has a ton of progress since the [last progress report](https://bjorn3.github.io/2022/06/13/progress-report-june-2022.html). There have been [303 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/ec841f58d38e5763bc0ad9f405ed5fa075e3fd30...69297f9c863f0e153d10447685b9a2cc34f60d57) since then. @afonso360 has been contributing a ton to improve Windows and AArch64 support. (Thanks a lot for that!)

# Achievements in the past four months

#### Windows support with the MSVC toolchain

Windows support with the MSVC toolchain has been added by @afonso360. This requires a Cranelift change to add COFF based TLS support, a rewrite of the bash scripts for testing in rust (as windows doesn't have bash), adding inline stack probing to Cranelift (stack probing is necessary on Windows to grow the stack) and finally a couple of minor changes to tests to make them run on Windows. There are still a couple of issues though. For example the JIT mode just crashes. In addition Bevy gets miscompiled causing it to crash at runtime. An investigation into this is ongoing.

* [#1252](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1252): Move test script to y.rs
* [#1253](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1253): Fix `no_sysroot` testsuite for MSVC environments
* [bytecodealliance/wasmtime#4546](https://github.com/bytecodealliance/wasmtime/pull/4546): cranelift: Add COFF TLS Support
* [bytecodealliance/wasmtime#4747](https://github.com/bytecodealliance/wasmtime/pull/4747): cranelift: Add inline stack probing for x64
* [#1249](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1249): Miscompilation of Bevy with MSVC

#### Abi fixes

Gankra's [abi cafe](https://github.com/gankra/abi-cafe) (previously abi-checker) now gets run on CI. This uncovered a couple of ABI issues between cg_clif and cg_llvm. Some were the fault of cg_clif and others had to be fixed in Cranelift.

* [#1255](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1255): Add abi-checker to y.rs and run it on CI
* [45b6cd6a8a2a3b364d22d4fabc0d72f9e37e3e50](https://github.com/bjorn3/rustc_codegen_cranelift/commit/45b6cd6a8a2a3b364d22d4fabc0d72f9e37e3e50): Fix a crash for 11 single byte fields passed through the C abi
* [bytecodealliance/wasmtime#4634](https://github.com/bytecodealliance/wasmtime/pull/4634): Fix sret for AArch64

#### AArch64 support

Linux on AArch64 now passes the full test suite of cg_clif. It is not tested in CI, so it is possible that support will regress in the future.

#### Basic s390x support

Basic support for IBM's s390x architecture has been added by @uweigand. There is no testing on CI and there are still some test failures.

* [#1260](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1260): Ignore ptr_bitops_tagging test on s390x
* issue [#1258](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1258): s390x test failure due to unsupported stack realignment
* issue [#1259](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1259): Enabling s390x on CI

#### Multi-threading support

The LLVM backend has supported multi-threading during compilation from LLVM IR to object files since [2014](https://github.com/rust-lang/rust/pull/16367). While the frontend is not parallelized, this can still give a non-trivial perf boost. Cg_clif until recently didn't support this, causing it to take longer to compile especially on machines with many cores. After doing significant refactorings all over cg_clif for about two weeks I was able to implement multi-threading support in cg_clif too. It was a lot of effort, but it was well worth it. There are almost no cases where cg_llvm is faster than cg_clif now.

<details><summary>The perf results (warning: long image)</summary>

<img src="https://user-images.githubusercontent.com/17426603/186444984-05a1362a-60c8-486f-bdcd-01bcdab87e52.png" alt="wall time on the rustc perf suite when compared to cg_llvm which shows almost all benchmarks having a significant improvement">

</details>

* [#1264](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1264): Refactorings for enabling parallel compilation (part 1)
* [#1266](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1266): Refactorings for enabling parallel compilation (part 2)
* [#1271](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1271): Support compiling codegen units in parallel

#### Inline assembly

While working on implementing multi-threading I was able to remove the partial linking hack that was used for supporting inline assembly and incremental compilation at the same time. This hack was incompatible with macOS. Now that it is no longer necessary inline assembly works on macOS too.

* [e45f600](https://github.com/bjorn3/rustc_codegen_cranelift/commit/e45f6000a0bd46d4b7580db59c86f3d30adbc270): Remove the partial linking hack for global asm support
* [f76ca22](https://github.com/bjorn3/rustc_codegen_cranelift/commit/f76ca2247998bff4e10b73fcb464a0a83edbfeb0): Enable inline asm on macOS

#### Portable simd

I implemented a couple of intrinsics used by `core::simd`. Only `simd_scatter`, `simd_gather` and `simd_arith_offset` are missing now. Note that a large portion of `core::arch` is still unimplemented.

* [#1277](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1277): Implement a couple of portable simd intrinsics

# Challenges

#### SIMD

Many vendor intrinsics remain unimplemented. The new portable SIMD project will however likely exclusively use so called "platform intrinsics" of which there are much fewer, compared to the LLVM intrinsics used to implement all vendor intrinsics in `core::arch`. In addition "platform intrinsics" are the common denominator between platforms supported by rustc, so they only have to be implemented once in cg_clif itself and in fact most have already been implemented. Cranelift does need a definition for each platform when native SIMD is used, but emulating "platform intrinsics" using scalar instructions is pretty easy.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

#### Distributing as rustup component

There is progress towards distributing cg_clif as rustup components, but there are still things to be done. https://github.com/bjorn3/rustc_codegen_cranelift/milestone/2 lists things I know of that still needs to be done.

# Contributing

Contributions are always appreciated. Feel free to take a look at [good first issues](https://github.com/bjorn3/rustc_codegen_cranelift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) and ping me (@bjorn3) for help on either the relevant github issue or preferably on the [rust lang](https://rust-lang.zulipchat.com) zulip if you get stuck.
