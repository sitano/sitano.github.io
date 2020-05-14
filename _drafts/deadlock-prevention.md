---
layout: post
title: Deadlock prevention algorithms
categories: [theory, databases]
tags: [theory, databases, examples, transactions, deadlock]
mathjax: true
desc: A showcase of how the deadlock prevention algorithms work like wait-die, wound-wait and prioritization.
---

Many concurrency control (CC) [[2]] algorithms may run into a deadlock
situation [[3]] (2PL [[4]] and derivatives). There are 2 different
approaches to workaround the situation: detecting deadlocks and
preventing deadlocks. Let’s take a look at how preventing deadlocks algorithms works with
an arbitrary CC.

The system consists of a Transaction Manager (TM) that receives
a stream of commands, feeds it into the concurrency control (CC)
algorithm that outputs the list of actions to be performed. Resulted
sequence of actions (scheduling history) is conflict serializable (CSR)
and executed by the data manager (DM).

```

commands -> TM -> CC -> schedule -> DM

```

Let’s our CC be a classic 2PL (two-phase commit). The stream
of the commands that we will be receiving will be:

$$ s\ =\ r_1(x) r_2(x) w_3(x) w_4(x) w_1(x) c_1 w_2(x) c_2 c_3 c_4 $$

Deadlock is easy to see here highlighted with the red arrows:

![]({{ Site.url }}/public/cc_dl/deadlock.svg)

Semantically correct locking of $$ s $$ for this figure
is pretty straight forward. $$ {r_1(x), r_2(x)} $$ will
obtain shared read lock and the corresponding write
operation will fail to upgrade it to exclusive lock.

Feeding prefix of $$ prefix(s) = r_1(x) r_2(x) $$
into the TM (and CC) will result into:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) $$

The next command that we will receive is $$ w_3(x) $$ and the
CC output will depend on the deadlock preventing algorithm we use.

There are known at least 4 deadlock prevention algorithms:

- wait-die - requester blocks on young, young abort them selves
- wound-wait - requester abort younger txs, young blocks
- immediate restart - restart if need to block
- running priority  - block if lock-holder is not blocked, restart otherwise

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
[2]: https://en.wikipedia.org/wiki/Concurrency_control
[3]: https://en.wikipedia.org/wiki/Deadlock
[4]: https://en.wikipedia.org/wiki/Two-phase_locking
