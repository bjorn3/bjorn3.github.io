---
layout: post
title: "Progress report on rustc_codegen_cranelift (July 2023)"
date: 2023-07-29
categories: cranelift cg_clif rust
---

It has been quite a while since the [last progress report](https://bjorn3.github.io/2022/10/12/progress-report-okt-2022.html). A ton of progress has been made since then, but I simply didn't get around writing a new progress report. There have been [639 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/69297f9c863f0e153d10447685b9a2cc34f60d57...6641b3a548a425eae518b675e43b986094daf609) since the last progress report. This is significantly more than the last time given how long there has been since the last progress report. As such I skimmed the commit list to see what stood out to me. I may have missed some important things.

You can find a precompiled version of cg_clif at <https://github.com/bjorn3/rustc_codegen_cranelift/releases/tag/dev> if you want to try it out.

# Achievements in the past nine months

#### Perf improvements

Debug assertions were accidentally enabled for the precompiled dev releases. Disabling them significantly improved performance from a ~13% improvement of cg_clif over cg_llvm to a ~39% improvement on one benchmark. Local builds have not been affected by this issue.

* [#1347](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1347): Build CI dist artifacts without debug assertions

#### SIMD

A lot of vendor intrinsics have been implemented. The regex crate now works on AVX2 systems without cg_clif's hack to make `is_x86_feature_detected!()` hide all features other than SSE and SSE2. This hack doesn't work when the standard library is compiled using cg_llvm as will be the case when cg_clif gets distributed with rustup.

* [#1297](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1297): Implement some AArch64 SIMD intrinsics
* [#1309](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1309): Implement simd_gather and simd_scatter
* [#1378](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1378): Implement all vendor intrinsics used by regex on AVX2 systems
* [e4d0811](https://github.com/bjorn3/rustc_codegen_cranelift/commit/e4d0811360e79b2789f27a65eed7d3248e1e092c): Implement _mm_srli_epi16 and _mm_slli_epi16
* [c09ef96](https://github.com/bjorn3/rustc_codegen_cranelift/commit/c09ef968782c8ada9aa5427605b1b7925ac60d32): Implement _mm_shuffle_epi8
* [#1380](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1380): Implement a whole bunch more x86 vendor intrinsics

#### Build system rework

The build system has seen a significant rework to allow using it to test a precompiled cg_clif version and to allow vendoring of everything for offline builds. This was a requirement to testing cg_clif in rust's CI. A PR is open to run part of cg_clif's tests in rust's CI.

* [#1291](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1291): Move downloaded test project to downloads/
* [#1298](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1298): Introduce CargoProject type and use it where possible
* [#1300](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1300): Rename the build/ directory to dist/
* [#1302](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1302): Allow specifying where build artifacts should be written to
* [#1338](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1338): Avoid clobbering build_system/ and ~/.cargo/bin
* [#1339](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1339): Many build system improvements
* [#1340](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1340): Push up a lot of rustc and cargo references
* [#1341](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1341): Refactor sysroot building
* [#1374](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1374): Allow building and testing without rustup
* [5b3bc29](https://github.com/bjorn3/rustc_codegen_cranelift/commit/5b3bc29008643203b4de3ffb4c5b5141039c88e6): Allow testing a cranelift backend built into rustc itself
* [134dc33](https://github.com/bjorn3/rustc_codegen_cranelift/commit/134dc334857e453c50f8ea31b13cbda106204f20): Fix testing with unstable features disabled
* [#1357](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1357): Support testing of cg_clif in rust's CI
* [rust#112701](https://github.com/rust-lang/rust/pull/112701): Run part of cg_clif's tests in CI (not yet merged)

#### Inline assembly

`const` operands for `inline_asm!()` and `global_asm!()` are now supported. `sym` operands work in some cases, but if rustc decides to make the respective function private to the codegen unit it is contained in, you will get a linker error as inline asm ends up in a separate codegen unit while rustc thinks it ends up in the same codegen unit.

* [#1350](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1350): Implement const and sym operands for inline asm
* [#1351](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1351): Implement const and sym operands for global asm

#### s390x support tested in CI

@afonso360 contributed CI support for testing s390x.

* [#1304](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1304): Add S390X CI Support

#### Archive writer

As I already pointed out in a [previous](https://bjorn3.github.io/2022/06/13/progress-report-june-2022.html#migrating-away-from-rust-ar) progress report I had been working on switching out the archive writer from a fork of rust-ar to a rewrite of LLVM's archive writer. This work has since been completed. The LLVM backend still uses LLVM's original version because a couple of regressions were found in the integration with rustc. I plan to fix those issues and switch the LLVM backend to the rust rewrite some time in the future.

* [#1155](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1155): Remove the ar git dependency
* [rust#97485](https://github.com/rust-lang/rust/pull/97485): Rewrite LLVM's archive writer in Rust

#### Benchmark improvements

Release builds of simple-raytracer are now benchmarked too. Release builds are slower but should still be faster than the LLVM backend. At the same time the resulting executables are about 20% faster and for simple-raytracer faster than LLVM in debug mode.

CI runs now also show the benchmark results if you scroll down on the overview page of the workflow run. See for example <https://github.com/bjorn3/rustc_codegen_cranelift/actions/runs/5645453142>.

* [#1373](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1373): Benchmark clif release builds with ./y.rs bench
* [448b7a3](https://github.com/bjorn3/rustc_codegen_cranelift/commit/448b7a3a12e6e76547c95cd327d83b2c7dff3c65): Record GHA step summaries for benchmarking


# Challenges

#### SIMD

While `core::simd` is fully supported through emulation using scalar operations, many platform specific vendor intrinsics in `core::arch` are not supported. This has been improving though with the most important (as far as the regex crate and its dependencies are concerned) x86 vendor intrinsics implemented.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding. I'm working on implementing this and integrating it with cg_clif.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

#### Distributing as rustup component

There is progress towards distributing cg_clif as a rustup component. For example a decent amount of SIMD vendor intrinsics are now implemented and there is an open PR to run part of cg_clif's test suite on rust's CI. There are still things to be done though. https://github.com/bjorn3/rustc_codegen_cranelift/milestone/2 lists things I know of that still need to be done.

# Contributing

Contributions are always appreciated. Feel free to take a look at [good first issues](https://github.com/bjorn3/rustc_codegen_cranelift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) and ping me (@bjorn3) for help on either the relevant github issue or preferably on the [rust lang](https://rust-lang.zulipchat.com) zulip if you get stuck.
