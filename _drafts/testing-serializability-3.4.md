---
layout: post
title: Testing serializability classes
categories: [theory, databases]
tags: [theory, databases, examples, transactions, anomalies]
mathjax: true
---

Recently, I came across an excellent exercise of testing a scheduling
history for belonging to different serializability classes and had
a lot of fun drawing polygraph and finding out a cycle in it.
When I finally managed to draw the correct version of the polygraph,
I thought that it could be interesting to someone wondering to know
how testing for view state serializability looks like.

In this article, I will show how to find out to what serializability
class the following history

$$ s = r_1(x) r_3(x) w_3(y) w_2(x) r_4(y) c_2 w_4(x) c_4 r_5(x) c_3 w_5(z) c_5 w_1(z) c_1 $$

belongs. Basically we will be looking at final state serializability
(FSR), view state serializability (VSR) and conflict state
serializability (CSR).

First of all, let's take a look at steps grouped by transaction id:

{% graphviz %}
digraph "step graph" {
  rankdir="LR"; ranksep=0.2; fontname="Roboto";
  node [shape=plaintext fontsize=12 margin=0.05 width=0 height=0 fontname="MJXc-TeX-math-I,MJXc-TeX-math-Ix,MJXc-TeX-math-Iw"];
  edge [arrowsize=0 minlen=1 penwidth=0.5];

  subgraph t {
    mindist=100.0;
    0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> inf
  }

  subgraph t1 {
    t1 -> "r1(x)" -> "w1(z)" -> c1 -> e1
  }

  subgraph t2 {
    t2 -> "w2(x)" -> c2 -> e2
  }

  subgraph t3 {
    t3 -> "r3(x)" -> "w3(y)" -> c3 -> e3
  }

  subgraph t4 {
    t4 -> "r4(y)" -> "w4(x)" -> c4 -> e4
  }

  subgraph t5 {
    t5 -> "r5(x)" -> "w5(z)" -> c5 -> e5
  }

  { rank = "same"; "0";  t1 t2 t3 t4 t5 }
  { rank = "same"; "1";  "r1(x)" }
  { rank = "same"; "2";  "r3(x)" }
  { rank = "same"; "3";  "w3(y)" }
  { rank = "same"; "4";  "w2(x)" }
  { rank = "same"; "5";  "r4(y)" }
  { rank = "same"; "6";  "c2" }
  { rank = "same"; "7";  "w4(x)" }
  { rank = "same"; "8";  "c4" }
  { rank = "same"; "9";  "r5(x)" }
  { rank = "same"; "10"; "c3" }
  { rank = "same"; "11"; "w5(z)" }
  { rank = "same"; "12"; "c5" }
  { rank = "same"; "13"; "w1(z)" }
  { rank = "same"; "14"; "c1" }
  { rank = "same"; inf;  e1 e2 e3 e4 e5 }
}
{% endgraphviz %}

Here, we have 5 transactions $$ t_1, t_2, t_3, t_4, t_5 $$. We imply complete
history with $$ t_0, t_{inf} $$, where $$ op_i(x) $$ means read or write in transaction
$$ i $$ of a data item $$ x $$.

Let's start with testing for the CSR. To do that, we will draw
the conflict graph for $$ s $$.

Note:

- conflict graph
- conflict relation
- conflict set

For the greater fun let's start with drawing conflict set $$ conf(s) $$ of $$ s $$.

{% graphviz %}
digraph "conflict step graph" {
  rankdir="LR"; ranksep=0.2; fontname="Roboto";
  node [shape=plaintext fontsize=12 margin=0.05 width=0 height=0 fontname="MJXc-TeX-math-I,MJXc-TeX-math-Ix,MJXc-TeX-math-Iw"];
  edge [arrowsize=0 minlen=1 penwidth=0.5];

  subgraph t {
    mindist=100.0;
    0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> inf
  }

  subgraph t1 {
    t1 -> "r1(x)" -> "w1(z)" -> c1 -> e1
  }

  subgraph t2 {
    t2 -> "w2(x)" -> c2 -> e2
  }

  subgraph t3 {
    t3 -> "r3(x)" -> "w3(y)" -> c3 -> e3
  }

  subgraph t4 {
    t4 -> "r4(y)" -> "w4(x)" -> c4 -> e4
  }

  subgraph t5 {
    t5 -> "r5(x)" -> "w5(z)" -> c5 -> e5
  }

  { rank = "same"; "0";  t1 t2 t3 t4 t5 }
  { rank = "same"; "1";  "r1(x)" }
  { rank = "same"; "2";  "r3(x)" }
  { rank = "same"; "3";  "w3(y)" }
  { rank = "same"; "4";  "w2(x)" }
  { rank = "same"; "5";  "r4(y)" }
  { rank = "same"; "6";  "c2" }
  { rank = "same"; "7";  "w4(x)" }
  { rank = "same"; "8";  "c4" }
  { rank = "same"; "9";  "r5(x)" }
  { rank = "same"; "10"; "c3" }
  { rank = "same"; "11"; "w5(z)" }
  { rank = "same"; "12"; "c5" }
  { rank = "same"; "13"; "w1(z)" }
  { rank = "same"; "14"; "c1" }
  { rank = "same"; inf;  e1 e2 e3 e4 e5 }

  edge [arrowsize=0.5 color=red];

  "w5(z)" -> "w1(z)"
  "w4(x)" -> "r5(x)"
  "w3(y)" -> "r4(y)"
  "r3(x)" -> "w2(x)"
  "r3(x)" -> "w4(x)"
  "w2(x)" -> "w4(x)"
  "w2(x)" -> "r5(x)"
  "r1(x)" -> "w2(x)"
  "r1(x)" -> "w4(x)"
}
{% endgraphviz %}

