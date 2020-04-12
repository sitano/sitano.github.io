---
layout: post
title: Testing FSR+VSR,CSR serializability showcase
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

## References

- [Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition][1].

[1]: https://www.amazon.com/Transactional-Information-Systems-Algorithms-Concurrency/dp/1558605088 "Transactional Information Systems: Theory, Algorithms, and the Practice of Concurrency Control and Recovery (The Morgan Kaufmann Series in Data Management Systems) 1st Edition by Gerhard Weikum, Gottfried Vossen, Morgan Kaufmann; 1 edition (June 4, 2001)"
