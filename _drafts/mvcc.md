---
layout: post
title: Multi-version concurrency control serializability
categories: [theory, databases]
tags: [theory, databases, examples, transactions, deadlock]
mathjax: true
desc: An example of testing a multi-version schedule serializability and an application of MVCC schedulers
---

Plan:

1. Multi-version histories

- how they look like compared to conventional histories
- monoversion histories
- mv serializability

2. An example of serializability testing

- testing MCSR
- testing MVSR wrong and right

3. An example of how MVCC schedulers work

- MVCC+M2PL
- ROMV

4. Anomalies in SI and SSI

---

In conventional histories in any point in time there exists only one version of a variable.
That means that the _write_ operations always rewrite previous version and the _read_ operations
always read the latest written version as it is defined by the schedule semantics:

$$ w_1(x) w_2(x) r_3(x), H_s(r_3(x))\ =\ H_s(w_2(x)) $$

where $$ H_s $$ is a function that assigns every read the latest write to corresponding variable.

Imagine that you can travel back in time. How it could look like?

$$ w_1(x) r_3(x) w_2(x), H_s(r_3(x))\ =\ H_s(w_1(x)) $$

Here we send read $$ r_3(x) $$ back in time to read the output of the transaction $$ t_1 $$.

How it could look like without commuting operations in the history? The answer is simple:
with the references to the previous versions of variables.

$$ w_1(x_1) w_2(x_2) r_3(x_1), h(r_3(x)) = w_1(x_1) $$

Here we have a writes that create versions of a variable $$ x $$. And the read that
reads one version of $$ t_1 $$. Function $$ h $$ is called a version function. With
the version function multi-version histories comes into play.

What are multi-version (mv) histories? It is histories with the version function that says
who reads what. A read can read one of the previously written versions of a variable.

If the version function always returns the latest version for reads the history called
monoversion. Conventional histories are equivalent to corresponding monoversion variants.

But so what one could say that we can have mv-histories? Weikum & Wossen gives a
great example of how much bigger the power of scheduling can be with the mv-histories.
Consider following history:

$$ s = r_1(x) w_1(x) r_2(x) w_2(y) r_1(y) w_1(z) c_1 c_2 $$

This history is not conflict-serializable due to the fact that $$ r_1(y) $$ arrived
too late so it creates a cycle in the conflict graph of $$ s $$. This history could
be serializable in example if $$ r_1(y) $$ came before $$ w_2(y) $$:

$$ s_2 = r_1(x) w_1(x) r_2(x) r_1(y) w_2(y) w_1(z) c_1 c_2 $$

$$ s_2 $$ does not have a cycle in the conflict graph so it is conflict-serializable.
That's cool. But we don't control the order in which events arrive in our scheduler.
What we control, is the point in time from which the read operation reads a version.
We can assign a version function so that serializability of $$ s $$ will become
possible:

$$ h(r_1(y)) = w_0(y) $$

That means that $$ r_1(y) $$ will read the version of $$ y $$ written by the initial
transaction $$ t_0 $$: literally the previous version before $$ t_2 $$:

$$ s_{mv} = r_1(x_0) w_1(x_1) r_2(x_1) w_2(y_2) r_1(y_0) w_1(z_1) c_1 c_2 $$

This mv-history $$ s_{mv} $$ is equivalent to the:  

$$ s_{mv2} = r_1(x_0) w_1(x_1) r_2(x_1) r_1(y_0) w_2(y_2) w_1(z_1) c_1 c_2 $$

That is a monoversion history that is equivalent to $$ s_2 $$ and $$ s_2 \in CSR $$.

Thus multi-versioning allows more histories to be serializable even though
serializability notions for mv-histories significantly differ. This comes from
the fact that different writes on the same variable are no more create conflicts
because they don't effect each other, they only create different versions. The
similar history is there for the _wr_ pairs.

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
[2]: https://en.wikipedia.org/wiki/Concurrency_control
