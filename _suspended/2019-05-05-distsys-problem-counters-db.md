---
layout: post
title: Distributed systems problem - counters database
categories: [distsys, problems]
tags: [distsys, problems, task, interview, test]
mathjax: true
source: "Mesosphere"
---

This continues a series of problems in a field of distributed systems
to be solved to learn or for discussing at interviews. [First][1] one
is available here. The lack of precise formulation of the tasks adds
to the number of possibilities to consider when thinking about solutions.

## Task

Create a highly available distributed database of counters $$ n \in N $$
that exposes following API:

* POST /config {"nodes": ["1.2.3.4", "1.2.3.5", "1.2.3.6"]} (JSON)
* GET  /get/:name:/value -> value
* GET  /get/:name:/consistent_value -> value
* POST /set/:name: non-negative-integer in ASCII 0...

Database must be highly available and expose 1 write method, 1 read method
with weaker consistency semantics and 1 with stronger consistency.
In-memory storage is fine.

Service must work with at least 3 nodes. Service must handle network
disruptions and process failures gracefully.

## Objectives

1. To be accurate for the consistent endpoint.
2. To be available in light of network or process failure.
3. To be crash-tolerant.

You may assume that the number of counters will be <10k, and that there
will be more than enough memory.

## Variant A

Consistent reads endpoint must guarantee recency on the values read.
Any natural numbers are expected at the input of `/set/:name:`.

## Variant B

You may assume that the contract of `/set/:name:` expects new values to
be only equal or greater than current value in this key.

## Questions

What consistency model would you choose for consistent reads?
How would you make the database highly available? What tradeoffs would you
choose to ensure best performance characteristics? How to test system
to prove it holds consistency and availability guarantees?

[1]: http://sitano.github.io/distsys/problems/2019/05/01/distsys-problem-rndseq/ "previous task"
