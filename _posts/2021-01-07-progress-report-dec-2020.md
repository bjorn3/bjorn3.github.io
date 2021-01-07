---
layout: post
title:  "Progress report on rustc_codegen_cranelift (Dec 2020)"
date:   2021-01-07
categories: cranelift cg_clif rust
---

[Rustc_codegen_cranelift](https://github.com/bjorn3/rustc_codegen_cranelift) (cg_clif) is an alternative backend for rustc that I have been working on for the past two years. It uses the Cranelift code generator. Unlike LLVM which is optimized for output quality at the cost of compilation speed even when optimizations are disabled, Cranelift is optimized for compilation speed while producing executables that are almost as fast as LLVM with optimizations disabled. This has the potential to reduce the compilation times of rustc in debug mode.

Since the [last progress report](https://bjorn3.github.io/2020/09/28/progress-report-sep-2020.html) there have been [150 commits](https://github.com/bjorn3/rustc_codegen_cranelift/compare/0c065f95609e28cd3f2ddddccb06bf01705699cb...dbee13661efa269cb4cd57bb4c6b99a19732b484).

# Achievements in the past three months

#### Git subtree

In [rust#77975](https://github.com/rust-lang/rust/pull/77975) cg_clif was added as git subtree to the main rust repo. This PR makes it possible to compile cg_clif as part of rustc. As already mentioned in ["Fixing bootstrap of rustc using cg_clif"](https://bjorn3.github.io/2020/11/01/fixing-rustc-bootstrap-with-cg_clif.html) it is even possible to bootstrap rustc completely using cg_clif without LLVM. All you have to do is add `"cranelift"` to the `codegen-backends` array in `config.toml`. (Or completely replace `"llvm"` in the array if you don't want to compile the LLVM backend)

#### Lazy compilation in jit mode

It is now possible to select the lazy jit mode using `$cg_clif_dir/build/cargo.sh lazy-jit`. In this mode functions are only compiled when they are first called. This has the potential to significantly improve the startup time of a program. While functions have to be codegened when called, it is expected that a significant amount of all code is only required when an error occurs or only when the program is used in certain ways.

Thanks [@flodiebold](https://github.com/flodiebold) for the [suggestion](https://rust-lang.zulipchat.com/#narrow/stream/131828-t-compiler/topic/cranelift.20backend.20work/near/187645798) back in February.

This mode is not enabled by default as trying to lazily compile a function from a different thread than the main rustc thread will result in an ICE while parallel rustc is not yet enabled by default.

* [wasmtime#2249](https://github.com/bytecodealliance/wasmtime/pull/2249): Rework the interface of cranelift-module
* [wasmtime#2287](https://github.com/bytecodealliance/wasmtime/pull/2287): Some SimpleJIT improvements
* [wasmtime#2390](https://github.com/bytecodealliance/wasmtime/pull/2390): More SimpleJIT refactorings
* [wasmtime#2403](https://github.com/bytecodealliance/wasmtime/pull/2403): SimpleJIT hot code swapping
* [#1120](https://github.com/bjorn3/rustc_codegen_cranelift/pull/1120): Lazy compilation in jit mode

#### SIMD

Several new simd intrinsics have been implemented.

* commit [22c9623](https://github.com/bjorn3/rustc_codegen_cranelift/commit/22c9623604c6366e4783614244372cf1b31f7ca7): Implement simd_reduce_{add,mul}_{,un}ordered 
* commit [47ff2e0](https://github.com/bjorn3/rustc_codegen_cranelift/commit/47ff2e093238c80eb99ee612b8b591bf7adb5526): Implement float simd comparisons 
* commit [d2eeed4](https://github.com/bjorn3/rustc_codegen_cranelift/commit/d2eeed4ff577ee35693a32ae95f043f57c267cb3): Implement more simd_reduce_* intrinsics 
* commit [e99f78a](https://github.com/bjorn3/rustc_codegen_cranelift/commit/e99f78af0880edd5f56254236042f3c9ce0dce63): Make simd_extract panic at runtime on non-const index again
* commit [d95d03a](https://github.com/bjorn3/rustc_codegen_cranelift/commit/d95d03ae8ad10f253dce81a62a9ac372835b9bb4): Support #[repr(simd)] on array wrappers 

#### Runtime performance

A variety of peephole optimizations has been added to cg_clif. Combined this probably resulted in a speedup of ~5%. In addition now that [wasmtime#1080](https://github.com/bytecodealliance/wasmtime/issues/1080) has been fixed, it became possible to enable the optimizations of Cranelift itself.

* commit [3f47f93](https://github.com/bjorn3/rustc_codegen_cranelift/commit/3f47f938ba5303be9b6fe8c13aee6dce4aaa4b0b): Enable Cranelift optimizations when optimizing

# Challenges

While there are several important things currently missing, I am confident that I will be able to implement a significant portion in 2021.

#### ABI compatibility

There are many remaining ABI incomptibilities. I will need to rework cg_clif to reuse `rustc_target::abi::call::FnAbi`. I am currently working on a refactoring of the ABI handling code on the rustc side to make this easier. A part of this refactor has already landed.

* issue [#10](https://github.com/bjorn3/rustc_codegen_cranelift/issues/10): C abi compatability
* [rust#79067](https://github.com/rust-lang/rust/pull/79067): Refactor the abi handling code a bit

#### Switch to the new backend framework of Cranelift

Cranelift is currently switching to a new backend framework. This framework produces faster code and has support for AArch64. Currently there is no 128bit integer support for it though, which is necessary to compile libcore. There is however a draft PR by [@cfallin](https://github.com/cfallin) that is able to compile cg_clif. There is a miscompilation of simple-raytracer in release mode though. It is currently unknown if it is related to this PR.

* <https://cfallin.org/blog/2020/09/18/cranelift-isel-1/>
* [wasmtime#2504](https://github.com/bytecodealliance/wasmtime/pull/2504): Draft: I128 support (partial) on x64.

#### Atomics

Atomic instructions are currently emulated using a global lock. This is very inefficient and only works when pthreads is available. The new style backends for Cranelift have native support for atomic instructions. I will switch to them once I can use the new style backends.

* [wasmtime#2077](https://github.com/bytecodealliance/wasmtime/pull/2077): Implement Wasm Atomics for Cranelift/newBE/aarch64.
* [wasmtime#2149](https://github.com/bytecodealliance/wasmtime/pull/2149): This patch fills in the missing pieces needed to support wasm atomics...

#### SIMD

Many vendor intrinsics remain unimplemented. The new portable SIMD project will however likely exclusively use platform intrinsics or which there are much fewer compared to the LLVM intrinsics used to implement all vendor intrinsics in `core::arch`. In addition platform intrinsics are architecture independent, so they only have to be implemented once.

* issue [#171](https://github.com/bjorn3/rustc_codegen_cranelift/issues/171): std::arch SIMD intrinsics

#### Cleanup during stack unwinding on panics

Cranelift currently doesn't have support for cleanup during stack unwinding.

* issue [wasmtime#1677](https://github.com/bytecodealliance/wasmtime/issues/1677): Support cleanup during unwinding

#### Windows support

Various issues

* issue [#997](https://github.com/bjorn3/rustc_codegen_cranelift/issues/977): Windows support
* branch [wip_windows_support](https://github.com/bjorn3/rustc_codegen_cranelift/compare/wip_windows_support)

#### Maintenance

While there have been several PR's by other people, I am the only person who has contributed more than a few changes to cg_clif.

* <https://github.com/bjorn3/rustc_codegen_cranelift/pulls?q=is%3Apr+is%3Aclosed+-author%3Aapp%2Fdependabot-preview>

Thanks to [@jyn514](https://github.com/jyn514) for giving feedback on this post.
