---
layout: post
title: How vm.zone_reclaim_mode = 0 looks like?
---

We hit a problem on our production servers. It looks like this:

![]({{ Site.url }}/public/memory-zonerm0.png)

Server has 3 _memcached_ instances installed for 12 gigs and
2 _redis_ instances installed for 8 gigs + async saves through out fork syscall +
some other services installed. There is 48 gigs of memory in total. 
It’s NUMA architecture, 2 cpus => 2 mem banks, 10/21 memory bank access. 

Server is configured with:

    vm.swappiness = 0
    vm.zone_reclaim_mode = 0

Picture above tells the story. When run processes hit 24 gb memory cap
OS memory scheduler swaps out those memory even in a case, there is 24 gb
of free memory owned by the buffer cache.

Why is that happening?

Take a look at a description of
[vm.zone\_reclaim\_mode](https://www.kernel.org/doc/Documentation/sysctl/vm.txt)
parameter.

**zone\_reclaim\_mode**:

Zone\_reclaim\_mode allows someone to set more or less aggressive approaches to
reclaim memory when a zone runs out of memory. If it is set to zero then no
zone reclaim occurs. Allocations will be satisfied from other zones / nodes
in the system.

This is value ORed together of

    1   = Zone reclaim on
    2   = Zone reclaim writes dirty pages out
    4   = Zone reclaim swaps pages

zone\_reclaim\_mode is disabled by default.  For file servers or workloads
that benefit from having their data cached, zone\_reclaim\_mode should be
left disabled as the caching effect is likely to be more important than
data locality.

zone\_reclaim may be enabled if it’s known that the workload is partitioned
such that each partition fits within a NUMA node and that accessing remote
memory would cause a measurable performance reduction.  The page allocator
will then reclaim easily reusable pages (those page cache pages that are
currently not used) before allocating off node pages.

Allowing zone reclaim to write out pages stops processes that are
writing large amounts of data from dirtying pages on other nodes. Zone
reclaim will write out dirty pages if a zone fills up and so effectively
throttle the process. This may decrease the performance of a single process
since it cannot use all of system memory to buffer the outgoing writes
anymore but it preserve the memory on other nodes so that the performance
of other processes running on other nodes will not be affected.

Allowing regular swap effectively restricts allocations to the local
node unless explicitly overridden by memory policies or cpuset
configurations.

_So_, it may be beneficial to switch off zone reclaim if the system is
used for a file server and all of memory should be used for caching files
from disk. In that case the caching effect is more important than
data locality.

### To read

[PostgreSQL, NUMA and zone reclaim mode on linux](http://frosty-postgres.blogspot.ru/2012/08/postgresql-numa-and-zone-reclaim-mode.html)

[Optimizing Linux Memory Management for Low-latency / High-throughput Databases](http://engineering.linkedin.com/performance/optimizing-linux-memory-management-low-latency-high-throughput-databases)

[OOM relation to vm.swappiness=0 in new kernel](http://www.mysqlperformanceblog.com/2014/04/28/oom-relation-vm-swappiness0-new-kernel/)
