---
layout: post
title: What you have to know about Consul and how to beat the outage problem
---

For those of you who are opened to the experimenting,
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
* Serf manages membership questions like node joining / leaving.
* Raft manages leadership questions and consistency.
* Each level of management has its own `peers list` (nodes joined or leaved).
  The key word is - they are separate and handled separately.
* What you want is to keep quorum in a fine state (leader is present) -
  thats why you should be interested in the state of the **Raft** peers list
  (which can _differ_ from what LAN level _serf_ currently observes).
* The point of having _Raft_ peers list separate is to have a list
  of nodes which are deciding who will be the leader in the quorum, because
  LAN`s list for example also contains all clients inside.
* Raft peers list controlled by the 1) Leader (actual join / leave management)
  2) LAN Serf layer events (new, failed, left nodes events).
* Raft (L1) and Serf (L2) peers lists may be unsynced in a way of containing
  totally different nodes. In that case, if your raft peers list contains
  some old nodes ip's which missing in the lan`s serf, then you have to
  go and get rid of them [manually](https://www.consul.io/docs/guides/outage.html).
* You can add or remove nodes from the quorum until it is in the consistent
  (leader present) state and there are at least 2 nodes present.

The whole point of the [Outage](https://www.consul.io/docs/guides/outage.html) page
is a) you are responsible for the quorum health, b) you are responsible for
the right values in the raft peers list, c) if something went wrong, fix
raft peers **manually** at every server node and restart the whole cluster.

For quorum to be healthy it is necessary for every node to know the neighbours that are
kept in the raft peers list at `raft/peers.json`. You should have at least 2
known nodes there (i.e. self + another one at least, and self btw may be omitted)
in order for quorum to be able to elect a leader on startup.

Available node states are:

* `bootstrap` is a bootstrapping mode in which you allow a single consul node
  to elect it self as a leader of its own single node cluster. You are not allowed
  to have another nodes joined / found in the cluster started in this mode. Both
  servers joined in this mode will found each other in the _serf_ peers list, but
  not in _raft_ - so they will not build up a quorum. Though they will keep holding
  self leadership each.

* `bootstrap expect` is another bootstrap mode which allows multi nodes quorum.
  It introduces `expectation` number, which is the number of server nodes to wait for
  quorum start. No actions in this mode will be taken until all `expected` nodes
  appeared up and known.

* `Initialized` means literally bootstrap happened once ago. `raft/` and `serf/`
  path should be present representing current node state. In this mode, in the
  case of multi nodes quorum, it can be built up from ground up having at least 2
  nodes in _raft_ peers with no respect to original `expect` number (if it was
  for example greater than you end up).

Available operational modes are:

* `Single node cluster` must be explicitly enabled with a special flag (`bootstrap`) which
  restricts any other configuration (more than 1 known server) for this specific node.
  It can not be part of any other cluster.

* `Multi nodes cluster` can enabled by omitting the `single` mode flags. Thanks to _Raft_ -
  `leader` can be elected even in the case of *at least 2* nodes are present.
  Its fine for Consul. It can go with 2. Its not recommended though. Thus,
  multi nodes cluster can't go under 2 nodes quorum. In that state it will lose
  leadership because single node clusters in this mode are not allowed.

  From the other side, if node came to a 1 single node state, it means you have a
  brain split situation in which it can't operate further, as it will suppose
  the majority of the nodes is somewhere there.


What are your `bootstrap` and `expect` server values
----------------------------------------------------

In order to restore your cluster (_raft_ quorum) you need to know/
be sure you have consistent set of those two (bootstrap mode, expect count) values
across your set of consuls servers.

Where are your `raft/peers.json`, `serf/local.snapshot` locates and what they contain
-------------------------------------------------------------------------------------

In the situation of the outage you will want to find out in what state your cluster is.
It can be done through looking across your _serf_ and _raft_ peers list.

* `raft/peers.json` contains current known _raft_ peers set - literally the nodes that
  take part in the quorum and consensus.

* `serf/*.snapshot` contains journal of _serf_ protocol progressing through time. You
  can be interested in it to find out what events took place during the time.

* `./consul members -detailed` or `/v1/catalog/nodes` will show you current _serf_
  (lan / wan) peers list.

        $ docker exec node1 consul members -detailed

* `/v1/status/leader` will give you current leader status in terms of elected node address.

        $ curl -v http://127.0.0.1:8500/v1/status/leader

