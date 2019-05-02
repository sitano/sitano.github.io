---
layout: post
title: Distributed systems problem - random sequence
categories: [distsys, problems]
tags: [distsys, problems, task, interview, test]
mathjax: true
source: "CH/OTP by IOHK, John M."
---

This opens a series of problems in a field of distributed systems
to be solved to learn or for discussing at interviews. They are
useful to reason about and understand fundamentals.

## Task

A cluster consists of a set of nodes. Nodes in a cluster communicate
by means of messages. Each node sends a messages to all other nodes.
Each node is preseeded with some number to setup deterministic
sequence of pseudo-random numbers $$N$$. An arbitrarily taken message
$$m$$ contains a pseudo-random number $$ n \in N \,|\, n \in (0, 1] $$.

When a cluster starts up, the nodes learn about each other. Then during
the grace period they are sending messages. After a while cluster
receives a signal to stop sending. When a stop signal is received by
a node and it is ready it prints a tuple:

$$ \left\langle |M|, \{m_i\}, \sum_{i=1}^{|M|} (i * m_i) \right\rangle $$

consisting of a number of all messages that were send in a grace period,
$$ \{m_i\} \,|\, m \in M $$ a sequence of all messages that was sent in
a grace period in order and a score, where $$M$$ is a set of all
messages sent by all nodes in a grace period ordered by sending time,
$$|M|$$ is a size of a set $$M$$, a $$m_i$$ is a $$i$$th message from
$$M$$ sent by some node.

$$ -[start]-[discover]-[sending]------[signal]-[result]----T-> t $$

If a node did not finish before the time point T from cluster
startup it is terminated and considered failed.

Implement a program that works correctly and maximizes output score.
Correctness must be hold under different failure scenarios. Describe
what can go wrong and how the solution handle failures.

What are the [safety][1] and [liveness][2] [properties][3] of that
system would be? How would you test properties of such a program?

[1]: https://en.wikipedia.org/wiki/Safety_property "safety"
[2]: https://en.wikipedia.org/wiki/Liveness        "liveness"
[3]: http://cecs.wright.edu/~pmateti/Courses/7370/Lectures/Fundas/safety-liveness.html "properties"
[4]: https://www.cs.cornell.edu/fbs/publications/RecSafeLive.pdf "Recognizing safety and liveness by Bowen Alpern and Fred B. Schneider"
[5]: https://lamport.azurewebsites.net/pubs/implementation.pdf   "The Implementation of Reliable Distributed Multiprocess Systems"
[6]: https://amturing.acm.org/p558-lamport.pdf                   "Time, Clocks, and the Ordering of Events in a Distributed System by Leslie Lamport"
