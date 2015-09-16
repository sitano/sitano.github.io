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
  enormous large manner.

* A lot of code duplication for implementations of all basic traits along all
  internal abstractions.

* Multileveled unsafe abstractions which hides each other side effects. It is
  hidden from the enduser but reachly present underneath.

* The fact that the sources of the platform (collection sources for example) do
  not present a good language style (idioms) do not speak for the Rust. It is
  1.2 out and `libcollections` still refactoring heavily.

* Most projects on the github uses specific `#!features` of the language
  available only under `night` build what is actually makes all `stable` and
  `beta` releases useless, coz guess what - you can't build nothing without it.

* There is no big nice projects on the github but mozilla's browser. There is a
  `REPL` project which requires `night` build as well. Another interesting project
  is `redis` remake called `sredis`.

* High entrance bar. It's because Rust hides all pointers semantics details from you,
  which in C++ are much clearer. More over, Rust changes syntax over the releases
  for the various pointers types (i.e. unique pointers). So many articles on Rust
  do not work already. And finally, when you think all the hidden details would ease
  a life for you, just do not go into the source code implementation.

* There is no templates specialization support yet.

* There is no negative constraints support for template parameters (: !Display).

* You can't match on traits (by type).

* There is no way to implement trait for enum instance. Enum instance / values 
  (that stands for ADT) are not types actually.