Configuration of `leave` event on termination
-----------------------------------------------------

There are 2 parameters that effect behaviour of cluster members on shutdown and restart.
You must be interested in considering those if you willing to keep quorum in a fixed state
(i.e. w/o leaving nodes mostly) or restart machines often and in parallel.

It should be decided which mode of operation is preferred: either you allow consul to
auto leave quorum on shutdown, or you count on your self manually managing peers left
with `leave` or `force-leave`.

If you allow consul to publish leaving event on a node shutdown and then pushes whole
cluster to restart you will end up fully broken cluster with no quorum at all.

* [leave\_on\_terminate](https://consul.io/docs/agent/options.html#leave_on_terminate)
  false by default
* [skip\_leave\_on\_interrupt](https://consul.io/docs/agent/options.html#skip_leave_on_interrupt)
  false by default (consider this)

Default response to the signals
-------------------------------

* SIGHUP - Reload, always. Only some things can be reloaded,
* SIGINT - Graceful leave by default, can be configured to be non-graceful,
* SIGTERM - Non-graceful leave. Can be configured to be graceful.

What to do in the outage situation of Multi-Server Cluster
==========================================================

This is kind of situation in which you end up with `No cluster leader` and
it cant heal it self. That means that you lost your quorum and the quorum
lost the majority. Actually in the multi node cluster mode it will mean
that your _raft_ peers links are completely wrong (i.e. case when each node
knows about it self only).

Read the [Outage](https://www.consul.io/docs/guides/outage.html) doc.

In order to make your cluster work again, you have to put it into the consistent
state in which the leader and the quorum are present:

1. Get rid of missing/dead peers from _raft_ peers list,
2. Make rest of good nodes to know about each other, so they should be contained
   in each others _raft_ peers lists.
3. Rebuild the quorum and elect the leader

To achieve this follow this steps:

1. Detect do you have a quorum and the leader present

        $ curl -v http://127.0.0.1:8500/v1/status/leader
        or
        $ curl -v http://127.0.0.1:8500/v1/kv/?keys=&separator=/

2. If your consul nodes are up and joined together, you can verify they see each other
   checking _serf_ peers list

        $ consul members -detailed

3. Check _raft_ peers list to contain right set of nodes across every consul server
   that should form the quorum. By right I mean:

    3.1. no dead, left, failed servers are present

    3.2. all server nodes are in there and seen by _serf_ (check topic 2) as well.

    In order to do it, go to `raft/peers.json`, open, read, add and/or remove nodes, save.
    Repeat on every node. If you ran into this situations of unsynced _raft_ peers
    across the cluster, you have to stop the nodes before manually fixing _raft_ peers list.

    After you are sure `raft/peers.json` files are good, start everything up. Consul
    will succeed in building the quorum and electing the new leader.

    Example of what your _raft_ peers file should look like for 3 consul servers:

        ["172.17.0.30:8300","172.17.0.31:8300","172.17.0.32:8300"]

    If you have only `single entry` there, `[]` or `null` it rather means it is wrong.

About the `Outage` doc
----------------------

It missing some points in the part of manually fixing `raft/peers.json`.

1. It is not enough to just get rid of failed nodes. You have to make sure you have all
   other healthy nodes in there. Without it you will not build up a quorum. Without a
   working quorum, its impossible to:

2. do what they claim next:

    > If any servers managed to perform a graceful leave, you may need to have then
    > rejoin the cluster using the join command`

    before doing that, you should fix your quorum (or add/restore them manually
    straight to the json file).

    In the case you have to fix your peers json files manually, it makes sense to
    add everything you need at once.

Case we run into
----------------

1. We have restarted the whole cluster in parallel

2. `skip_leave_on_interrupt` was set to _false_, so every node issued
   `leave` event to the cluster, so they end up with cleared _raft_ peers list each.

3. After restart they of course failed to build a quorum without any neighbours
   in the _raft_ list.

To fix it, we restored original `raft/peers.json` file on each server node and
restarted the cluster.

Tips
----

* When cluster leader is present you can join / leave nodes live - it will auto update
  peers json,

* You can add new servers straight to _raft_ peers list (you can add new servers with new ips
  right into json),

* If you have unsynced _raft_ peers set and _serf_ and there are some nodes in _raft_
  missing in _seft_ the only option to remove them will be to manually cut them from
  the `raft/peers.json`. `force-leave` works only for nodes present in _serf_ peers list
  first (at least for the state of version 0.5.2).
