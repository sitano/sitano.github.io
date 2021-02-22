---
layout: post
title: On the limitations of the Dynamo (read Cassandra) design
categories: [databases, architecture]
tags: [databases, architecture]
mathjax: false
desc: Describe the consequences of the Dynamo-style database design
---

The [Dynamo-style][1] database design is one of the most famous approaches
out there that favors High Availability (HA). There are at least a few
Open Source (OS) databases that are based on that design decisions. The most
know is [Cassandra][3].

The advantages of this approach are well known and proved them selves.
Let’s take a look what Dynamo-style design approach has on a negative
side of the tradeoffs plate.

## Negative design consequences

Comes mostly from the Consistent Hashing and Eventual Consistency.

### Storage

1. Wide-columness => Cells-based design but with rows. The data model
   abstraction layer that leaks into the storage file format along with
   the back compatibility. Write optimized for KV writes.
2. Cells => Rows hard to read because need to find all Cells
3. Last-write-wins (LWW) Eventual Consistency (EC) convergence strategy
   with uncoordinated timestamps => timestamps from clients and
   coordinators are not-monotonic => any next write may be outdated =>
   no guarantee that the latest write is the recent => need to read all
   versions on all LSM-tree levels.
4. (3) => need to keep delete Tombstones longer than the Compaction
   happens on ALL replicas.
5. (2) + (3) => no rows isolation => writes can torn rows.
6. LSM-tree with STCS does not keep keys ranges disjoint => checks all SSTables.
7. Updates are append inserts. No in-place writes.

### Maintenance

1. Any change to cluster membership view (VC - view change) => moves
   all pieces on the ring => every node participates in the VC.
2. Due to the lack of VC controller => can’t limit or isolate a
   load impact of the VC on the cluster. Can’t build hybrid topologies.
3. (2) => VC may result in the brain split => nodes add/remove only by 1
   => slow
4. (3) => cluster can’t came out of the Brain Split situation automatically.
5. (3) => overhead for data move when doing more than adding/removing
   more than 1 node sequentially
6. Streaming can hang without a signal
7. (3) with (Storage.3) and due to the EC overall => impossible to know
   when the data is in sync, and when it’s in sync at least partially =>
   can’t serve requests until full sync completed => slow + risk
8. (6) and (7) => repair before changing VC => overhead + slow => risk
9. STCS requires x2 space in the worst case.

### Features

1. Keys are hashed => uniformly spread => no range scans and clustering
2. Impossible to build virtual consensus groups with long stable leaders
   due to the lack of data groups - a row is a single replication unit =>
   no coordinators for transactions => no fast transactions, have only LWT

## References

- [Dynamo: Amazon's highly available key-value store, October 2007, ACM SIGOPS Operating Systems Review 41(6):205-220][1].
- [Dynamo (storage system)][2]
- [Apache Cassandra][3]

[1]: https://www.researchgate.net/publication/220910159_Dynamo_Amazon's_highly_available_key-value_store "Dynamo: Amazon's highly available key-value store, October 2007, ACM SIGOPS Operating Systems Review 41(6):205-220"
[2]: https://en.wikipedia.org/wiki/Dynamo_(storage_system) “Dynamo (storage system)”
[3]: https://en.wikipedia.org/wiki/Apache_Cassandra “Apache Cassandra”
