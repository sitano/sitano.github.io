---
layout: post
title: Go channels are not wrong (slow mutexes), but you are
---

This post appeared as an attempt to address a popular trend in the
Go community lately, to write an articles usually called: go channels
are slow compared to whatever (mutexes, ring buffers, etc) - you
name it. Which I personally think are not a) correct, b) they tend
to urge people in what channels actually are not in its nature, thus
rising incorrect understanding of its nature and semantics.

I will address to those articles:

- [So You Wanna Go Fast?](http://bravenewgeek.com/so-you-wanna-go-fast/) by
  Rog from February 26, 2016 at 11:18 am,
  [code](https://github.com/tylertreat/go-benchmarks/blob/master/channel_test.go)
- [Prometheus: Designing and Implementing a Modern Monitoring Solution in Go](
  https://github.com/gophercon/2015-talks/blob/master/Bj%C3%B6rn%20Rabenstein%20-%20Prometheus/slides.pdf)
  by Björn Rabenstein on Prometheus, SoundCloud, 2015-Talk,
  [code](https://github.com/beorn7/concurrentcount/blob/master/benchmark_test.go)

Whats wrong with these tests?
=============================

Intro
-----

I should start asking a reader about what does he think about comparing an elephants
to the birds (or monkeys) in a wild? Both actually inhabit an earth nature in a
same environment.

So, what I am complaining about? People reason about go channels are not as
fast as mutexes (or anything else), forgetting to add that they compare two
different purpose primitives from [concurrent computing](
https://en.wikipedia.org/wiki/Concurrent_computing) with totally different semantics:

- mutex is a [shared memory communication](https://en.wikipedia.org/wiki/Shared_memory)
  primitive used usually to organize memory access patterns via [mutual exclusion](
  https://en.wikipedia.org/wiki/Mutual_exclusion),

- channel is a [message passing communication](https://en.wikipedia.org/wiki/Message_passing)
  primitive and a key component to organization of various [models of concurrency](
  https://en.wikipedia.org/wiki/Message_passing).

What people usually say? - Channels are slow _instead of_ mutexes. And they provide
mutual exclusion tests based on channels implementation underneath. And that's dumb.

The worst part of it is, another people start repeating this tail pattern: go channels
are slow without a reason, which of course the effect of [broken telephone](
https://en.wikipedia.org/wiki/Chinese_whispers). Those who say that, do not understand
message passing pattern, concurrency control and the difference in semantics of those two.
I can give you free advice: don't try to implement mutexes with go channels and then
compare hammering the stuff without even race conditions over it. The whole idea of it
is sick from the whole beginning.

So, "don't share, communicate with sharing" is still true.

The understanding of the difference may come from the learning of implementation of the go
runtime and totally makes sense and present further down.

Second
------

Performance never described as a single-dimension value. Its always at least value
of three:

- latency
- throughput
- footprint

Tests in those articles usually tend to minimize single dimension latency in a mutual
exclusive data access. Should this work for channels in their fast-path code part optimization?

Third
-----

Try to implement a Channel pattern (structure / interface) using only mutexes. No asm. Good luck.

_hint: mutexes do not park until they full spinned with just couple of exceptions_

Forth
-----

Are you ready to sacrifice cpu usage (use heavy spinning) in the sake of minimizing latency?

Do you trust go runtime scheduler? Why not, if you chose to use co-routines?

[So You Wanna Go Fast?](http://bravenewgeek.com/so-you-wanna-go-fast/)
------------------

???

[Prometheus: Designing and Implementing a Modern Monitoring Solution in Go](https://github.com/gophercon/2015-talks/blob/master/Bj%C3%B6rn%20Rabenstein%20-%20Prometheus/slides.pdf)
------------------

???

Scheduling details
==================

parking
-------

???

goshed queue
------------

???

TODO: what is ns/op to rescheduling?

What are go sync primitives actually?
=====================================

???

spinning
--------

???

TODO: what is max spinning ns/op to sync pri?

futex, note
-----------

???

sem
---

???

mutex
-----

???

channel
-------

???

What are good design patterns for Go channels?
==============================================

???

Bench
=====

???
