---
layout: post
title: Multi-version concurrency control serializability
categories: [theory, databases]
tags: [theory, databases, examples, transactions, deadlock]
mathjax: true
desc: An example of testing a multi-version schedule serializability and an application of MVCC schedulers
---

Multi-version histories
---

In conventional histories in any point in time there exists only one version of a variable.
That means that the _write_ operations always rewrite previous version and the _read_ operations
always read the latest written version as it is defined by the schedule semantics:

$$ w_1(x) w_2(x) r_3(x), H_s(r_3(x))\ =\ H_s(w_2(x)) $$

where $$ H_s $$ is a function that assigns every read the latest write to the corresponding variable.

Imagine that you can travel back in time. How it could look like?

$$ w_1(x) r_3(x) w_2(x), H_s(r_3(x))\ =\ H_s(w_1(x)) $$

Here we send read $$ r_3(x) $$ back in time to read the output of the transaction $$ t_1 $$.

How it could look like without commuting operations in the history? The answer is simple:
with the references to the previous versions of variables.

$$ w_1(x_1) w_2(x_2) r_3(x_1), h(r_3(x)) = w_1(x_1) $$

Here we have a writes that create versions of a variable $$ x $$. And the read that
reads one version of $$ t_1 $$. Function $$ h $$ is called a version function. With
the version function the multi-version histories comes into play.

Such histories like one above are called multi-version (mv) histories. It is histories
with the version function that says who reads what. A read operation can read one of
the previously written versions of a variable. If the version function always returns
the latest version for reads the history called monoversion. Conventional histories
are equivalent to corresponding monoversion variants.

With mv histories we can produce more serializable histories even if some of the operations
arrive late. Weikum & Vossen gives a great example of how much bigger the power of
scheduling can be with the mv-histories. Consider the following history:

$$ s = r_1(x) w_1(x) r_2(x) w_2(y) r_1(y) w_1(z) c_1 c_2 $$

This history is not conflict-serializable due to the fact that $$ r_1(y) $$ arrived
too late so it creates a cycle in the conflict graph of $$ s $$. This history could
be serializable in example if $$ r_1(y) $$ came before $$ w_2(y) $$:

$$ s_2 = r_1(x) w_1(x) r_2(x) r_1(y) w_2(y) w_1(z) c_1 c_2 $$

$$ s_2 $$ does not have a cycle in the conflict graph so it is conflict-serializable.
That's cool. But we don't control the order in which events arrive in our scheduler.
What we control, is the point in time from which the read operation reads a version.
We can define a version function so that serializability of $$ s $$ will become
possible:

$$ h(r_1(y)) = w_0(y) $$

That means that $$ r_1(y) $$ will read the version of $$ y $$ written by the initial
transaction $$ t_0 $$: literally the previous version before $$ t_2 $$:

$$ m = r_1(x_0) w_1(x_1) r_2(x_1) w_2(y_2) r_1(y_0) w_1(z_1) c_1 c_2 $$

This multi-version history $$ m $$ is equivalent to the:  

$$ m_2 = r_1(x_0) w_1(x_1) r_2(x_1) r_1(y_0) w_2(y_2) w_1(z_1) c_1 c_2 $$

That is a monoversion history that is equivalent to $$ s_2 $$ and $$ s_2 \in CSR $$:

$$ s_2 = r_1(x) w_1(x) r_2(x) r_1(y) w_2(y) w_1(z) c_1 c_2 $$

Thus, multi-versioning allows to serialize more histories. Let's take a look at how
the serializability works in a case of multi-version histories.

Multi-version serializability
---

There are 2 kinds of MV serializability:

- MVSR - multi-version view serializability
- MCSR - multi-version conflict serializability

MVSR is defined by the analogy with the VSR equivalence relation:
$$ m \in MVSR $$ if and only if there exists a serial monoversion
schedule $$ m' $$ for the same set of transactions such that
$$ RF(m) = RF(m') $$ where $$ RF $$ is a _read-from_ relation.

The final state view in MVSR is not relevant any more because any
permutation of operations in $$ s $$ will produce the same final
state view because writes do not erase previous versions.

MCSR by the analogy with CSR is a class in which for a history $$ m $$
there $$ \exists\ m' - {serial\ monoversion} $$ for the same set of transactions
such that all conflict pairs of $$ m $$ occur in the same order in $$ m' $$.

Interesting nuance of the MV conflict set is its asymmetry:
conflict set consists of the $$ (r_j(x_i), w_k(x_k)) $$ pairs
such that $$ w_i(x_i) <_m r_j(x_i) <_m w_k(x_k) $$. So there are
no _ww_ and _wr_ pairs in the conflict set because commuting _ww_
does not change anything for following read operations,
and commuting _wr_ pairs does not affect the read variants
space in a negative way so if the history with _rw_ pair
is serializable the one with the _wr_ pair is serializable
as well.

This asymmetry leads to the asymmetry in serializability class
definition such that it's $$ m $$ conflict pairs must occur in
the same order in $$ m' $$, not the pairs from $$ m' $$. More
details in [[3]]. I have spent some time to read out the
definition of the MCSR in Vossen & Weikum book that does not
make an accent from my point of view on that nuance.

The relation between classes is as follows:

$$ CSR \subset MCSR \subset MVSR \subset {histories} \\ $$
$$ CSR \subset VSR \subset MVSR\\ $$

On testing serializability
---

Let's take a look at how a history may be tested for the multi-version
serializability. We will start with testing for MCSR and then
continue with the MVSR with this example:

$$ m = w_0(x_0) w_0(y_0) c_0 w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 r_3(y_0) w_3(x_3) c_3 $$

- testing MCSR
- testing MVSR wrong and right

MVCC schedulers
---

- MVCC+M2PL
- ROMV

Anomalies in SI and SSI
---

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].
- [Algorithmic aspects of multiversion concurrency control by Thanasis Hadzilacos, Christos Harilaos Papadimitriou, march 1985][3].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
[2]: https://en.wikipedia.org/wiki/Concurrency_control
[3]: https://dl.acm.org/doi/10.1145/325405.325417 "Algorithmic aspects of multiversion concurrency control by Thanasis Hadzilacos, Christos Harilaos Papadimitriou, march 1985"
