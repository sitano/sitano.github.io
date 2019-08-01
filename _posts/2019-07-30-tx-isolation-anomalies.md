---
layout: post
title: Transaction isolation anomalies
categories: [theory, databases]
tags: [theory, databases, examples, transactions, anomalies]
mathjax: true
---

This document contains simple examples and explanations
of transaction isolation anomalies well known since
late 90's. The work based on papers [[1]], [[2]], [[3]].

I draw these graphs for different cases to better
understand the model that is defined at [[1]], [[3]]
and I hope it will be helpful for someone else as a quick
reminder of what these cases are about.

List of covered anomalies include:

- [G0: Dirty writes](#g0-dirty-writes)
- [G1: Dirty reads](#g1-dirty-reads)
- [G1a: Aborted Reads (cascaded aborts)](#g1a-aborted-reads-cascaded-aborts)
- [G1b: Intermediate Reads (dirty reads)](#g1b-intermediate-reads-dirty-reads)
- [G1c: Circular Information Flow](#g1c-circular-information-flow)
- [G-cursor: Lost Update](#g-cursor-lost-update)
- [G-single: Single Anti-dependency Cycles (read skew)](#g-single-single-anti-dependency-cycles-read-skew)
- [G2-item: Item Anti-dependency Cycles (write skew on disjoint read)](#g2-item-item-anti-dependency-cycles-write-skew-on-disjoint-read)
- [G2: Anti-Dependency Cycles (write skew on predicate read)](#g2-anti-dependency-cycles-write-skew-on-predicate-read)
- [OTV: Observed Transaction Vanishes](#otv-observed-transaction-vanishes)
- [IMP/PMP: Predicate-Many-Preceders](#imppmp-predicate-many-preceders)

## Model

On database model and transactions I encourage you to go read [[1]], [[3]].

In short:

1. The database consists of objects: rows or tuples;
2. Objects can be read or written by transactions;
3. Transaction reads and writes objects in some specific order;
4. An object has one or more versions.
5. Transaction can read any version of an object.
6. Transaction write generates new version of an object.

## Histories

Transaction execution form histories. There are good and bad
histories that we don't want to happen.

A _history_ H over a set of transactions consists of two parts — a
partial order of events E (e.g., read, write, abort, commit) of
those transactions, and a version order, $$ << $$, that is a total
order on committed versions of each object.

## Predicates

There are predicate _reads_ and _writes_. They don't differ too much.
A predicate is a boolean condition.

For example, list all employees from sales department:

    SELECT * FROM EMPLOYEE WHERE DEPT = SALES;

A query based on a predicate $$ P $$ (DEPT = SALES) by transaction $$ T_i $$
is represented in a history as $$ r_i(P: Vset(P)) \, r_i(x_j) \, r_i(y_k) ... $$,
where $$ x_j $$ , $$ y_k $$ are the versions in $$ Vset(P) $$ that match $$ P $$,
and $$ T_i $$ reads these versions.

Or, rise salary for sales:

    UPDATE EMPLOYEE SAL = SAL + $10 WHERE DEPT=SALES;

## Serialization Graph

_Direct serialization graph_ arising from a _history_ H,
denoted by $$ DSG(H) $$ is a graph in which each node corresponds
to a committed transaction and directed edges correspond
to different types of direct conflicts.

There is a read/write/anti-dependency edge from transaction $$ T_i $$ to
transaction $$ T_j $$ if $$ T_j $$ directly read/write/anti-depends on $$ T_i $$.

## Basic transactions conflicts

### Read-dependency (wr)

Transaction $$ T_j $$ directly read-depends on transaction $$ T_i $$
if $$ T_i $$ installs some object version $$ x_i $$ and $$ T_j $$ reads $$ x_i $$.

The relation is called _wr_ because one transaction writes an object
and the dependant transaction reads it.

![]({{ Site.url }}/public/tx_read_dep_wr.png)

- $$ W_i $$ denotes write operation by transaction $$ T_i $$;
- $$ R_i $$ denotes read operation by transaction $$ T_i $$;
- $$ Xj, X[j], X(j) $$ denotes an object $$ X $$ of version $$ j $$

$$ W_1(X_0) $$ means transaction $$ T_1 $$ wrote object $$ X $$
of version _0_ in history $$ H $$.

In this example transaction $$ T_2 $$ reads an object $$ X $$
written by the transaction $$ T_1 $$ and thus _item-read-depends_
on $$ T_1 $$. This _wr_ dependency is outlined as an orange arrow
in the graph from $$ T_1 $$ to $$ T_2 $$ over $$ x $$: $$ wr[x] $$.

### Change the matches of predicate-based read (wr)

$$ T_i $$ changes the matches of a predicate-based read $$ r_j (P: Vset(P)) $$ if
$$ T_i $$ installs $$ x_i $$ , $$ x_h $$ immediately precedes $$ x_i $$ in the version order,
and $$ x_h $$ matches $$ P $$ whereas $$ x_i $$ does not or vice-versa. In this case,
we also say that $$ x_i $$ changes the matches of the predicate-based read.

This is another case of _wr_ dependency because first transaction
installs a new object which is then appears in the second predicate-read
by the second transaction. And by appearing it changes the predicate-read
matching set.

![]({{ Site.url }}/public/tx_read_predicate_dep_wr.png)

Transaction $$ T_2 $$ sees only $$ X_0 $$ at the first read.
And with the second read it observes $$ X_0 $$ and $$ X_1 $$
just written by the $$ T1 $$.  

### Write-dependency (ww)

A transaction $$ T_j $$ directly write-depends on $$ T_i $$ if $$ T_i $$
installs a version $$ x_i $$ and $$ T_j $$ installs x’s next version
(after $$ x_i $$) in the version order.

The relation is called _ww_ because one transaction writes an object
and the dependant transaction overwrites it. Straight forward outcome
of this kind of conflicts are _dirty writes_.

![]({{ Site.url }}/public/tx_write_dep_ww.png)

In this example transaction $$ T_2 $$ overwrites an object $$ X $$
written by the transaction $$ T_1 $$ and thus _write-depends_
on $$ T_1 $$. This _ww_ dependency is outlined as an orange arrow
in the graph from $$ T_1 $$ to $$ T_2 $$ over $$ x $$: $$ ww[x] $$.

### Anti-dependency (rw)

An anti-dependency occurs when a transaction overwrites a
version observed by some other transaction. Thats in turn
means that one transaction reads an object which is then
changed by another transaction: read-write-depends (rw).

There is a small difference between the item-anti-dependency
and predicate-anti-dependency but its not significant.

![]({{ Site.url }}/public/tx_anti_dep_rw.png)

In this example transaction $$ T_2 $$ changes (writes) an object $$ X $$
observed by the transaction $$ T_1 $$ and thus _item-anti-depends_
on $$ T_1 $$. This _rw_ dependency is outlined as an orange arrow
in the graph from $$ T_1 $$ to $$ T_2 $$ over $$ x $$: $$ rw[x] $$.

## Transaction anomalies

All phenomena are defined in terms of DSG cycles and conflict relations.

### G0: dirty writes

**G0: Write Cycles**. A history H exhibits phenomenon
G0 if DSG(H) contains a directed cycle consisting
entirely of write-dependency edges.

*G0* phenomenon describes what is known as _dirty writes_
because it reflects a case in which updates to $$ x $$ and $$ y $$
occurs in opposite order ($$ T1:W.x << T2:W.x$$, but $$ T2:W.y << T1:W.y $$).

The level on which *G0* is disallowed called *PL-1* or
_READ UNCOMMITTED_.

![]({{ Site.url }}/public/tx_dirty_writes.png)

In this example $$ T1 $$ writes $$ (x = 2, y = 8) $$,
and $$ T2 $$ writes $$ (x = 5, y = 5) $$. The outcome
of the history H is $$ (x = 5, y = 8) $$ which is
inconsistent with any of the executed transaction.

### G1: dirty reads

Phenomenon *G1* captures the essence of no-dirty-reads,
and consists of *g1a*, *g1b*, *g1c*. *PL-2* isolation level
is defined such that *G1* disallowed.

### G1a: Aborted Reads (cascaded aborts)

**G1a: Aborted Reads**. A history H shows phenomenon
*G1a* if it contains an aborted transaction $$ T1 $$ and a
committed transaction $$ T2 $$ such that $$ T2 $$ has read
some object (maybe via a predicate) modified by $$ T $$.

*G1a* is part of the *PL-2* isolation level or _READ COMMITTED_.

It prevents a transaction T2 from committing if T2 has
read the updates of a transaction that might later abort.

![]({{ Site.url }}/public/tx_g1a_cascaded_aborts.png)

In this example $$ T2 $$ has read an object $$ X $$ written
by aborted transaction $$ T1 $$. Then $$ T2 $$ must be aborted.

### G1b: Intermediate Reads (dirty reads)

**G1b: Intermediate Reads**. A history H shows phenomenon
*G1b* if it contains a committed transaction
$$ T2 $$ that has read a version of object $$ x $$ (maybe via a
predicate) written by transaction $$ T1 $$ that was not $$ T1 $$’s
final modification of $$ x $$.

*G1b* is part of the *PL-2* isolation level or _READ COMMITTED_.

It ensures that transactions see only final versions of
the objects.

![]({{ Site.url }}/public/tx_g1b_inter_reads.png)

In this example $$ T2 $$ reads an intermediate state of
object $$ X $$ of version $$ 0 $$ ($$ T2: R_2(x_0) $$) written by the $$ T1: W_1(x_0) $$
and then overwritten with another version $$ x_1 $$. Then
$$ T2 $$ must be aborted (can't be committed).

### G1c: Circular Information Flow

**G1c: Circular Information Flow.** A history H exhibits
phenomenon *G1c* if *DSG(H)* contains a directed
cycle consisting entirely of dependency edges.

*G1c* is part of the *PL-2* isolation level or _READ COMMITTED_.

It ensures that if transaction $$ T2 $$ is affected by
transaction $$ T1 $$, it does not affect $$ T1 $$, i.e., there
is a unidirectional flow of information from $$ T1 $$ to $$ T2 $$.

There 3 possible combinations of cycles consisting of *ww*, *wr*
dependencies. *g1c* does not consider cycles with *rw* edges.

First example shows *ww-ww* and *wr-ww* cycles:

![]({{ Site.url }}/public/tx_g1c_circular_flow.png)

Imagine your system invariant is only one of the buttons
$$ {x, y} $$ are allowed to be enabled simultaneously.
This means allowed outcomes are $$ (0,0), (1,0), (0,1) $$,
but not $$ (1,1) $$.

Now the first transaction $$ T1 $$ will be disabling button $$ x $$
and enabling button $$ y $$: $$ (x=0, y=1) $$, and the second
transaction $$ T2 $$ will do the opposite - it will enable $$ x $$
and disable $$ y $$: $$ (x=1, y=0) $$. That is exactly what is
needed to create *ww-ww* cycle: $$ W_1(x_0)-ww->W_2(x_1) $$,
$$ W_2(y_0) -ww->W1(y_1) $$.

Operator which makes a decision on performing a second action
is allowed to proceed only if the first button was enabled so
the $$ T2 $$ reads $$ x $$ at $$ R_2(w_0) $$ creating a *wr-ww*
cycle.

Now $$ T1 $$ and $$ T2 $$ depends on each other. Outcome of
history H is $$ (x=1, y=1) $$ both buttons enabled that breaks
our invariant.

In the second example there is a *wr-wr* cycle in which
both transactions perform _write_ and _read_ on opposite
objects _x_ and _y_ thus ending up with inconsistent final view:

![]({{ Site.url }}/public/tx_g1c_circular_flow_2.png)

$$ T1 $$ writes $$ (x=11) $$, and $$ T2 $$ writes $$ (y=22) $$.
After that they read _y_ and _x_ correspondingly and see
$$ T1: (x=11, y=20) $$, $$ T2: (x=10, y=22) $$. That means
that in history H they observed partial state of the system
what must be forbidden for the sake of the greater good.

### G-cursor: Lost Update

**G-cursor(x)** or _Single Anti-dependency Cycle over X_: A history H
exhibits phenomenon _G-cursor(x)_ if _LDSG(H)_ contains a cycle
with an anti-dependency (_rw_) and one or more write-dependency (_ww_)
edges such that all edges are labeled $$ x $$.

*G-cursor* describes what is known as _lost update_.

The level on which *G1* and *G-cursor* are disallowed called *PL-CS* or
_Cursor Stability_.

![]({{ Site.url }}/public/tx_lost_update.png)

In this example each of the transactions tries to increment a value
$$ x $$. First of all a transactions reads an object state creating
*rw* edge, and then writes back updated state _+1_ (*ww*). It happens to be
that $$ T1 $$ and $$ T2 $$ ran concurrently end up $$ x = 1 $$ even
though they both were updating its state with _+1_. $$ W_2(x_1) $$
update was lost after $$ W_1(x_2) $$. The right outcome for this
program would $$ x = 2 $$.

### G-single: Single Anti-dependency Cycles (read skew)

**G-single** or _Single Anti-dependency Cycle_: A history H
exhibits phenomenon *G-single* if *DSG(H)* contains a cycle
consisting of an anti-dependency (_rw_) and one or more dependency (_ww_, _rw_)
edges.

*G-single* describes what is known as _read skew_ or _non-repeatable reads_.

![]({{ Site.url }}/public/tx_read_skew.png)

The problem here is that _read-only_ transaction $$ T_i $$ performing
read of $$ (x, y) $$ observed $$ x $$ and $$ y $$ from various states of
the system, thus ended up seeing inconsistent state. $$ R_i(x) $$ read
a version before the committed transaction $$ T_j $$ wrote a version of
$$ W_j(y) $$ that was then read by $$ T_i: R_i(y) $$.

In example:

```
  T1 --R(x=0)-----------------R(y=1)--(x=0,y=1) <-- broken
  T2 ---------W(x=1)---W(y=1)---------(x=1,y=1)
  x  --0--------1---------------------1
  y  --0-----------------1------------1
```

### G2-item: Item Anti-dependency Cycles (write skew on disjoint read)

**G2-item**: _Item Anti-dependency Cycles_. A history H exhibits
phenomenon *G2-item* if *DSG(H)* contains a directed cycle having
one or more item-anti-dependency (rw) edges.

*G2-item* describes what is known as _write skew_.

The level on which *G2-item* is disallowed called *PL-2.99* or
_REPEATABLE READ_.

![]({{ Site.url }}/public/tx_write_skew.png)

### G2: Anti-Dependency Cycles (write skew on predicate read)

**G2**: _Anti-dependency Cycles_. A history H exhibits
phenomenon *G2* if *DSG(H)* contains a directed cycle
with one or more anti-dependency (_rw_) edges.

*G2* describes what is known as _write skew_. This one
includes predicate reads.

The level on which *G2* is disallowed called *PL-3* or
_SERIALIZABLE_.

![]({{ Site.url }}/public/tx_write_skew.png)

### OTV: Observed Transaction Vanishes

**Observed Transaction Vanishes (OTV)**. A history H exhibits
phenomenon *OTV* if *USG(H)* contains a directed cycle consisting
of exactly one read-dependency (_wr_) edge by $$ x $$ from $$ T_j $$ to
$$ T_i $$ and a set of edges by $$ y $$ containing at least one
anti-dependency (_rw_) edge from $$ T_i $$ to $$ T_j $$ and $$ T_j $$’s
read from $$ y $$ precedes its read from $$ x $$.

OTV occurs when a transaction observes part of another transaction’s
updates but not all of them.

![]({{ Site.url }}/public/tx_otv_anomaly.png)

### IMP/PMP: Predicate-Many-Preceders

**Item-Many-Preceders (IMP)**. A history H exhibits phenomenon
*IMP* if *DSG(H)* contains a transaction $$ T_i $$ such that $$ T_i $$
directly item-read-depends (_wr_) by $$ x $$ on more than one other transaction.

IMP occurs if a transaction observes multiple versions of the same item
(e.g., transaction Ti reads x1 and x2).

**Predicate-Many-Preceders (PMP)**. A history H exhibits
the phenomenon *PMP* if, for all predicate-based reads
$$ r_i(P_i : Vset(P_i)) $$ and $$ r_j(P_j : Vset(P_j) $$ in
$$ T_k $$ such that the logical ranges of $$ P_i $$ and $$ P_j $$
overlap (call it $$ P_o $$), the set of transactions that change
the matches of $$ P_o $$ for $$ r_i $$ and $$ r_j $$ differ.

PMP occurs if a transaction observes different versions resulting from
the same predicate read (e.g., transaction $$ T_i $$ reads
$$ Vset(P_i) = ∅ $$ and $$ Vset(P_i) = {x_1} $$)).

Both IMP and PMP relates to the _Snapshot_ isolation mode (
a system provides Snapshot Isolation if it prevents phenomena
_G0, G1a, G1b, G1c, PMP, OTV, and Lost Updates_).

![]({{ Site.url }}/public/tx_imp_pmp_anomaly.png)

### Short-fork/ Long-fork (write-skew)

TO BE DONE

## Citations

All definitions are taken from [[1]], [[2]], [[3]].

## References

- [Atul Adya, Barbara Liskov, Patrick O’Neil: "Generalized Isolation Level Definitions" Appears in the Proceedings of the IEEE International Conference on Data Engineering, San Diego, CA, March 2000][1]
- [Peter Bailis, Alan Fekete, Ali Ghodsi, Joseph M. Hellerstein, and Ion Stoica: "Scalable Atomic Visibility with RAMP Transactions" at ACM Transactions on Database Systems, Vol. 41, No. 3, Article 15, Publication date: July 2016][2]
- [Weak Consistency: A Generalized Theory and Optimistic Implementations for Distributed Transaction][3]
- [Project Hermitage][4]
- [Hal Berenson, Phil Bernstein, Jim Gray, Jim Melton, Elizabeth O'Neil and Patrick O'Neil: A Critique of ANSI SQL Isolation Levels, at ACM International Conference on Management of Data (SIGMOD), volume 24, number 2, May 1995. doi:10.1145/568271.223785][5]

[1]: http://bnrg.cs.berkeley.edu/~adj/cs262/papers/icde00.pdf "Atul Adya, Barbara Liskov, Patrick O’Neil: "Generalized Isolation Level Definitions" Appears in the Proceedings of the IEEE International Conference on Data Engineering, San Diego, CA, March 2000"
[2]: http://www.bailis.org/papers/ramp-tods2016.pdf "Peter Bailis, Alan Fekete, Ali Ghodsi, Joseph M. Hellerstein, and Ion Stoica: "Scalable Atomic Visibility with RAMP Transactions" at ACM Transactions on Database Systems, Vol. 41, No. 3, Article 15, Publication date: July 2016."
[3]: http://pmg.csail.mit.edu/papers/adya-phd.pdf "Weak Consistency: A Generalized Theory and Optimistic Implementations for Distributed Transactions"
[4]: https://github.com/ept/hermitage/ "Project Hermitage"
[5]: http://research.microsoft.com/pubs/69541/tr-95-51.pdf "Hal Berenson, Phil Bernstein, Jim Gray, Jim Melton, Elizabeth O'Neil and Patrick O'Neil: A Critique of ANSI SQL Isolation Levels, at ACM International Conference on Management of Data (SIGMOD), volume 24, number 2, May 1995. doi:10.1145/568271.223785"
