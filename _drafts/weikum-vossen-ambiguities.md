---
layout: post
title: Ambiguities in Weikum & Vossen book 
categories: [theory, databases]
tags: [theory, databases, examples, transactions, deadlock]
mathjax: true
desc: Ambiguities in readings of Weikum & Vossen book by me
---

OS1 rule
---

page 146, OS1 is part of the lock acquisition rule for ordering
sharing:

_OS1_: In a schedule $$ s $$, for any two operations $$ p_i(x) $$
and $$ q_i(x),\ i\ \noteq\ j $$, such that $$ pl_i(x) -> ql_j(x) $$
is permitted, if $$ t_i $$ acquires $$ pl_i(x) $$ before $$ t_j $$
acquires $$ ql_j(x) $$, then the execution of $$ p_i(x) $$ must
occur before the execution of $$ q_j(x) $$.

TODO: explain constraint on ordering of all

MCSR definition
---

page 199, MCSR definition:

> A multiversion history m is multiversion conflict serializable if there is a serial
> monoversion history for the same set of transactions in which all pairs of
> operations in multiversion conflict occur in the same order as in m. Let MCSR
> denote the class of all multiversion conflict-serializable histories.

TODO: explain constraint on asymmetry

MV2PL 2.a rule
---

page 205, MV2PL 2.a rule:

> 2. If the step is final within transaction ti, it is delayed until the following
> types of transactions are committed:
> (a) all those transactions tj that have read the current version of a data
> item written by ti,

TODO: explain, ambiguity of current version and the version written by ti

Polygraph
---

This one is not an ambiguity but it took me a while to get this detail
from the definition:

VSR polygraph has edges to all transactions from the $$ t_0 $$ and
edges to $$ t_{\infty} $$ from all the transactions.



## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
