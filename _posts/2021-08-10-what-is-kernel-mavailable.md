---
layout: post
title: What is /proc/meminfo/MemAvailable?
categories: [memory, kernel]
tags: [memory, kernel]
mathjax: false
desc: Describe what /proc/meminfo/MemAvailable is exactly.
---

Have you ever wondered what is Available Memory in Linux?

The documentation (https://www.kernel.org/doc/Documentation/filesystems/proc.txt)
says MemAvailable is:

    An estimate of how much memory is available for starting new
    applications, without swapping. Calculated from MemFree,
    SReclaimable, the size of the file LRU lists, and the low
    watermarks in each zone.

    The estimate takes into account that the system needs some
    page cache to function well, and that not all reclaimable
    slab will be reclaimable, due to items being in use. The
    impact of those factors will vary from system to system.

But what does it mean in practice? Let’s take a look at how
it is calculated in Linux Kernel in `long si_mem_available(void)`
at `kernel/fork.c`:

    MemAvailable =
        MemFree
        // Total of max lows and all highs of all zones from /proc/zoneinfo
        - SUM_over_all_zones(MAX_over_all_zones(LOW_WATERMARK) + HIGH_WATERMARK) * PageSize
        // Probably Cached memory (/proc/meminfo)
        + Active(file) + Inactive(file) - min((Active(file) + Inactive(file))/2, SUM_over_all_zones(LOW_WATERMARK))
        // SReclaimable (/proc/meminfo)
        + SReclaimable - min((SReclaimable)/2, SUM_over_all_zones(LOW_WATERMARK))
        // vmstat counter:
        // part of the reclaimable slab and other kernel memory consists of
        // items that are in use, and cannot be freed. Cap this estimate at the
        // low watermark. For example memory used by long names of reclaimable
        // dentries in slab cache.
        // See: https://lore.kernel.org/lkml/20180305133743.12746-2-guro@fb.com/t/
        // and: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/deployment_guide/s2-proc-meminfo
        + NR_INDIRECTLY_RECLAIMABLE_BYTES - min(NR_INDIRECTLY_RECLAIMABLE_BYTES/2, SUM_over_all_zones(LOW_WATERMARK))

Thus, MemAvailable is MemFree - Low watermarks + capped cached memory + capped
slab reclaimable part + capped currently unreclaimable part of reclaimable area.

Does not look like something a free, right? At least don't look at it as on
the measure of the memory your app can allocate before hitting the OOM.
