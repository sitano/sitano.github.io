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
Each node is preseeded with specific number to setup deterministic
sequence of pseudo-random numbers $$N$$. A message $$m$$ contains a
pseudo-random number $$ n \in N \,|\, n \in (0, 1] $$.

When a cluster starts up, the nodes learn about each other. Then during
the grace period they are sending messages. After a while cluster
receives a signal to stop sending.

When a signal is received by a node it prints a tuple:

$$ \left\langle |M|, \sum_{i=1}^{|M|} (i * m_i) \right\rangle $$

consisting of a number of all messages that was sent and a score,
where $$M$$ is a set of all messages sent in a grace period ordered
by sending time, $$|M|$$ is a size of a set $$M$$,
a $$m_i$$ is a $$i$$th message from $$M$$ sent by some node.

Implement a program that works correctly and maximizes output score.
Correctness must be hold under different failure scenarios.
