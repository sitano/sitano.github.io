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

$$ w_1(x_1) w_2(x_2) r_3(x_1), h(r_3(x)) = w_1(x) $$

Here we have a writes that create versions $$ \{ x_1, x_2 \} $$
of a variable $$ x $$. And the read that reads one version of $$ t_1 $$.
Function $$ h $$ is called a version function. With the version function
the multi-version histories comes into play.

Such histories like one above are called multi-version (mv) histories. It is histories
with defined version function that says who reads what. A read operation can read one of
the previously written versions of a variable. If the version function always returns
the latest version for reads the history called monoversion. Conventional histories
are equivalent to corresponding monoversion variants.

With mv histories we can produce more serializable schedules. Weikum & Vossen gives
a great example of how much bigger the power of scheduling can be with the mv-histories.
Consider the following history:

$$ s = r_1(x) w_1(x) r_2(x) w_2(y) r_1(y) w_1(z) c_1 c_2 $$

![]({{ Site.url }}/public/mvcc/chsgcg.png)

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
transaction $$ t_0 $$ literally the previous version before $$ t_2 $$:

$$ m = r_1(x_0) w_1(x_1) r_2(x_1) w_2(y_2) r_1(y_0) w_1(z_1) c_1 c_2 $$

This multi-version history $$ m $$ is conflict equivalent to the:  

$$ m_2 = r_1(x_0) w_1(x_1) r_2(x_1) [ r_1(y_0) w_2(y_2) ] w_1(z_1) c_1 c_2 $$

in which we only commuted 2 operations. $$ m_2 $$ is a monoversion history that is
equivalent to $$ s_2 $$ and $$ s_2 \in CSR $$:

$$ s_2 = r_1(x) w_1(x) r_2(x) r_1(y) w_2(y) w_1(z) c_1 c_2 $$

Now when it's obvious that MVCC is capable of producing more of a correct
serializable schedulers let's take a look at how the serializability works
in a case of multi-version histories.

Multi-version serializability
---

There are 2 kinds of MV serializability:

- MVSR - multi-version view serializability
- MCSR - multi-version conflict serializability

MVSR is defined by the analogy with the VSR:
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
no _ww_ and _wr_ pairs in the mv-conflict set because commuting _ww_
does not change anything for the following read operations,
and commuting _wr_ pairs does not affect the read variants
space in a negative way so if the history with _rw_ pair
is serializable the one with the _wr_ pair is serializable
as well.

This asymmetry leads to the asymmetry in serializability class
definition such that it's $$ m $$ conflict pairs must occur in
the same order in $$ m' $$, not the pairs from $$ m' $$. More
details in [[3]]. I have spent some time reading out the
definition of the MCSR in Vossen & Weikum book because they
do not make an accent on that nuance from my point of view.

The relation between classes is as follows:

$$ CSR \subset MCSR \subset MVSR \subset {histories} \\ $$
$$ CSR \subset VSR \subset MVSR\\ $$

On testing serializability
---

Let's take a look at how a history may be tested for the multi-version
serializability. We will start with testing for MCSR and then
continue with the MVSR with this example:

$$ m = w_0(x_0) w_0(y_0) c_0 w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 r_3(y_0) w_3(x_3) c_3 $$

Let's draw a multi-version conflict graph (MVCG):

![]({{ Site.url }}/public/mvcc/mv_conflict_graph.png)

MVCG has no cycles and thus is acyclic. Hence $$ m \in MCSR $$. For even
greater simplicity let's take a look at the $$ m $$ step-graph along with
the MV conflict set. It will show us in a graphical way where the single
conflict edge $$ x $$ originates from and what we can commute to get
serial monoversion history $$ m' $$ that will be $$ m \approx_c m' $$.

![]({{ Site.url }}/public/mvcc/mv_step_graph_wcs.png)

Now let's commute something in $$ m $$ to find $$ m' $$ - serial monoversion history.
What can confuse here is that the history $$ m $$ is already serial but not monoversion.
Intuitively, what you would try to do first is to have $$ m' = t_0 t_3 t_1 t_2 $$
but it is incorrect, because reverses conflict pair $$ (r_2(x_1), w_3(x_3)) $$
which we can't commute. So the only chance we have is to move $$ t_0 $$ forward,
commuting operations 1-by-1:

