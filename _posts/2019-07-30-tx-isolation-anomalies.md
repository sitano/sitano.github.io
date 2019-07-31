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

- G0: Write Cycles (dirty writes)
- G1a: Aborted Reads (cascaded aborts)
- G1b: Intermediate Reads (dirty reads)
- G1c: Circular Information Flow
- OTV: Observed Transaction Vanishes
- IMP/PMP: Predicate-Many-Preceders
- G-cursor: Lost Update
- G-single: Single Anti-dependency Cycles (read skew)
- G2-item: Item Anti-dependency Cycles (write skew on disjoint read)
- G2: Anti-Dependency Cycles (write skew on predicate read)

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

![]({{ Site.url }}/public/tx_dirty_writes.png)

### G1a: Aborted Reads (cascaded aborts)

![]({{ Site.url }}/public/tx_g1a_cascaded_aborts.png)

### G1b: Intermediate Reads (dirty reads)

![]({{ Site.url }}/public/tx_g1b_inter_reads.png)

### G1c: Circular Information Flow

![]({{ Site.url }}/public/tx_g1c_circular_flow.png)

![]({{ Site.url }}/public/tx_g1c_circular_flow_2.png)

### OTV: Observed Transaction Vanishes

![]({{ Site.url }}/public/tx_otv_anomaly.png)

### IMP/PMP: Predicate-Many-Preceders

![]({{ Site.url }}/public/tx_imp_pmp_anomaly.png)

### G-cursor: Lost Update

![]({{ Site.url }}/public/tx_lost_update.png)

### G-single: Single Anti-dependency Cycles (read skew)

![]({{ Site.url }}/public/tx_read_skew.png)

### G2-item: Item Anti-dependency Cycles (write skew on disjoint read)

![]({{ Site.url }}/public/tx_write_skew.png)

### G2: Anti-Dependency Cycles (write skew on predicate read)

![]({{ Site.url }}/public/tx_write_skew.png)

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
