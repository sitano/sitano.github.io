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
preventing deadlocks. Let’s take a look at how preventing
deadlocks algorithms works with an arbitrary CC.

The system consists of a Transaction Manager (TM) that receives
a stream of commands, feeds it into the concurrency control (CC)
algorithm that outputs the list of actions to be performed. Resulted
sequence of actions (scheduling history) is conflict serializable (CSR)
and executed by the data manager (DM).

```

commands -> TM -> CC -> schedule -> DM

```

Let our CC be a classic 2PL (two-phase commit). The stream
of the commands that we will be receiving will be:

$$ s\ =\ r_1(x) r_2(x) w_3(x) w_4(x) w_1(x) c_1 w_2(x) c_2 c_3 c_4 $$

Semantically correct locking of $$ s $$ for this figure
is pretty straight forward. $$ {r_1(x), r_2(x)} $$ will
obtain shared read lock and the corresponding write
operation will fail to upgrade it to exclusive lock.

Note. In simple words well-formed locking is a form of a schedule
where all read and writes operations perform under corresponding
shared or exclusive locks, locks and unlocks are semantically correct
(lock < op < unlock), there is no transitive redundency of locks
(no lock < op(x) < lock < x < ... or unlock < unlock).

Note. Main 2PL property is that transaction acquires all lock
before releasing them (no lock(x) < unlock(x) < lock(y)).

Deadlock is easy to see here highlighted with the red arrows:

![]({{ Site.url }}/public/cc_dl/deadlock.svg)

The deadlock is $$ lr_1(x) lr_2(x) lw_1(x) lw_2(x) $$. Both
$$ t_1 $$ and $$ t_2 $$ tries to upgrade their shared locks
and block waiting for each other to release the $$ x $$.

Feeding a prefix $$ prefix(s) = r_1(x) r_2(x) $$ into the TM
(and CC) will result into:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) $$

The next command that we will receive is $$ w_3(x) $$. $$ w_3(x) $$
must block, because $$ t_1 $$ and $$ t_2 $$ are holding shared lock.
However, CC output will depend on the deadlock preventing algorithm.

There are at least 4 widely known deadlock prevention algorithms:

- wait-die - lock requester blocks on younger txs, young abort themselves
- wound-wait - lock requester aborts younger txs, young blocks
- immediate restart - restart if need to block
- running priority  - block if lock-holder is not blocked, restart otherwise

Requester is a transaction $$ t_i $$ that requests a lock by issuing
a locking command $$ lr_i(x) $$ or $$ lw_i(x) $$. Transaction $$ t_j $$
that holds the lock called holder. Then we set a total order of
transactions $$ ts $$ in such a way that $$ ts(t_i) < ts(t_j) $$ if
and only if $$ t_i $$ started before $$ t_j $$.

Wait-die
===

Receiving $$ w_3(x) $$ must block $$ t_3 $$ for $$ t_1,\ t_2 $$. However,
$$ ts(t_3)\ >\ ts(t_1) \land ts(t_3)\ >\ ts(t_2) $$. Hence $$ t_3 $$
can't block and wait for $$ t_1 $$ and $$ t_2 $$ and our CC issues an
abort command $$ a_3 $$. Thus we are getting:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 $$

The same thing happens for the $$ w_4(x) \in t_4 $$: 

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 a_4 $$

Then we receive $$ w_1(x) $$ from $$ t_1 $$. $$ ts(t_1)\ <\ ts(t_2) $$
thus $$ lw_1(x) $$ (along the $$ t_1 $$) blocks waiting for the $$ t_2 $$
to release shared lock on $$ x $$.

$$ t_1 $$ is blocked, so $$ c_1 $$ queued. Next command we receive is $$ w_2(x) $$.
$$ ts(t_2)\ >\ ts(t_1) $$ and $$ lw_2(x) $$ can't block waiting for $$ t_1 $$.
Thus $$ t_2 $$ aborts:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 a_4 a_2 $$

Now, we can finish $$ t_1 $$ because aborted $$ t_2 $$ released shared lock:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 a_4 a_2 lw_1(x) w_1(x) uw_1(x) c_1 $$

(here we assume that transaction abort automatically releases all of its locks)

Wound-wait
===

Receiving $$ w_3(x) $$ must block $$ t_3 $$ for $$ t_1,\ t_2 $$. Indeed,
$$ ts(t_3)\ >\ ts(t_1) \land ts(t_3)\ >\ ts(t_2) $$. Hence $$ t_3 $$
is younger it will block and wait for $$ t_1 $$ and $$ t_2 $$ to release
the lock. Thus we are still having:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x), \{t_3\} \text{ queued} $$

