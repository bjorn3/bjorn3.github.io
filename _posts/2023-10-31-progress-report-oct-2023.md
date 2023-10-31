---
layout: post
title: "Progress report on rustc_codegen_cranelift (Oct 2023)"
date: 2023-10-31
categories: cranelift cg_clif rust
---

Quite some exciting progress since the [last progress report](https://bjorn3.github.io/2023/07/29/progress-report-july-2023.html)! There have been [180 commits](https://github.com/rust-lang/rustc_codegen_cranelift/compare/6641b3a548a425eae518b675e43b986094daf609...9a33f82140c6da6e5808253309c674554b93e9fe) since the last progress report.

As of today, rustc_codegen_cranelift is available on nightly! :tada: You can run `rustup component add rustc-codegen-cranelift-preview --toolchain nightly` to install it and then either `CARGO_PROFILE_DEV_CODEGEN_BACKEND=cranelift cargo +nightly build -Zcodegen-backend` to use it for the current invocation or add

```toml
[unstable]
codegen-backend = true

[profile.dev]
codegen-backend = "cranelift"
```

to `.cargo/config.toml` or

```toml
# This line needs to come before anything else in Cargo.toml
cargo-features = ["codegen-backend"]

[profile.dev]
codegen-backend = "cranelift"
```

to `Cargo.toml` to enable it by default for debug builds. You can also set `codegen-backend` for individual packages using `[profile.dev.package.my_program] codegen-backend = "cranelift"`. This would for example allow building a game engine using LLVM all optimizations enabled, but your game logic using Cranelift for faster iteration.

The following targets are currently supported:

* x86_64-unknown-linux-gnu
* x86_64-unknown-linux-musl
* x86_64-apple-darwin
* aarch64-unknown-linux-gnu
* aarch64-unknown-linux-musl

Windows support has been omitted for now. And for macOS currently on supports x86_64 as Apple invented their own calling convention for arm64 for which variadic functions can't easily be implemented as hack. If you are using an M1 processor, you could try installing the x86_64 version of rustc and then using Rosetta 2. Rosetta 2 will hurt performance though, so you will need to try if it is faster than the LLVM backend with arm64 rustc.

Also be aware that there are currently still some [missing features](#challenges).

# Achievements in the past three months

#### Distributing as rustup component

As I already indicated at the start of this progress report, cg_clif is now available as rustup component.

* [rust-lang/rust#81746](https://github.com/rust-lang/rust/pull/81746): Distribute cg_clif as rustup component on the nightly channel

#### Moved to the rust-lang org

Rustc_codegen_cranelift is now part of the rust-lang github organization: <https://github.com/rust-lang/rustc_codegen_cranelift/>

#### Risc-V support

While Cranelift has had a riscv64 backend for a couple of months now, only recently some of the features have been implemented as well as some bug fixes have been done by @afonso360 to make cg_clif work on linux riscv64gc. Once that was done I only needed to add inline assembly support for riscv64.

* [#1398](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1398): Add riscv64 linux support

#### SIMD

A whole bunch more x86_64 and arm64 vendor intrinsics have been implemented. This includes arm64 vendor intrinsics used by newer regex versions and the x86_64 vendor intrinsics used by rav1e and image. In addition a bunch of the new platform independent simd intrinsics used by `std::simd` have been implemented. The hack to disable detection of target features using `is_x86_feature_detected!()` has now been removed when inline asm support is enabled. This hack never worked when using a standard library compiled by LLVM anyway and enough vendor intrinsics are now supported to not need it anymore most of the time.

* [c974bc8](https://github.com/rust-lang/rustc_codegen_cranelift/commit/c974bc89b874fa5a46dfb2db8e983d4b864e42c5): Update regex and implement necessary AArch64 vendor intrinsics
* [f1ede97](https://github.com/rust-lang/rustc_codegen_cranelift/commit/f1ede97b145c084b14579c467c4276d247193adf): Update portable-simd test and implement new simd_* platform intrinsics
* [e5ba1e8](https://github.com/rust-lang/rustc_codegen_cranelift/commit/e5ba1e84171899aa99b4ba6c1b5d4eef3873592a): Implement llvm intrinsics necessary for rav1e
* [a558968](https://github.com/rust-lang/rustc_codegen_cranelift/commit/a558968dbe962b1daa730426d001becebd102931): Implement all llvm intrinsics necessary for the image crate

#### Inline assembly

Inline assembly is now supported on arm64 and riscv64 as well as macOS and Windows. Futhermore support for inline assembly is now being tested in cg_clif's CI. With the exception of `sym` operands, inline assembly is now declared as stable for usage with cg_clif.

* [#1396](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1396): Support inline asm on AArch64
* [#1397](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1397): Test inline asm support on CI
* issue [#1204](https://github.com/rust-lang/rustc_codegen_cranelift/issues/1204): Full asm!() support
* [#1403](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1403): Support and stabilize inline asm on all platforms

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
