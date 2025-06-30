---
layout: post
title: "Progress report on rustc_codegen_cranelift (June 2025)"
date: 2025-06-30
categories: cranelift cg_clif rust
---

There has been a fair bit of progress since the [last progress report](https://bjorn3.github.io/2024/11/14/progress-report-nov-2024.html)! There have been [476 commits](https://github.com/rust-lang/rustc_codegen_cranelift/compare/0b8e94eb69e0901b42e91c3b713207b33f4e46b2...c713ffab3c6e28ab4b4dd4e392330f786ea657ad) since the last progress report.

You can find a precompiled version of cg\_clif at <https://github.com/rust-lang/rustc_codegen_cranelift/releases/tag/dev> or in the rustc-codegen-cranelift-preview rustup component if you want to try it out.

# Achievements in the past 7 months

#### Unwinding

Cranelift has finally implemented support for cleanup during stack unwinding on Linux.

A little bit of history: As part of my bachelor thesis I finished a little under a year ago, I implemented support for unwinding in Cranelift. This was mostly working, however when I revisited the code after finishing writing of my thesis to get it upstreamed, I discovered that there were some cases where the register allocator would insert moves after a call instruction that can unwind and then expect these moves to be executed before jumping to any of the successors of the call instruction. This however can't happen when unwinding as unwinding directly jumps from the unwinding call to the exception handler block. I tried a bit to fix this, but got stuck on limitations in Cranelift's register allocator. In addition I got busy with my day job. Fast forward to about two months ago, when Chris Fallin (the main author of major parts of Cranelift) started implementing support for exception handling in Cranelift, fixing the limitations of the register allocator that I got stuck on in the process. The overall design is similar to my proposal, though the details of the Cranelift IR extensions are more elegant than what I previously came up with. I was able to rebase the cg\_clif changes from my thesis on top of the newly landed Cranelift changes with minor effort after a couple of small fixes on the Cranelift side. Thanks a lot for working on unwinding support for Cranelift, Chris!

A walkthrough of how unwinding is actually implemented in cg\_clif can be found at <https://tweedegolf.nl/en/blog/157/exception-handling-in-rustc-codegen-cranelift>.

Unwinding support in cg\_clif will remain disabled by default for now pending investigation of some build performance issues. In addition it currently doesn't work on Windows and macOS. On macOS there are some minor differences around the exact encoding of the unwinding tables that haven't been implemented yet. On Windows adding support will be a fair bit more complicated however. Windows uses the funclets based SEH rather than the landingpads based itanium unwinding (`.eh_frame`) for unwinding. Cranelift only supports landingpads.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding
* [bytecodealliance/rfcs#36](https://github.com/bytecodealliance/rfcs/pull/36): Implementing the exception handling proposal in Wasmtime
* issue [#1567](https://github.com/rust-lang/rustc_codegen_cranelift/issues/1567): Support unwinding on panics
* [wasmtime#10485](https://github.com/bytecodealliance/wasmtime/pull/10485): Cranelift: remove block params on critical-edge blocks. (thanks @cfallin!)
* [wasmtime#10502](https://github.com/bytecodealliance/wasmtime/pull/10502): Cranelift: remove return-value instructions after calls at callsites. (thanks @cfallin!)
* [wasmtime#10510](https://github.com/bytecodealliance/wasmtime/pull/10510): Cranelift: initial try\_call / try\_call\_indirect (exception) support. (thanks @cfallin!)
* [wasmtime#10593](https://github.com/bytecodealliance/wasmtime/pull/10593): Some fixes for try\_call
* [wasmtime#10609](https://github.com/bytecodealliance/wasmtime/pull/10609): Cranelift: move exception-handler metadata into callsites. (by me and @cfallin)
* [wasmtime#10702](https://github.com/bytecodealliance/wasmtime/pull/10702): Avoid clobbering all float registers in the presence of try_call on arm64
* [wasmtime#10709](https://github.com/bytecodealliance/wasmtime/pull/10709): Cranelift: fix invalid regalloc constraints on try-call with empty handler list. (thanks @cfallin!)
* [ab514c9](https://github.com/rust-lang/rustc_codegen_cranelift/commit/ab514c95967a7c5d732aa1e3800afc4d9cb252f9): Pass UnwindAction to a couple of functions
* [9495eb5](https://github.com/rust-lang/rustc_codegen_cranelift/commit/9495eb517e5a2b76fcdb514eeec5aa4d8fd16320): Pass Module to UnwindContext
* [#1575](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1575): Preparations for exception handling support
* [#1584](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1584): Experimental exception handling support on Linux

#### ARM

CI now builds and tests on native arm64 Linux systems rather than testing a subset of the tests in QEMU. Inline asm on arm64 can now use vector registers. And the half and bytecount crates are now fixed on arm64.

* [#1557](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1557): Test and dist for arm64 linux on CI
* [#1564](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1564): Fix usage of vector registers in inline asm on arm64
* [#1566](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1566): Fix the half and bytecount crates on arm64

#### f16/f128 support

@beetrees contributed support for the unstable f16 and f128 types.

* [wasmtime#8860](https://github.com/bytecodealliance/wasmtime/pull/8860): Initial f16 and f128 support (thanks @beetrees!)
* [wasmtime#9045](https://github.com/bytecodealliance/wasmtime/pull/9045): Add initial f16 and f128 support to the x64 backend (thanks @beetrees!)
* [wasmtime#9076](https://github.com/bytecodealliance/wasmtime/pull/9076): Add initial f16 and f128 support to the aarch64 backend (thanks @beetrees!)
* [wasmtime#10652](https://github.com/bytecodealliance/wasmtime/pull/10652): Add inital support for f16 without Zfh and f128 to the riscv64 backend (thanks @beetrees!)
* [wasmtime#10691](https://github.com/bytecodealliance/wasmtime/pull/10691): Add initial f16 and f128 support to the s390x backend (thanks @beetrees!)
* [#1574](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1574): Add f16/f128 support (thanks @beetrees!)

#### Sharing code between codegen backends

I've made two PR's to rustc to share more code between codegen backends. This reduces the maintenance burden of both cg\_clif and rustc. In the future I would like to migrate the entire inline asm handling of cg\_clif to cg\_ssa to be used as fallback for codegen backends that don't natively support inline asm.

* [rust#132820](https://github.com/rust-lang/rust/pull/132820): Add a default implementation for CodegenBackend::link
* [rust#134232](https://github.com/rust-lang/rust/pull/134232): Share the naked asm impl between cg\_ssa and cg\_clif
* [rust#141769](https://github.com/rust-lang/rust/pull/141769): Move metadata object generation for dylibs to the linker code

#### SIMD

Some new vendor intrinsics were implemented.

* [b004312](https://github.com/rust-lang/rustc_codegen_cranelift/commit/b004312ee4c8418e5a42cc25b971fa5fc5ac88b7): Implement arm64 vaddlvq\_u8 and vld1q\_u8\_x4 vendor intrinsics
* [1afce7c](https://github.com/rust-lang/rustc_codegen_cranelift/commit/1afce7c3548ff31174cb060f3217b1994d982bed): Implement simd\_insert\_dyn and simd_extract_dyn intrinsics
* [49bfa1a](https://github.com/rust-lang/rustc_codegen_cranelift/commit/49bfa1aaf5f7e68079e6ed9b0d23dacebf38bac9): Fix simd\_insert\_dyn and simd\_extract\_dyn intrinsics with non-pointer sized indices

#### ABI

ABI handling for 128bit integers libcalls has been improved. In addition the abi-cafe version we test against has been updated to 1.0. Thanks to a bunch of new features it has, we no longer need to patch it's source code, making it easier to do future updates.

* [#1546](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1546): Fix the ABI for libcalls
* [#1582](https://github.com/rust-lang/rustc_codegen_cranelift/pull/1582): Update to abi-cafe 1.0
* [b7cfe2f](https://github.com/rust-lang/rustc_codegen_cranelift/commit/b7cfe2f4db9e7740f6302a1627d1c087054e64b4): Use the new --debug flag of abi-cafe

# Challenges

#### SIMD

While `core::simd` is fully supported through emulation using scalar operations, many platform specific vendor intrinsics in `core::arch` are not supported. This has been improving though with the most important x86\_64 and arm64 vendor intrinsics implemented.

If your program uses any unsupported vendor intrinsics you will get a compile time warning and if it actually gets reached, the program will abort with an error message indicating which intrinsic is unimplemented. Please open an issue if this happens.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### ABI

There are still several remaining ABI compatibility issues with LLVM. On arm64 Linux there is a minor incompatibility with the C ABI, but the Rust ABI works just fine. On arm64 macOS there are several ABI incompatibilities that affect the Rust ABI too, so mixing cg\_clif and cg\_llvm there isn't recommended yet. And on x86\_64 Windows there is also an incompatibility around return values involving i128. I'm slowly working on fixing these.

* issue [#1525](https://github.com/rust-lang/rustc_codegen_cranelift/issues/1525): Tracking issue for abi-cafe failures

# Contributing

Contributions are always appreciated. Feel free to take a look at [good first issues](https://github.com/rust-lang/rustc_codegen_cranelift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) and ping me (@bjorn3) for help on either the relevant github issue or preferably on the [rust lang](https://rust-lang.zulipchat.com) zulip if you get stuck.
