---
layout: post
title: Testing serializability classes showcase
categories: [theory, databases]
tags: [theory, databases, examples, transactions, anomalies]
mathjax: true
---

Recently I came up across a nice exercise of testing a scheduling
history for belonging to different serializability classes and had
a lot of fun drawing polygraph and finding out a cycle in it.
After I successfully managed to finally draw the correct version of
the polygraph I thought that it could be interesting to someone
wondering to know how testing for view state serializability
looks like.

In this article I will show how to find out to what serializability
class the following history:

$$ s = r_1(x) r_3(x) w_3(y) w_2(x) r_4(y) c_2 w_4(x) c_4 r_5(x) c_3 w_5(z) c_5 w_1(z) c_1 $$

belongs. Basically we will be looking at final state serializability
(FSR), view state serializability (VSR) and conflict state
serializability (CSR).

First of all, let's take a look at steps grouped by transactions
and order:

{% graphviz %}
digraph "some graphviz title" {
  rankdir="LR"
  node [shape=plaintext, fontsize=14];
  size = "200, 200";

  subgraph t {
    0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11 -> 12 -> 13 -> 14 -> inf
  }

  subgraph t1 {
    "r1(x)" -> "w1(z)" -> c1
  }

  subgraph t2 {
    "w2(x)" -> c2
  }

  subgraph t3 {
    "r3(x)" -> "w3(y)" -> c3
  }

  subgraph t4 {
    "r4(y)" -> "w4(x)" -> c4
  }

  subgraph t5 {
    "r5(x)" -> "w5(z)" -> c5
  }

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
}
{% endgraphviz %}

Here, we have 5 transactions $$ t_1, t_2, t_3, t_4, t_5 $$. We imply complete
history with $$ t_0, t_{inf} $$. $$ op_i(x) $$ means read or write in transaction
$$ i $$ of a data item $$ x $$.

Let's start with testing for the CSR. To do that, we will draw
the conflict graph for $$ s $$.

Note:

- conflict graph
- conflict relation
- conflict set

For the greater fun let's start with drawing conflict relations $$ conf(s) $$.

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