The same thing happens for the $$ w_4(x) \in t_4 $$:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x), \{t_3, t_4 \}\text{ queued} $$

Then we receive $$ w_1(x) $$ from $$ t_1 $$. $$ ts(t_1)\ <\ ts(t_2) $$
thus $$ lw_1(x) $$ wounds $$ t_2 $$ that holds shared lock by issuing $$ a_2 $$:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_2 lw_1(x) w_1(x) uw_1(x) c_1, \{t_3, t_4\}\text{ queued} $$

(here we assume that transaction abort automatically releases all of its locks)

Now, the wait queue consist of $$ t_3 $$ and $$ t_4 $$:

$$ w_3(x) w_4(x) c_3 c_4 $$

Now we easily output $$ lw_3(x) w_3(x) $$:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_2 lw_1(x) w_1(x) uw_1(x) c_1
lw_3(x) w_3(x) $$

Next comes in $$ w_4(x) $$.

$$ ts(t_4) > ts(t_3) $$ hence $$ t_4 $$ blocks in favor of $$ t_3 $$.

Luckily, the next command $$ c_3 $$ commits $$ t_3 $$ and we can finish
$$ t_4 $$:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_2 lw_1(x) w_1(x) uw_1(x) c_1
lw_3(x) w_3(x) uw_3(x) c_3 lw_4(x) w_4(x) uw_4(x) c_4 $$

Immediate restart
===

$$ w_3(x) $$ and $$ w_4(x) $$ must block for $$ t_1,\ t_2 $$ so $$ \{t_3, t_4\} $$ abort:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 a_4 $$

Then we receive $$ w_1(x) $$ from $$ t_1 $$, but $$ w_1(x) $$ can't upgrade
it's sharing lock, because it is also obtained by the $$ t_2 $$ so it must block.
Instead of block, we issue abort:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 a_4 a_1 $$

(here we assume that transaction abort automatically releases all of its locks)

Now $$ t_2 $$ can successfully finish:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_3 a_4 a_1 lw_2(x) w_2(x) uw_2(x) c_2 $$

Running priority
===

Receiving $$ w_3(x) $$ must block $$ t_3 $$ for $$ t_1,\ t_2 $$. Indeed,
$$ \{t_1, t_2\} $$ are not blocked.

$$ lr_1(x) r_1(x) lr_2(x) r_2(x), \{t_3\} \text{ queued} $$

Next comes $$ w_4(x) $$ that must also block for $$ t_1,\ t_2 $$ and again
$$ \{t_1, t_2\} $$ are not blocked.

$$ lr_1(x) r_1(x) lr_2(x) r_2(x), \{t_3, t_4\} \text{ queued} $$

Now we receive $$ w_1(x) $$, but $$ t_2 $$ holds shared lock on $$ x $$
and is not block, so $$ w_1(x) $$ queued:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x), \{t_3, t_4, t_1\} \text{ queued} $$

Now we receive $$ w_2(x) $$. $$ t_1 $$ holds shared lock on $$ x $$ and
is blocked waiting for $$ t_2 $$. Hence $$ t_2 $$ can't block on $$ t_1 $$
and must be aborted:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_2, \{t_3, t_4, t_1\} \text{ queued} $$

(here we assume that transaction abort automatically releases all of its locks)

Now, the wait queue consist of:

$$ w_3(x) w_4(x) w_1(x) c_1 c_3 c_4 $$

$$ t_1 $$ still holds the shared lock, so ongoing writes from $$ \{t_3, t_4\} $$
must be aborted:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_2 a_3 a_4, \{ t_1\} \text{ queued} $$

And the $$ t_1 $$ can now finish:

$$ lr_1(x) r_1(x) lr_2(x) r_2(x) a_2 a_3 a_4 lw_1(x) w_1(x) uw_1(x) c_1 $$

Theoretically, the CC could resort blocked transactions in favor of
processing ones that has more locks first ($$ t_1 $$). In that case
the transactions that are also blocked but have dependencies on others
that are also blocked could have more chances to be committed without
a restart.

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
[2]: https://en.wikipedia.org/wiki/Concurrency_control
[3]: https://en.wikipedia.org/wiki/Deadlock
[4]: https://en.wikipedia.org/wiki/Two-phase_locking
