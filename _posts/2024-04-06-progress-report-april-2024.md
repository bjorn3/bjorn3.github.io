---
layout: post
title: "Progress report on rustc_codegen_cranelift (April 2024)"
date: 2024-04-06
categories: cranelift cg_clif rust
---

There has been a fair bit of progress since the [last progress report](https://bjorn3.github.io/2022/10/12/progress-report-okt-2022.html)! There have been [342 commits](https://github.com/rust-lang/rustc_codegen_cranelift/compare/9a33f82140c6da6e5808253309c674554b93e9fe...242b261585ffb70108bfd236a260e95ec4b06556) since the last progress report.

You can find a precompiled version of cg_clif at <https://github.com/bjorn3/rustc_codegen_cranelift/releases/tag/dev> or in the rustc-codegen-cranelift-preview rustup component if you want to try it out.

# Achievements in the past five months

#### SIMD

A ton of missing SIMD intrinsics got reported over the past couple of months. Most intrinsics that people have reported missing are now implemented.

* [#1416](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1416): Implement AArch64 intrinsics necessary for simd-json (thanks @afonso360!)
* [#1417](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1417): Implement a lot of SIMD intrinsics
* [#1425](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1425): Implement AES-NI and SHA256 crypto intrinsics using inline asm
* [#1431](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1431): Implement another batch of vendor intrinsics
* [45d8c12](https://github.com/rust-lang/rustc_codegen_cranelift/commit/45d8c121ba02c825379b655d8dd74e1843e98d62): Return architecturally mandated target features to rustc
* [#1443](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1443): Restructure x86 signed pack instructions (thanks @Nilstrieb!)
* [0dc13d7](https://github.com/rust-lang/rustc_codegen_cranelift/commit/0dc13d7acb0118d6c14a9209d921e5278e829458): Implement \_mm\_prefetch as nop
* [24361a1](https://github.com/rust-lang/rustc_codegen_cranelift/commit/24361a1b99b122806afdc01c3aae1c43fdcc7e0a): Fix portable-simd tests
* [604c8a7](https://github.com/rust-lang/rustc_codegen_cranelift/commit/604c8a7cf80eca33bd078d6b45faaa808ef9ecd8): Accept \[u8; N\] bitmasks in simd_select_bitmask
* [cdae185](https://github.com/rust-lang/rustc_codegen_cranelift/commit/cdae185e3022b6e7c6c7fe363353fe1176a06604): Implement SHA-1 x86 vendor intrinsics
* [1ace86e](https://github.com/rust-lang/rustc_codegen_cranelift/commit/1ace86eb0be64a57e5df7f37e17b3cf5f414943d): Implement all x86 vendor intrinsics used by glam

#### Debuginfo

I've started implementing debuginfo support beyond the already existing line table support. Most primitive types are now described in the debuginfo tables. And the locations and types of statics are now encoded. For unsupported types `[u8; size_of::<T>()]` will be used as type instead. While debuginfo for statics may not be all that useful for most use cases, describing types is a prerequisite for debuginfo describing the locations of locals, which is very useful for debugging.

* [#1470](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1470): Various small debuginfo improvements
* [#1472](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1472): Add debuginfo for statics
* issue [#166](https://github.com/rust-lang/rustc_codegen_cranelift/issues/166): DWARF support

#### s390x support

A couple of fixes to the s390x support now allows compiling and testing cg_clif on s390x.

* [#1457](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1457): Fix simd_select_bitmask on big-endian systems (thanks @uweigand!)
* [#1458](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1458): Fix download hash check on big-endian systems (thanks @uweigand!)
* [b03b414](https://github.com/rust-lang/rustc_codegen_cranelift/commit/b03b41420b2dc900a9db019f4b5a5c22c05d2bb8): Fix stack alignment problem on s390x


# Challenges

#### SIMD

While `core::simd` is fully supported through emulation using scalar operations, many platform specific vendor intrinsics in `core::arch` are not supported. This has been improving though with the most important x86_64 and arm64 vendor intrinsics implemented.

If your program uses any unsupported vendor intrinsics you will get a compile time warning and if it actually gets reached, the program will abort with an error message indicating which intrinsic is unimplemented. Please open an issue if this happens.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding. I'm working on implementing this and integrating it with cg_clif.

Until this is fixed `panic::catch_unwind()` will not work and panicking in a single thread will abort the entire process just like `panic=abort` would. This also means you will have to use `-Zpanic-abort-tests` in combination with setting `panic = "abort"` if you want a test failure to not bring down the entire test harness.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

# Contributing

Contributions are always appreciated. Feel free to take a look at [good first issues](https://github.com/bjorn3/rustc_codegen_cranelift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) and ping me (@bjorn3) for help on either the relevant github issue or preferably on the [rust lang](https://rust-lang.zulipchat.com) zulip if you get stuck.