The cycle is easy to see here at:

$$ \{(r_1(x), w_2(x)), (w_2(x), r_5(x)), (w_5(z), w_1(z))\} \subset conf(s) $$

However, let's show that $$ D_2(s) $$ (conflict-step graph) is not acyclic and
thus $$ s \notin CSR $$:

{% graphviz %}
digraph "d2(s)" {
  node [shape=plaintext fontsize=12 margin=0.05 width=0 height=0 fontname="MJXc-TeX-math-I,MJXc-TeX-math-Ix,MJXc-TeX-math-Iw"];
  edge [arrowsize=0.5 minlen=1 penwidth=0.5];

  t1 -> t2 [label=x color=red];
  t2 -> t5 [label=x color=red];
  t2 -> t4 [label=x];
  t3 -> t2 [label=x];
  t4 -> t5 [label=x];
  t3 -> t4 [label="x,y"];
  t5 -> t1 [label=z color=red];
}
{% endgraphviz %}

We have proved that $$ s $$ does not belong to the CSR class.
It is time to test if $$ s $$ belongs to the VSR - the most
funniest part of the check. We first test if $$ s \in VSR $$
and then if it does find $$ s' - serial | s \approx_v s' $$.

To make drawing $$ s $$ polygraph easier let's draw useful
steps in $$ s $$ with $$ RF(s) $$ first.

Note. $$ RF(s) $$ is a read-from relation over $$ s $$ defined as
$$ RF(s) = {(t_i, x, t_j)\ |\ \text{an}\ r_j(x)\ \text{reads}\ x\ \text{from a}\ w_i(x)} $$.

Note. A step $$ p $$ is directly useful for a step $$ q $$,
denoted $$ p \rightarrow q $$, if $$ q $$ reads from $$ p $$, or if $$ p $$
is a read step and $$ q $$ a subsequent write step from the same
transaction.

{% graphviz %}
digraph "RF(s)" {
  rankdir="LR"; ranksep=0.2; fontname="Roboto";
  node [shape=plaintext fontsize=12 margin=0.05 width=0 height=0 fontname="MJXc-TeX-math-I,MJXc-TeX-math-Ix,MJXc-TeX-math-Iw"];
  edge [arrowsize=0 minlen=1 penwidth=0.5];

  subgraph t {
    mindist=100.0;
    0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> inf
  }

  subgraph t1 {
    t1 -> "r1(x)" -> "w1(z)" -> c1 -> e1
  }

  subgraph t2 {
    t2 -> "w2(x)" -> c2 -> e2
  }

  subgraph t3 {
    t3 -> "r3(x)" -> "w3(y)" -> c3 -> e3
  }

  subgraph t4 {
    t4 -> "r4(y)" -> "w4(x)" -> c4 -> e4
  }

  subgraph t5 {
    t5 -> "r5(x)" -> "w5(z)" -> c5 -> e5
  }

  { rank = "same"; "0";  t1 t2 t3 t4 t5 }
  { rank = "same"; "1";  "r1(x)" }
  { rank = "same"; "2";  "r3(x)" }
  { rank = "same"; "3";  "w3(y)" }
  { rank = "same"; "4";  "w2(x)" }
  { rank = "same"; "5";  "r4(y)" }
  { rank = "same"; "6";  "c2" }
  { rank = "same"; "7";  "w4(x)" }
  { rank = "same"; "8";  "c4" }
  { rank = "same"; "9";  "r5(x)" }
  { rank = "same"; "10"; "c3" }
  { rank = "same"; "11"; "w5(z)" }
  { rank = "same"; "12"; "c5" }
  { rank = "same"; "13"; "w1(z)" }
  { rank = "same"; "14"; "c1" }
  { rank = "same"; inf;  e1 e2 e3 e4 e5 }

  edge [arrowsize=0.5 color=blue];

  "w1(z)" -> "e1"
  "w4(x)" -> "e4"
  "w3(y)" -> "e3"

  "w4(x)" -> "r5(x)"
  "w3(y)" -> "r4(y)"

  "t3" -> "r3(x)"
  "t1" -> "r1(x)"

  edge [arrowsize=0.5 color=gray];

  "r3(x)" -> "w3(y)"
  "r4(y)" -> "w4(x)"
  "r1(x)" -> "w1(z)"
}
{% endgraphviz %}