$$
m = w_0(x_0) w_0(y_0) c_0 w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 r_3(y_0) w_3(x_3) c_3 \\
[ w_0(x_0) w_0(y_0) c_0 ] [ w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 ] r_3(y_0) w_3(x_3) c_3 \\
[ w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 ] [ w_0(x_0) w_0(y_0) c_0 ] r_3(y_0) w_3(x_3) c_3 \\
m' = w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 w_0(x_0) w_0(y_0) c_0 r_3(y_0) w_3(x_3) c_3 \\
m' = t_1 t_2 t_0 t_3 \\
\approx \\
s' = w_1(x) c_1 r_2(x) w_2(y) c_2 w_0(x) w_0(y) c_0 r_3(y) w_3(x) c_3 \\
= t_1 t_2 t_0 t_3
$$

The fun part is that we moved our transactions $$ t_1, t_2 $$ back in time behind
the $$ t_0 $$ that is an initial state transaction. However, commuting $$ t_0 $$
did not prevent us from imagining the proper serial monoversion history even tho
the whole thing is equivalent to the history in which we send scheduling transactions
even further back in time.

The conflicts of $$ m $$ occur in the same order in $$ m' $$ so we are good:

![]({{ Site.url }}/public/mvcc/mvsm_step_graph_wcs.png)

We have proved that $$ m \in MCSR $$ and found serial monoversion $$ m' $$
such that $$ m \approx_c m' $$.
Now let's take a look at how $$ m $$ looks like in MVSR. We already know
that $$ MCSR \subset MVSR $$ so $$ m \in MCSR \Rightarrow m \in MVSR $$.

But in anyway, is it $$ m' $$ that we found for the MCSR case is sufficient
for the MVSR. Let's test it!

First of all, let's prove that $$ m \in MVSR $$ on it's own.
We will build a multi-version serializability graph (MVSG) to see it is
acycle. We can't do that without defining a version order relation up front.
In anyway, MVSR is defined as $$ RF(m) = RF(m') $$, so let's start with the
step-graph with read-from relation:

![]({{ Site.url }}/public/mvcc/mv_step_graph_wrf.png)

What you see here is 1/3 of the MVSG edges that consists of the conflict
graph $$ G(s) $$ that are _wr_ edges of the form $$ (w_i(x_i), r_j(x_i)) $$.
The rest consists of the conflicts depending on the versions order.

Now taking the version ordering from our $$ m' $$ MCSR case we are having:

$$
x_1 << x_0 << x_3 \\
y_2 << y_0
$$

For $$ r_2(x_1) $$ we have $$ w_1(x_1) <_{m'} r_2(x_1) <_{m'} w_0(x_0) $$ and
$$ w_1(x_1) <_{m'} r_2(x_1) <_{m'} w_3(x_3) $$ so we must add 2 edges to the MVSG:
$$ \{(r_2(x_1), w_0(x_0)), (r_2(x_1), w_3(x_3))\} $$.

For $$ r_3(y_0) $$ we have $$ w_2(y_2) <_{m'} w_0(y_0) <_{m'} r_3(y_0) $$
so we must add an edge to the MVSG: $$ (w_2(y_2), w_0(y_0)) $$.

So we have got:

![]({{ Site.url }}/public/mvcc/mv_step_graph_wcs2.png)

By collapsing operations into the transactions vertices we can obtain a MVSG:

![]({{ Site.url }}/public/mvcc/mvsg.png)

It's easy to see it is acycle and that means $$ m \in MVSR $$ and the version
order we picked based on $$ m' $$ serial monoversion history is good enough.

For more curiosity we can compare _read-from_ sets of $$ m, m' $$:

$$
m = w_0(x_0) w_0(y_0) c_0 w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 r_3(y_0) w_3(x_3) c_3 \\
RF(m) = \{ (t_1, x, t_2), (t_0, y, t_3) \} \\
m' = w_1(x_1) c_1 r_2(x_1) w_2(y_2) c_2 w_0(x_0) w_0(y_0) c_0 r_3(y_0) w_3(x_3) c_3 \\
= t_1 t_2 t_0 t_3 \\
RF(m') = \{ (t_1, x, t_2), (t_0, y, t_3) \} \\
\Rightarrow \\
RF(m) = RF(m') \\
\Rightarrow \\
m \in MVSR
$$

And finally for those who are curious how the version function looks like
for $$ m $$:

$$
h(r_2(x)) = w_2(x) \\
h(r_3(y)) = w_0(y) \\
h(w_i(a)) = w_i(a)
$$

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
[3]: https://www.sciencedirect.com/science/article/pii/002200008690022X "Algorithmic aspects of multiversion concurrency control by Thanasis Hadzilacos, Christos Harilaos Papadimitriou, march 1985"
