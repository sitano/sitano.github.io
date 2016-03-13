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

- [So You Wanna Go Fast?](http://bravenewgeek.com/so-you-wanna-go-fast/) by Rog from February 26, 2016 at 11:18 am,
  [code](https://github.com/tylertreat/go-benchmarks/blob/master/channel_test.go)
- [Prometheus: Designing and Implementing a Modern Monitoring Solution in Go](https://github.com/gophercon/2015-talks/blob/master/Bj%C3%B6rn%20Rabenstein%20-%20Prometheus/slides.pdf)
  by Björn Rabenstein on Prometheus, SoundCloud, 2015-Talk

Whats wrong with tests?
=======================

What are go sync primitives actually?
=====================================

spinning
--------

TODO: what is max spinning ns/op to sync pri?

futex, note
-----------

sem
---

mutex
-----

channel
-------

Scheduling details
==================

parking
-------


goshed queue
------------

TODO: what is ns/op to rescheduling?

What are good design patterns for Go channels?
==============================================

Bench
=====