Blue lines depict $$ RF(s) $$ relation. In example in pair
$$ (r_1(z), e_1) \in RF(s), e_i = t_\infty $$ the transaction $$ t_\infty $$
reads $$ z $$ from the latest write in $$ s $$ of $$ z $$ from
transaction $$ t_1 $$ as defined by the $$ H[s]
$$ ($$ H[s](z) = H_s(w_1(z)) $$).

Let's also add few important conflicts from the $$ conf(s) $$
to our graph to see where we will have cycle in choices.

{% graphviz %}
digraph "RF(s)" {
  rankdir="LR"; ranksep=0.2; fontname="Roboto";
  node [shape=plaintext fontsize=12 margin=0.05 width=0 height=0 fontname="MJXc-TeX-math-I,MJXc-TeX-math-Ix,MJXc-TeX-math-Iw"];
  edge [arrowsize=0 minlen=1 penwidth=0.5];

  subgraph t {
    mindist=100.0;
    0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> inf
  }

  subgraph t1 {
    t1 -> "r1(x)" -> "w1(z)" -> c1 -> e1
  }

  subgraph t2 {
    t2 -> "w2(x)" -> c2 -> e2
  }

  subgraph t3 {
    t3 -> "r3(x)" -> "w3(y)" -> c3 -> e3
  }

  subgraph t4 {
    t4 -> "r4(y)" -> "w4(x)" -> c4 -> e4
  }

  subgraph t5 {
    t5 -> "r5(x)" -> "w5(z)" -> c5 -> e5
  }

  { rank = "same"; "0";  t1 t2 t3 t4 t5 }
  { rank = "same"; "1";  "r1(x)" }
  { rank = "same"; "2";  "r3(x)" }
  { rank = "same"; "3";  "w3(y)" }
  { rank = "same"; "4";  "w2(x)" }
  { rank = "same"; "5";  "r4(y)" }
  { rank = "same"; "6";  "c2" }
  { rank = "same"; "7";  "w4(x)" }
  { rank = "same"; "8";  "c4" }
  { rank = "same"; "9";  "r5(x)" }
  { rank = "same"; "10"; "c3" }
  { rank = "same"; "11"; "w5(z)" }
  { rank = "same"; "12"; "c5" }
  { rank = "same"; "13"; "w1(z)" }
  { rank = "same"; "14"; "c1" }
  { rank = "same"; inf;  e1 e2 e3 e4 e5 }

  edge [arrowsize=0.5 color=blue];

  "w1(z)" -> "e1"
  "w4(x)" -> "e4"
  "w3(y)" -> "e3"

  "w4(x)" -> "r5(x)"
  "w3(y)" -> "r4(y)"

  "t3" -> "r3(x)"
  "t1" -> "r1(x)"

  edge [arrowsize=0.5 color=gray];

  "r3(x)" -> "w3(y)"
  "r4(y)" -> "w4(x)"
  "r1(x)" -> "w1(z)"

  edge [arrowsize=0.5 color=red];

  "r1(x)" -> "w2(x)"
  "w2(x)" -> "w4(x)"
  "w5(z)" -> "w1(z)"
}
{% endgraphviz %}

These conflicts clearly demonstrates the limits until which the transactions
can be moved before breaking their $$ RF(s) $$ relation with $$ s' - serial$$.
Having those conflicts depicted it can be clearly seen that there is no such a
serial transaction exist that $$ s'\ -\ \text{serial}\ |\ s \approx_v s' $$
due to the:

$$ t_1 <_{s,x}\ t_2 <_{s,x}\ t_4 <_{s,x}\ t_5 <_{s,z}\ t_1 $$

Now, having all that in mind, let's draw polygraph and prove we were right.
We will start with drawing only $$ (V, E) $$ part of the $$ P(s) $$ for
simplicity.

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
