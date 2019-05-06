---
layout: post
title: Distributed systems problem - banks
categories: [distsys, problems]
tags: [distsys, problems, task, interview, test]
mathjax: true
source: "Mesosphere"
---

This continues a series of problems in a field of distributed systems
to be solved to learn or for discussing at interviews. [Previous][1] one
is available here. The lack of precise formulation of the tasks adds
to the number of possibilities to consider when thinking about solutions.

## Task

### Part 1

Create a program that behaves like a bank and exposes following API:

* POST /create/:account: - create new account
* GET  /account/:account:/balance - returns current account balance
* POST /transfer/local {"from", "to", "amount"} - transfers money

Objectives are:

1. Don't lose money
2. Be thread safe
3. Be crash-tolerant.

### Part 2

Let's assume there are many independent banks. Each bank has its own
unique ID and they want to make transfers between each other. Implement
protocol and cross-bank transfers.

* POST /config [{id: address}]
* POST /transfer/international {"from", "to", "amount"}

Let's assume banks can not have correspondent accounts.

Describe what can go wrong and what ways of solving it are there?

[1]: http://sitano.github.io/distsys/problems/2019/05/05/distsys-problem-counters-db/ "previous task"
