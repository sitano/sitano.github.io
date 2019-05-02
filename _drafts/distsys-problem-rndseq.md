---
layout: post
title: Distributed systems problem - random sequence
categories: [distsys, problems]
tags: [distsys, problems, task, interview, test]
mathjax: true
---

This opens a series of problems in a field of distributed systems
to be solved to learn or for discussing at interviews. They are
useful to reason about to understand fundamentals.

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

$$ \left\langle \{m\}_i, \sum_{j=1}^{|M|} (j * m_j) \right\rangle $$

consisting of $$ \{m\}_i \,|\, m \in M $$ a sequence of all messages
that was sent by a node $$i$$ and a score, where $$M$$ is a set of all
messages sent by all nodes in a grace period ordered by sending time,
$$|M|$$ is a size of a set $$M$$, a $$m_j$$ is a $$j$$th message from
$$M$$ sent by some node.

$$ -[start]-[discover]-[sending]------[signal]-[result]----T-> t $$

If a node did not finish before the time point T from cluster
startup it is terminated and considered failed.

Implement a program that works correctly and maximizes output score.
Correctness must be hold under different failure scenarios.

What are the [safety][1] and [liveness][2] [properties][3] of that
system would be? What assumptions you see reasonable to pick?
What failures are possible? How your algorithm fails gracefully?

[1]: https://en.wikipedia.org/wiki/Safety_property "safety"
[2]: https://en.wikipedia.org/wiki/Liveness        "liveness"
[3]: http://cecs.wright.edu/~pmateti/Courses/7370/Lectures/Fundas/safety-liveness.html "properties"
[4]: https://www.cs.cornell.edu/fbs/publications/RecSafeLive.pdf "Recognizing safety and liveness by Bowen Alpern and Fred B. Schneider"
