---
layout: post
title:  "Fixing bootstrap of rustc using cg_clif"
date:   2020-11-01
categories: cg_clif rust debugging
---

Six days ago [rust-lang/rust#77975](https://github.com/rust-lang/rust/pull/77975) was merged. This PR makes it possible to build cg_clif as part of rustc using the following config:

```toml
[rust]
codegen-backends = ["llvm", "cranelift"]
```

In the past I have succeeded in bootstrapping rustc using cg_clif by omitting `llvm` from `codegen-backends`. This has unfortunately regressed since. The produced rustc currently hangs while building libcore. I think it can be interesting to explain how I went to debug this issue and fixing it.

To reproduce the issue, you first need to apply the following patch to disable inline asm usage in parking_lot:

```diff
diff --git a/compiler/rustc_data_structures/Cargo.toml b/compiler/rustc_data_structures/Cargo.toml
index 23e689fcae7..5f077b765b6 100644
--- a/compiler/rustc_data_structures/Cargo.toml
+++ b/compiler/rustc_data_structures/Cargo.toml
@@ -32,7 +32,6 @@ tempfile = "3.0.5"
 
 [dependencies.parking_lot]
 version = "0.11"
-features = ["nightly"]
 
 [target.'cfg(windows)'.dependencies]
 winapi = { version = "0.3", features = ["fileapi", "psapi"] }
```

Then you can build using:

```bash
$ cat > config.toml <<EOF
[build]
full-bootstrap = true

[rust]
codegen-backends = ["cranelift"]
EOF
$ ./x.py build --stage 2
```

This successfully builds a rustc binary using cg_clif. You can find it in `build/$target/stage2/bin/rustc`. It hangs while compiling `libcore`. The first thing to do is check if it can actually run:

```bash
$ ./build/$target/stage2/bin/rustc -V
rustc 1.49.0-dev
```

That works. Next I tried to compile `mini_core` and `mini_core_hello_world` from the cg_clif test suite. First `mini_core`:

```bash
$ time ./build/$target/stage2/bin/rustc compiler/rustc_codegen_cranelift/example/mini_core.rs --crate-type lib
./build/$target/stage2/bin/rustc  --crate-type lib  1,45s user 0,02s system 99% cpu 1,472 total
```

A bit slow, but that is expected from an unoptimized rustc. Next up `mini_core_hello_world`:

```bash
$ time ./build/$target/stage2/bin/rustc compiler/rustc_codegen_cranelift/example/mini_core_hello_world.rs -L.
^C
./build/$target/stage2/bin/rustc  -L.  10,07s user 0,02s system 99% cpu 10,099 total
```

That one hangs. Lets try to get a few backtraces while it hangs:

```bash
$ gdb --args ./build/$target/stage2/bin/rustc compiler/rustc_codegen_cranelift/example/mini_core_hello_world.rs -L.
(gdb) run
^C
(gdb) thread apply all bt

Thread 2 (Thread 0x7f99869096f8 (LWP 11698)):
#1  0x00007f99869096f8 in <u64 as compiler_builtins::int::Int>::overflowing_add ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/libstd-fa031f8594e3722d.so
#2  0x00007f99869035a3 in compiler_builtins::int::addsub::UAddSub::uadd () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/libstd-fa031f8594e3722d.so
#3  0x00007f9986903865 in compiler_builtins::int::addsub::AddSub::add () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/libstd-fa031f8594e3722d.so
#4  0x00007f9986903b65 in compiler_builtins::int::addsub::Addo::addo () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/libstd-fa031f8594e3722d.so
#5  0x00007f9986903fd4 in compiler_builtins::int::addsub::__rust_u128_addo () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/libstd-fa031f8594e3722d.so
#6  0x00007f9986907c0e in __rust_u128_addo () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/libstd-fa031f8594e3722d.so
#7  0x00007f9991cd9311 in core::num::<impl u128>::overflowing_add () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#8  0x00007f9991cde20a in rustc_apfloat::ieee::sig::add () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#9  0x00007f9991cdf33b in rustc_apfloat::ieee::sig::widening_mul () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#10 0x00007f998b1959a8 in rustc_apfloat::ieee::IeeeFloat<S>::from_decimal_string ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#11 0x00007f998b1b904c in <rustc_apfloat::ieee::IeeeFloat<S> as rustc_apfloat::Float>::from_str_r ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#12 0x00007f998b1bb76a in <rustc_apfloat::ieee::IeeeFloat<S> as core::str::traits::FromStr>::from_str ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#13 0x00007f998b171927 in core::str::<impl str>::parse () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#14 0x00007f998b1902af in rustc_mir_build::thir::constant::parse_float ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#15 0x00007f998b18f570 in rustc_mir_build::thir::constant::lit_to_const ()
[...]
(gdb) cont
^C
(gdb) thread apply all bt

Thread 2 (Thread 0x7f9991ce15d0 (LWP 11698)):
#0  0x00007f9991ce15d0 in core::slice::iter::Iter<T>::new () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#1  0x00007f9991ce1588 in core::slice::<impl [T]>::iter () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#2  0x00007f9991ce179a in core::slice::iter::<impl core::iter::traits::collect::IntoIterator for &[T]>::into_iter ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#3  0x00007f9991cda180 in core::iter::traits::iterator::Iterator::zip ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#4  0x00007f9991cde0cd in rustc_apfloat::ieee::sig::add () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#5  0x00007f9991cdf33b in rustc_apfloat::ieee::sig::widening_mul () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#6  0x00007f998b1959a8 in rustc_apfloat::ieee::IeeeFloat<S>::from_decimal_string ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#7  0x00007f998b1b904c in <rustc_apfloat::ieee::IeeeFloat<S> as rustc_apfloat::Float>::from_str_r ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#8  0x00007f998b1bb76a in <rustc_apfloat::ieee::IeeeFloat<S> as core::str::traits::FromStr>::from_str ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#9  0x00007f998b171927 in core::str::<impl str>::parse () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#10 0x00007f998b1902af in rustc_mir_build::thir::constant::parse_float ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
#11 0x00007f998b18f570 in rustc_mir_build::thir::constant::lit_to_const ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
[...]
```

In both cases we see that it is currently inside `rustc_apfloat::ieee::sig::widening_mul`. Let's see if this function ever returns using `finish`:

```bash
(gdb) thread 2
[Switching to thread 2 (Thread 0x7f9991ce15d0 (LWP 11698))]
(gdb) frame 5
#5  0x00007f9991cdf33b in rustc_apfloat::ieee::sig::widening_mul () from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
(gdb) finish
Run till exit from #5  0x00007f9991cdf33b in rustc_apfloat::ieee::sig::widening_mul ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
0x00007f998b1959a8 in rustc_apfloat::ieee::IeeeFloat<S>::from_decimal_string ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
```

It returns, next try:

```bash
(gdb) finish
Run till exit from #0  0x00007f9991cdf33b in rustc_apfloat::ieee::IeeeFloat<S>::from_decimal_string ()
   from /home/bjorn/Documenten/rust/build/x86_64-unknown-linux-gnu/stage2/bin/../lib/librustc_driver-e6ad613079f085f8.so
^C
Thread 1 "rustc" received signal SIGINT, Interrupt.
[Switching to Thread 0x7fffe0933200 (LWP 11693)]
0x00007fffe0cac495 in __GI___pthread_timedjoin_ex (threadid=140736961124096, thread_return=0x0, abstime=0x0, block=<optimized out>) at pthread_join_common.c:89
89      in pthread_join_common.c
```

Gotcha! It hangs in `from_decimal_string`. Let's try to come up with a test that doesn't require running a rustc compiled using cg_clif. First up let's reduce `mini_core_hello_world.rs` step by step until a minimal reproducing example. This results in:

```rust
#![feature(no_core, start, lang_items)]
#![no_core]

extern crate mini_core;

#[start]
fn start(_argc: isize, _argv: *const *const u8) -> isize {
    take_f32(0.1);
    0
}

fn take_f32(_f: f32) {}
```

As expected due to `from_decimal_string` being the function that hangs, it requires a float literal to be present.

Let's try to run the test suite of `rustc_apfloat` using cg_clif to see if anything fails.

```bash
$ cd compiler/rustc_apfloat
$ ../../../cg_clif/cargo.sh test
failures:

---- convert stdout ----
---- convert stderr ----
Unexpected error: child process exited with signal 4
---- decimal_strings_without_null_terminators stdout ----
---- decimal_strings_without_null_terminators stderr ----
Unexpected error: child process exited with signal 4
---- denormal stdout ----
---- denormal stderr ----
Unexpected error: child process exited with signal 4
---- exact_inverse stdout ----
---- exact_inverse stderr ----
Unexpected error: child process exited with signal 4
---- from_decimal_string stdout ----
---- from_decimal_string stderr ----
Unexpected error: child process exited with signal 4
---- fma stdout ----
---- fma stderr ----
Unexpected error: child process exited with signal 4
---- modulo stdout ----
---- modulo stderr ----
Unexpected error: child process exited with signal 4
---- multiply stdout ----
---- multiply stderr ----
Unexpected error: child process exited with signal 4
---- neg stdout ----
---- neg stderr ----
Unexpected error: child process exited with signal 4
---- operator_overloads stdout ----
---- operator_overloads stderr ----
Unexpected error: child process exited with signal 4
---- to_integer stdout ----
---- to_integer stderr ----
Unexpected error: child process exited with signal 4
---- to_string stdout ----
---- to_string stderr ----
Unexpected error: child process exited with signal 4

failures:
    convert
    decimal_strings_without_null_terminators
    denormal
    exact_inverse
    fma
    from_decimal_string
    modulo
    multiply
    neg
    operator_overloads
    to_integer
    to_string

test result: FAILED. 37 passed; 12 failed; 0 ignored; 0 measured; 0 filtered out
```

Hmm, it doesn't hang, but instead crashes. Upon further inspection these errors turn out to be caused by [#1063](https://github.com/bjorn3/rustc_codegen_cranelift/issues/1063), which causes `x * 0` to crash for 128bit ints when debug assertions are enabled. I couldn't reproduce the hang. Even when adding a test with `"0.1".parse::<Single>()`, which is what should have been hanging in rustc. After a bit of fiddling I eventually ran the test suite in release mode:

```bash
$ ../../../cg_clif/cargo.sh test --release
[...]
     Running /home/bjorn/Documenten/rust/target/release/deps/ieee-bb5cab6348b645f9

running 50 tests
test add ... ok
test abs ... ok
test copy_sign ... ok
test divide ... ok
^C
```

So, the hang only exists in release mode. It can't be caused by #1063, as that only is a bug specific to the checked multiplication implementation for 128bit integers in compiler_builtins that always causes a crash in an edge case and otherwise doesn't cause any problems. This bug however doesn't cause a crash.

We can reduce the rustc_apfloat test suite based on the earlier observation about the failing command in rustc:

```rust
use rustc_apfloat::ieee::Single;

#[test]
fn rustc_repro() {
    let _ = "0.1".parse::<Single>();
}
```

Now let's reduce `rustc_apfloat` until we get a minimal repro. As a first step we can remove all comments using the regex `^ *//.*\n`. Then run `cargo fmt` to tidy up the source a bit. Now we can remove functions step by step while keeping our test compiling. The `ppc` module is not used by our test, so we can remove it together with its test file. The `Half`, `Double` and `Quad` types are not used either, so these can be removed too. I went on so for a while until I reduced it to 1087 lines. After that it wasn't possible to remove unused functions anymore and instead I had to begin replacing unreached if branches with `unreachable!()`. After a while I had reduced it to less than 850 lines. While reducing I tested against cg_llvm, not cg_clif to ensure that I didn't accidentally introduced an `unreachable!()` that is actually reachable. When I tested against cg_clif again it succeeded. This meant that I had to revert a few changes. It also indicated that the bug isn't a simple wrong implementation of 128bit integers like I expected, but a much more severe miscompilation.

> The reduction at this point can be found at <https://gist.github.com/bjorn3/de955bd055b0dbd10ba97cac700ec484>.

After a lot more of attempting to reduce it I got the following:

```rust
#[test]
fn from_decimal_string() {
    loop {
        let multiplier = 1;

        take_multiplier_ref(&multiplier);

        if multiplier == 1 {
            break;
        }

        unreachable();
    }
}

fn take_multiplier_ref(_multiplier: &u128) {}

fn unreachable() -> ! {
    unreachable!();
}
```

`multiplier` is set to 1, so it should break from the loop, yet it continues to `unreachable()`. (I put the `unreachable!()` macro invocation into a `unreachable()` wrapper to reduce the amount of MIR and thus clif ir generated for `from_decimal_string`.)

Next I requested the mir and clif ir by passing `--emit mir,llvm-ir` to rustc. (Yes, I hijacked the llvm-ir emit option for clif-ir) This resulted in the following for `from_decimal_string` after enabling [a piece of code](https://github.com/bjorn3/rustc_codegen_cranelift/blob/34be539ca44c198cfc02048e7decebbe37e810f7/src/base.rs#L428) and cleaning up the result a bit:

```rust
fn from_decimal_string() -> () {
    let mut _0: ();
    let _1: u128;
    let _2: ();
    let mut _3: &u128;
    let _4: &u128;
    let mut _5: u128;
    scope 1 {
        debug multiplier => _1;
    }

    bb0: {
        _1 = const 1_u128;
        _4 = &_1;
        _3 = _4;
        _2 = take_multiplier_ref(move _3) -> bb1;
    }

    bb1: {
        _5 = _1;
        switchInt(move _5) -> [1_u128: bb3, otherwise: bb2];
    }

    bb2: {
        unreachable();
    }

    bb3: {
        _0 = const ();
        return;
    }
}
```

```
function u0:99() system_v {
; symbol _ZN4ieee19from_decimal_string17h1c65ca117ebb56f7E
; instance Instance { def: Item(WithOptConstParam { did: DefId(0:8 ~ ieee[317d]::from_decimal_string#1), const_param_did: None }), substs: [] }
; sig ([]; c_variadic: false)->()

; kind  loc.idx   param    pass mode                            ty
; ret   _0      -          NoPass                               ()

; kind  local ty                              size align (abi,pref)
; stack _1    u128                             16b 8, 8              storage=ss0
; zst   _2    ()                                0b 1, 8              align=8,offset=
; ssa   _3    &u128                             8b 8, 8              ,var=0
; ssa   _4    &u128                             8b 8, 8              ,var=1
; ssa   _5    u128                             16b 8, 8              ,var=2

    ss0 = explicit_slot 16
    gv0 = symbol colocated u1:23 ; trap at Instance { def: Item(WithOptConstParam { did: DefId(0:8 ~ ieee[317d]::from_decimal_string#1), const_param_did: None }), substs: [] } (_ZN4ieee19from_decimal_string17h1c65ca117ebb56f7E): [corruption] Diverging function returned
    sig0 = (i64) system_v
    sig1 = () system_v
    sig2 = (i64) -> i32 system_v
    fn0 = colocated u0:96 sig0 ; Instance { def: Item(WithOptConstParam { did: DefId(0:3 ~ ieee[317d]::take_multiplier_ref), const_param_did: None }), substs: [] }
    fn1 = colocated u0:97 sig1 ; Instance { def: Item(WithOptConstParam { did: DefId(0:4 ~ ieee[317d]::unreachable), const_param_did: None }), substs: [] }
    fn2 = u0:103 sig2 ; puts

block0:
    nop 
    jump block1

block1:
    nop 
; _1 = const 1_u128
    v0 = iconst.i64 1
    v1 = iconst.i64 0
    v2 = iconcat v0, v1
; write_cvalue: Addr(Pointer { base: Stack(ss0), offset: Offset32(0) }, None): u128 <- ByVal(v2): u128
    v3 = stack_addr.i64 ss0
    store notrap v2, v3
; _4 = &_1
    v4 = stack_addr.i64 ss0
; write_cvalue: Var(_4, Variable(1)): &u128 <- ByVal(v4): &u128
; _3 = _4
; write_cvalue: Var(_3, Variable(0)): &u128 <- ByVal(v4): &u128
; 
; _2 = take_multiplier_ref(move _3)
    call fn0(v4)
    jump block2

block2:
    nop 
; _5 = _1
; write_cvalue: Var(_5, Variable(2)): u128 <- ByRef(Pointer { base: Stack(ss0), offset: Offset32(0) }, None): u128
    v5 = stack_addr.i64 ss0
    v6 = load.i128 notrap v5
; 
; switchInt(move _5)
    v7 = icmp_imm eq v6, 1
    brnz v7, block4
    jump block3

block3:
    nop 
; 
; unreachable()
    call fn1()
    v8 = global_value.i64 gv0
    v9 = call fn2(v8)
    trap unreachable

block4:
    nop 
; _0 = const ()
; write_cvalue: Addr(Pointer { base: Dangling(Align { pow2: 3 }), offset: Offset32(0) }, None): () <- ByRef(Pointer { base: Dangling(Align { pow2: 3 }), offset: Offset32(0) }, None): ()
; 
; return
    return
}
```

This didn't make the problem any clearer, but when I looked at the clif ir after [legalization] the problem stood out. `v7 = icmp_imm eq v6, 1` got lowered to:

[legalization]: https://cfallin.org/blog/2020/09/18/cranelift-isel-1/#old-backend-design-instruction-legalizations

```
    v6 = iconcat v12, v13
; 
; switchInt(move _5)
    v14 = iconst.i64 1
    v15 = iconst.i64 1
    v18 = icmp eq v12, v14
    v19 = icmp eq v13, v15
    v7 = band v18, v19
```

Notice how it uses the constant 1 twice, instead of 1 and 0. It was comparing against 0x0000_0000_0000_0001_0000_0000_0000_0001 instead of 1. The fix was a one line patch:

```diff
diff --git a/cranelift/codegen/src/legalizer/mod.rs b/cranelift/codegen/src/legalizer/mod.rs
index 3b33e55b1..825b3c20e 100644
--- a/cranelift/codegen/src/legalizer/mod.rs
+++ b/cranelift/codegen/src/legalizer/mod.rs
@@ -779,7 +779,7 @@ fn narrow_icmp_imm(
         .iconst(ty_half, imm & ((1u128 << ty_half.bits()) - 1) as i64);
     let imm_high = pos
         .ins()
-        .iconst(ty_half, imm.wrapping_shr(ty_half.bits().into()));
+        .iconst(ty_half, imm.checked_shr(ty_half.bits().into()).unwrap_or(0));
     let (arg_low, arg_high) = pos.ins().isplit(arg);
 
     match cond {

```

I opened [bytecodealliance/wasmtime#2343](https://github.com/bytecodealliance/wasmtime/pull/2343) for this. (The final patch is slightly different.) Now with the patched Cranelift, I get

```bash
$ ./x.py build --stage 2 -j3
[...]
Assembling stage2 compiler (x86_64-unknown-linux-gnu)
Building stage2 std artifacts (x86_64-unknown-linux-gnu -> x86_64-unknown-linux-gnu)
[...]
    Finished release [optimized] target(s) in 24m 31s
Copying stage2 std from stage2 (x86_64-unknown-linux-gnu -> x86_64-unknown-linux-gnu / x86_64-unknown-linux-gnu)
Building stage2 compiler artifacts (x86_64-unknown-linux-gnu -> x86_64-unknown-linux-gnu)
[...]
```

The subtree for rustc_codegen_cranelift will be updated in [rust-lang/rust#78624](https://github.com/rust-lang/rust/pull/78624).

Moral of the story: I lost track of how much 128bit integer bug fixes there have been at this point.

Thanks to [@jyn514](https://github.com/jyn514) for giving feedback on this post.
