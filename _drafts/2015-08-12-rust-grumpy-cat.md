---
layout: post
title: Why Rust is a grumpy cat?
---

I have taken a look at the (Rust)[https://www.rust-lang.org/] `v1.2`,
started with writing a simple single linked list implementation based on
either borrowed references or boxed unique pointers.

My opinion after what i have been through - Rust is rather too young to be
used in production.

Looking at the sources of the basic `vec!` type following flaws were found:

* Simple `[T]` type is nothing more than a `slice` have a complex logic inside
  of `libcore` actually appears to be a projection over a raw pointer (raw \*T).
  That leads to the fact this code can't be reused anywhere off the Rust `internals`
  unless your own implementation is sticked to it tight, based on raw ptrs,
  or any other magic internal structs which are overlap each other in a
  enormous large manner.a

* A lot of code duplication for implementations of all basic traits along all
  internal abstractions.

* Multileveled unsafe abstractions which hides each other side effects. It is
  hidden from the enduser but reachly present underneath.

* The fact that the sources of the platform (collection sources for example) do
  not present a good language style (idioms) do not speak for the Rust. It is
  1.2 out and `libcollections` still refactoring heavily.
