---
layout: post
title: What you have to know about Consul and how to beat the outage problem
---

For those of you how are opened to the experimenting,
you can start launching 3 consul docker instances
and playground around it.

Give your servers some configuration, i.e.:

        {
            "leave_on_terminate": false,
            "skip_leave_on_interrupt": false,
            "bootstrap_expect": 3,
            "server": true,
            "retry_join": [ ... ],
            "rejoin_after_leave": true
        }

Start consuls:

        $ docker run -P -v /tmp/node1:/data --name node1 -h node1 -i -t --entrypoint=/bin/bash progrium/consul
        $$ consul agent -config-file=/data/config -data-dir=/data

To the rest, you should know the following:

How Consul manages cluster membership
=====================================

Consul does the cluster management in the 3 levels:

        /---------------------\
        | L3. Serf            | <-> WAN interconnectivity
        |                     |                       ^
        | - peers list        |                       |
        | WAN connected nodes |         (broadcasting)|
        |                     |                       |
        \---------------------/                       |
        /-----------------------------------\         v
        | L2. Serf                          | <-> LAN interconn
        |                                   |      | - node join
        | - peers list                      |      | - node leave
        | LAN connected servers and clients |      | - node reap
        | - node1 (srv)                     |      | - ign: update
        | - node2 (srv)                     |      | - ign: user
        | - node3 (cli)                     |      | - ign: qry
        |                                   |      |
        \-----------------------------------/      |
        /-------------------------\                v
        | L1. Raft                | <-> Quorum consensus
        |                         |     Leadeship election
        | - LAN srvs peers list   |     (leader do)
        | consistent fsm and db   |             |
        | journal / log           |        (r/w)|
        | followers streaming     |             |
        |                         |             |
        \-------------------------/             v
        /----------------------------------------------\
        | KV DB <-> Key-Value persistent storage       |
        |                                              |
        | - consistent writes, con/stale reads allowed |
        \----------------------------------------------/
        /--------------------\
        | Events ss          |
        |                    |+---> LAN/WAN broadcast
        | - lan broadcasting |
        \--------------------/

What to look at
---------------

* Consul `servers` are not the same as Consul `clients`.
* Serf manages membership questions like node join / leave.
* Raft manages leadership questions and consistency.
* Each level of management has its own `peers list` (nodes joined or leaved).
  The key word here is - they are separate and handled separately.
* What you want is to keep quorum in a fine state (leader is present) -
  thats why you should be interested in the state of the **Raft** peers list
  which can _differ_ from what LAN level _serf_ currently observes.
* The point of having _Raft_ peers list separate for Consul is to have a list
  of nodes which are deciding who will be the leader in the quorum, because
  LAN`s list for example also contains all clients inside.
* Raft peers list controlled by the 1) Leader 2) LAN Serf layer events
  (join / leave).
* Raft (L1) and Serf (L2) peers lists can be unsynced in a way of containing
  totally different nodes. In that case, if your raft peers list contains
  some old nodes ip's which missing in the lan`s serf, then you have to
  go and get rid of them [manually](https://www.consul.io/docs/guides/outage.html).
* You can add or remove nodes from the quorum until it is in the consistent
  (leader present) state and there are at least 2 nodes present.

The whole point of [outage](https://www.consul.io/docs/guides/outage.html) page
is a) you are responsible for the quorum health, b) you are responsible for
the right values in the raft peers list, c) if something went wrong, fix **manually**
raft peers at every server node and restart the whole cluster.

For quorum to be healthy it is necessary for every node to know the neighbours that are
kept in the raft peers list at `raft/peers.json`. You should have at least 2
known nodes there (i.e. self + another one is allowed, and self btw may be omitted)
in order for quorum to be able to elect a leader on startup.

Available operational modes are:

* `Single node cluster` must be explicitly enabled with a special flag which
  restrict any other configuration (more than 1 known server) for this specific node.
  It can not be part of any other cluster.

* `Multi nodes cluster` enables omitting `single` mode flags. From the point of view
  of this mode, presence of the single mode means the `leader` can be elected even
  in the case of *at least 2* nodes are present - its fine for Consul. It can go with 2.
  Its not recommended though.

This way multi nodes cluster can't go under 2 nodes quorum. In that state it will stop
working (it will give up leadership because single node mode in this mode is not allowed).

From the other side, if node came to a 1 single node state, it means you have a
brain split situation in which it can't operate further, as it will suppose
the majority of the nodes is somewhere there.

The states are:

* `Bootstrap` and `bootstrap expect` which are the same in a way of the second
  introduces `expectation` number of nodes to start quorum from scratch. No actions
  in this mode will be taken until all `expected` nodes appeared up and known.

* `Initialized` means literally `bootstrap` happened once ago. Both `raft/` and `serf/`
  path should be present representing current node state. In this mode any bootstrap
  flags stops have any meaning.

What are your `bootstrap` and `expect` server values
----------------------------------------------------

_in progress..._

Where are your `raft/peers.json`, `serf/local.snapshot` locates and what they contain
-------------------------------------------------------------------------------------

_in progress..._

Configuration of `leave` event issuing on termination
-----------------------------------------------------

_in progress..._

* `leave_on_terminate`
* `skip_leave_on_interrupt`

What to do in the outage situation
==================================

_in progress..._
