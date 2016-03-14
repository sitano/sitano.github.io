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

I will address to the following articles:

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

What people usually say? - Channels are slow _inplace of_ mutexes. And they provide
mutual exclusion tests based on channels implementation underneath. And that's dumb.

The worst part of it is, another people start repeating this tail pattern: go channels
are slow without a reason, which of course the effect of a [broken telephone](
https://en.wikipedia.org/wiki/Chinese_whispers). Those who say that, do not understand
message passing pattern, concurrency control and the difference in semantics of those two.
I can give you free advice: don't try to implement mutexes with go channels and then
compare hammering the stuff without even race conditions over it. The whole idea of it
is sick from the whole beginning.

So, "don't share, communicate with sharing" is still true.

The understanding of the difference may come from the learning of
implementation of the go runtime and totally makes sense and present further down.

Second
------

Performance never described as a single-dimension value. Its always at least value
of three:

- latency
- throughput
- footprint

Tests in those articles usually tend to minimize single dimension latency in a mutual
exclusive data access. Should this work for channels in their fast-path code part
optimization?

Third
-----

Try to implement a Channel pattern (structure / interface) using only mutexes.
No asm. Good luck.

_hint: mutexes do not park until they full spinned with just couple of exceptions_

Forth
-----

Are you ready to sacrifice cpu usage (use heavy spinning) in the sake of
minimizing latency?

Do you trust go runtime scheduler? Why not, if you chose to use co-routines?

So You Wanna Go Fast?
------------------

???

Prometheus: Designing and Implementing a Modern Monitoring Solution in Go
------------------

???

Implementation
==============

I am using Go [1.6](https://github.com/golang/go/releases/tag/go1.6)
[source code](https://github.com/golang/go/tree/7bc40ffb05d8813bf9b41a331b45d37216f9e747).
For running test I would use something between i7 3770K and 4770K and at least 16 gigs of RAM.

Scheduling details
==================

I am not going to cover go [scheduler](
https://github.com/golang/go/blob/7bc40ffb05d8813bf9b41a331b45d37216f9e747/src/runtime/proc.go#L2022)
in [details](https://golang.org/s/go11sched) here.

The scheduler's job is to distribute ready-to-run goroutines
over worker threads. Main concepts:

- G - goroutine.
- M - worker thread, or machine.
- P - processor, a resource that is required to execute Go code.
      M must have an associated P to execute Go code, however it can be
      blocked or in a syscall w/o an associated P.

Runtime defined as a tuple of (m0, g0). Almost everything interested is happening in
the context of g0 (like scheduling, gc setup, etc). Usually switch from an arbitrary
goroutine to the g0 can happen in the case of: resceduling, goroutine parking, exiting /
finishing, syscalling, recovery from panic and maybe other cases I did not managed
to find with grep. In order to do a switch runtime calls [mcall](
https://github.com/golang/go/blob/7bc40ffb05d8813bf9b41a331b45d37216f9e747/src/runtime/stubs.go#L34)
function.

`mcall` switches from the g to the g0 stack and invokes fn(g), where g is the
goroutine that made the call. mcall can only be called from g stacks (not g0, not gsignal).

Under the scope of this article, most interesting are the concept of goroutine
`parking` and `rescheduling` which both usually used in the low-level implementations
of the sync primitives.

Typical switch looks like this:

```golang

//go:nosplit

// Gosched yields the processor, allowing other goroutines to run.  It does not
// suspend the current goroutine, so execution resumes automatically.
func Gosched() {
	mcall(gosched_m)
}

```

goshed & queues
---------------

The scheduler maintains global run queue. Next goroutine will be chosen from this
global run queue and local to `p` run queue. If there is no work, it will rather wait
trying to steal job from other resources `p*` before with `findrunnable`.

_Note. There is even network steeling opt. of goroutines ;)_

This is a [famous](https://golang.org/pkg/runtime/#Gosched)
[runtime.Gosched](https://github.com/golang/go/blob/7bc40ffb05d8813bf9b41a331b45d37216f9e747/src/runtime/proc.go#L242)
call, which yields the processor, allowing other goroutines to run.

```golang

//go:nosplit

// Gosched yields the processor, allowing other goroutines to run.  It does not
// suspend the current goroutine, so execution resumes automatically.
func Gosched() {
	mcall(gosched_m)
}

func goschedImpl(gp *g) {
	...
	globrunqput(gp)
	...
	schedule()
}

// Put gp on the global runnable queue.
//go:nowritebarrier
func globrunqput(gp *g) { ... }

```

runtime.Gosched() puts current goroutine `g` to the end of the global scheduler run
queue (`sched.runqtail`, using `globrunqput`), freeing current execution thread `m`
for calling next goroutine on the queue (`schedule`). Thus, it does not suspend the
current goroutine, so execution resumes automatically.

Gosched can be met in some places inside the go runtime and in implementations
of various user level sync primitives like [Ring Buffer](https://github.com/Workiva/go-datastructures/blob/master/queue/ring.go#L114).

Meaningless speed of self rescheduling?
---------------------------------------

This will call `runtime.Gosched()` on the benchmark goroutine with -cpu=1 to measure
switch to `g0` and rescheduling to self. It's clear the latency of getting next piece
of cpu time depends on the number of cores to thread pool size to number of goroutines,
their overall greediness and scheduler fairness algorithm.


```golang

func BenchmarkGosched(b *testing.B) {
	defer runtime.GOMAXPROCS(runtime.GOMAXPROCS(1))
	b.ResetTimer()
	for i := 0; i < b.N; i ++ {
		runtime.Gosched()
	}
}

```

Run: `go test -v -run ! -bench Gosched`. I have got 105 ns/op.

parking
-------

???

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
