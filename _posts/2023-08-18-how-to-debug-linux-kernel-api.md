---
layout: post
title: How to debug linux kernel API (syscalls issues)?
categories: [perf, kernel]
tags: [perf, kernel]
mathjax: false
desc: Use ftrace to debug inability to mount sysfs in unshared user namespace.
---

Linux API can be hard. Sometimes it happens you don't know why a syscall returns
a specific result. The documentation and google not always help. You can turn
you face to the Kernel source code but it's hard to navigate through out
the myriad of functions without any help. This is when the `ftrace` and `eBPF`
comes into play.

`ftrace` is an outstanding tool but it's hard to remember how to use it.  I need
it rarely and each time I need it its already vanished out of my memory.  This
time I needed to mount `sysfs` inside of the fresh _user namespace_ like
following:

    $ mkdir -p rootfs
    $ docker export $(docker create debian:latest) | tar -C ./rootfs -xvf -
    $ unshare -U -r -p -f -m -R ./rootfs --mount-proc bash

where `-U` is unsharing user namespace along with the `-r` to map root user,
`-p` is to clone pid namespace and transition-fork() into it with `-f`, then
`-m` gives us new mount namespace which will isolate us from the parent mount
environment and finally `-R` is a chroot() call. `--mount-proc` additionally
mounts procfs inside.

We have got _procfs_ fine. When we try to mount _sysfs_ we are getting:

    # # inside our container:
    # mount -t sysfs sys /sys
    mount: /sys: permission denied.

Oops. Something went wrong.

So, first thing you are gonna google is that there was a patch to both
filesystems as they are the special case for mount namespace that required full
visibility in the current mount namespace for the mount:

    https://patchwork.kernel.org/project/linux-fsdevel/patch/87k2wbjcb2.fsf@x220.int.ebiederm.org/

    -   if (!capable(CAP_SYS_ADMIN) && !fs_fully_visible(fs_type))
    -       return ERR_PTR(-EPERM);
    -
        /* Does the mounter have privilege over the pid namespace? */
        if (!ns_capable(ns->user_ns, CAP_SYS_ADMIN))
            return ERR_PTR(-EPERM);
    ...
    +	.fs_flags	= FS_USERNS_VISIBLE | FS_USERNS_MOUNT,

As we see here, there is the requirement to have CAP_SYS_ADMIN over current _PID
namespace_ for _procfs_ and something about full visibility for both. For _sysfs_
there is something about permissions related to the network namespace via
`kobj_ns_current_may_mount(KOBJ_NS_TYPE_NET)`.

The patch overall is too old, and nowadays the `fs_fully_visible` function is
called `mount_too_revealing`
(<https://github.com/torvalds/linux/blob/master/fs/namespace.c#L4886>).

    SYSCALL_DEFINE5(mount):

    long do_mount(const char *dev_name, const char __user *dir_name, const char *type_page, unsigned long flags, void *data_page)
      int path_mount(const char *dev_name, struct path *path, const char *type_page, unsigned long flags, void *data_page)
        static int do_new_mount(struct path *path, const char *fstype, int sb_flags, int mnt_flags, const char *name, void *data):
          do_new_mount_fc(fc, path, mnt_flags):
            mount_too_revealing(sb, &mnt_flags);

`mount_too_revealing`
(<https://github.com/torvalds/linux/blob/master/fs/namespace.c#L4817>) is checking
for additional security guarantees for the file systems when we try to do the mount
inside the current mount namespace if it is owned by the non-root user
namespace:

    static bool mount_too_revealing(const struct super_block *sb, int *new_mnt_flags)
        ...
        struct mnt_namespace *ns = current->nsproxy->mnt_ns;

        if (ns->user_ns == &init_user_ns)
            return false;

It starts with checking `noexec,nodev` for all file systems that are
`SB_I_USERNS_VISIBLE` and then goes further with scanning for currently existing
mounts to determine any specific restrictions that are put over it.  The
special-case mount is not too revealing if there are already fully visible
mounts of the same kind with the flags that are the same or more permissive.
Full visibility also implies not having masked sub-paths.

`sysfs` is actually a userns visible filesystem, however, this knowledge does
not help much:

    # # inside our container:
    # mount -t sysfs -o nosuid,nodev sys /sys
    mount: /sys: permission denied.

Let's see what we can do with the magical linux debug interface (ftrace).

To see all of the available tracepoints we could use:

    $ sudo perf list | grep mount

But we want to see the execution of the mount specific to `sysfs`. So let's take
a look a traceable functions with:

    $ sudo perf ftrace -F | grep '^sysfs' | sort

Among the available functions you will find the fs entry point in either variants.

    sysfs_mount
    or
    sysfs_init_fs_context

At this point we could just trace the execution of `__x64_sys_mount` to find out
the same entrypoint:

    sudo perf ftrace -a -v -G __x64_sys_mount     
    function_graph tracer is used
    # tracer: function_graph
    #
    # CPU  DURATION                  FUNCTION CALLS
    # |     |   |                     |   |   |   |
    6)               |  __x64_sys_mount() {
    6)               |    path_mount() {
    6)               |      security_sb_mount()
    6)               |      ns_capable()
    6)               |      get_fs_type()
    6)               |      fs_context_for_mount()
    6)               |          sysfs_init_fs_context()

Let's imagine we are on Debian. Let's trace `sysfs_mount`:

    $ sudo perf ftrace -a -v -G sysfs_mount -D 3

    1)               |  sysfs_mount() {
    1)   0.380 us    |    _raw_spin_lock();
    1)               |    net_current_may_mount() {
    1)   0.640 us    |      ns_capable();
    1)   1.447 us    |    }
    1) + 24.001 us   |  }

    $ sudo perf probe --add 'sysfs_mount%return $retval'
    $ sudo perf trace --call-graph=dwarf -a -e probe:sysfs_mount__return

     0.000 probe:sysfs_mount__return:(ffffffff98af6880 <- ffffffff98a6a71e) arg1=0xffffffffffffffff
        kretprobe_trampoline ([kernel.kallsyms])
        [0x12225a] (/lib/x86_64-linux-gnu/libc-2.27.so)
    …

The first call where `sysfs_mount()` is failing is the check over network namespace
capability by `net_current_may_mount()`. Ok, let's also clone a net namespace:

    $ unshare -U -r -n -p -f -m -R ./rootfs --mount-proc bash
    # mount -t sysfs sys /sys
    mount: /sys: permission denied.

    $ sudo perf ftrace -a -v -G sysfs_mount -D 3

    0)               |  sysfs_mount() {
    0)   0.305 us    |    _raw_spin_lock();
    0)               |    net_current_may_mount() {
    0)   0.655 us    |      ns_capable();
    0)   1.359 us    |    }
    0)   0.235 us    |    _raw_spin_lock();
    0)   0.320 us    |    net_grab_current_ns();
    0)               |    kernfs_mount_ns() {
    0)   0.800 us    |      kmem_cache_alloc_trace();
    0)               |      sget_userns() {
    0) ! 339.176 us  |      }
    0)   0.471 us    |      mutex_lock();
    0)   6.304 us    |      kernfs_get_inode();
    0)   0.232 us    |      mutex_unlock();
    0)   2.470 us    |      d_make_root();
    0)   0.459 us    |      mutex_lock();
    0)   0.278 us    |      mutex_unlock();
    0) ! 361.424 us  |    }
    0) ! 383.453 us  |  }

WUT??? it's passed? but we still has an error!

    $ sudo perf trace --call-graph=dwarf -a -e probe:sysfs_mount__return
        0.000 probe:sysfs_mount__return:(ffffffff98af6880 <- ffffffff98a6a71e) arg1=0xffff99cae37b8840
            kretprobe_trampoline ([kernel.kallsyms])
            [0x12225a] (/lib/x86_64-linux-gnu/libc-2.27.so)
    …

you see, even the return value is not -1 (arg1=0xffff99cae37b8840).
We can see we are having an execution of the mount deinialization
`sysfs_kill_sb`:

    $ sudo perf trace --call-graph=dwarf -a -e probe:sysfs_kill_sb
        0.000 probe:sysfs_kill_sb:(ffffffff98af6850)
            sysfs_kill_sb ([kernel.kallsyms])
            deactivate_locked_super ([kernel.kallsyms])
            cleanup_mnt ([kernel.kallsyms])
            task_work_run ([kernel.kallsyms])
            exit_to_usermode_loop ([kernel.kallsyms])
            do_syscall_64 ([kernel.kallsyms])
            entry_SYSCALL_64_after_hwframe ([kernel.kallsyms])
            [0x12225a] (/lib/x86_64-linux-gnu/libc-2.27.so)

right after the success of the `sysfs_mount()`

    $ sudo perf trace --call-graph=dwarf -a -e probe:sysfs_mount
        0.000 probe:sysfs_mount:(ffffffff98af6880)
            sysfs_mount ([kernel.kallsyms])
            mount_fs ([kernel.kallsyms])
            vfs_kern_mount.part.36 ([kernel.kallsyms])
            do_mount ([kernel.kallsyms])
            ksys_mount ([kernel.kallsyms])
            __x64_sys_mount ([kernel.kallsyms])
            do_syscall_64 ([kernel.kallsyms])
            entry_SYSCALL_64_after_hwframe ([kernel.kallsyms])
            [0x12225a] (/lib/x86_64-linux-gnu/libc-2.27.so)

let's see into that one:

    $ sudo perf ftrace -a -v -G sysfs_kill_sb -D 3
    1)               |  sysfs_kill_sb() {
    1)   0.283 us    |    kernfs_super_ns();
    1)               |    kernfs_kill_sb() {
    1)   0.545 us    |      mutex_lock();
    1)   0.343 us    |      mutex_unlock();
    1) + 12.255 us   |      kill_anon_super();
    1)   0.306 us    |      kfree();
    1) + 14.777 us   |    }
    1)   0.334 us    |    _raw_spin_lock();
    1)               |    net_drop_ns() {
    1)   0.270 us    |      net_drop_ns.part.14();
    1)   0.852 us    |    }
    1) + 34.952 us   |  }

so... what is happening?

`sysfs_mount()` successfully finishes and then something happens that rolls back
the whole result. If we will trace the `__x64_sys_mount()` again we will see
that there is also aforementioned `mount_too_revealing` along with the
`mnt_already_visible` checking for the correct set of not too permissive mount
flags:

    $ sudo perf ftrace -a -v -G __x64_sys_mount 
    function_graph tracer is used
    # tracer: function_graph
    #
    # CPU  DURATION                  FUNCTION CALLS
    # |     |   |                     |   |   |   |
    3)               |  __x64_sys_mount() {
    3)   0.755 us    |    copy_mount_options();
    3)               |    user_path_at_empty()
    3)               |    path_mount() {
    3)               |      security_sb_mount()
    3)               |      ns_capable()
    3)               |      get_fs_type()
    3)               |      fs_context_for_mount()
    3)               |      put_filesystem()
    3)               |      vfs_parse_fs_string()
    3)               |      parse_monolithic_mount_data()
    3)               |      mount_capable()
    3)               |      vfs_get_tree() 
    3)               |      security_sb_kern_mount()
    3)               |      mount_too_revealing() {
    3)   0.956 us    |        down_read();
    3)   1.063 us    |        _raw_spin_lock();
    3)   0.825 us    |        _raw_spin_unlock();
    3)   0.737 us    |        up_read();
    3) + 14.458 us   |      } <--- what has happend here???
    3)               |      fc_drop_locked() {
    3)               |        dput()
    3)               |        deactivate_locked_super() {
    3)               |          unregister_shrinker()
    3)               |          sysfs_kill_sb()
                                ^^ -- here we already deinit() the mount
                                ...

Remember that `mount_too_revealing()` tests for flags to have the correct
permisiviness. It turns out I have missed that the parent mount had sysfs
mounted in RO mode. So just adding RO mode helps.

Conclusion
---

`sysfs` mount requires having:

- a CAP_SYS_ADMIN in the _user namespace_ that is the owner of the current _network namespace_ as well as (kobj_ns_current_may_mount(KOBJ_NS_TYPE_NET)/net_current_may_mount),
- a CAP_SYS_ADMIN in the _user namespace_ owner of the current mount namespace (mount_capable()),
- noexec,nodev flags (mount_too_revealing()),
- less permissive flags compared to existing mounts (!mnt_already_visible),
- enough visibility among already mounted variants (!mnt_already_visible),
- LSM permission.

Such that this is well enough in my case:

    $ unshare -U -r -n -p -f -m -R ./rootfs --mount-proc bash
    # mount -t sysfs -o ro,nosuid,nodev,noexec,relatime sys /sys

Appendix I
---

How to use eBPF `bpftrace` to trace specific syscalls with the arguments.  Let's
trace `docker run` sequence of mount calls with eBPF:

    $ sudo cat /sys/kernel/debug/tracing/events/syscalls/sys_enter_mount/format

    name: sys_enter_mount
    ID: 833
    format:
        field:unsigned short common_type;	offset:0;	size:2;	signed:0;
        field:unsigned char common_flags;	offset:2;	size:1;	signed:0;
        field:unsigned char common_preempt_count;	offset:3;	size:1;	signed:0;
        field:int common_pid;	offset:4;	size:4;	signed:1;

        field:int __syscall_nr;	offset:8;	size:4;	signed:1;
        field:char * dev_name;	offset:16;	size:8;	signed:0;
        field:char * dir_name;	offset:24;	size:8;	signed:0;
        field:char * type;	offset:32;	size:8;	signed:0;
        field:unsigned long flags;	offset:40;	size:8;	signed:0;
        field:void * data;	offset:48;	size:8;	signed:0;

    print fmt: "dev_name: 0x%08lx, dir_name: 0x%08lx, type: 0x%08lx, flags: 0x%08lx, data: 0x%08lx", ((unsigned long)(REC->dev_name)), ((unsigned long)(REC->dir_name)), ((unsigned long)(REC->type)), ((unsigned long)(REC->flags)), ((unsigned long)(REC->data))

    $ sudo bpftrace -e 'tracepoint:syscalls:sys_enter_mount { printf("type: %6s, src/dev: %s, dest: %s, flags: %d, data: %x\n", str(args->type), str(args->dev_name), str(args->dir_name), args->flags, args->data); }'
    Attaching 1 probe...

    # in another console:
    $ docker run --rm -it debian bash

    # in bpftrace console:
    type: overlay, src/dev: overlay, dest: /var/lib/docker/overlay2/d73117ad815fcf2552676c7110ba2414a19ed4.., flags: 0, data: 102e280
    type: overlay, src/dev: overlay, dest: /var/lib/docker/overlay2/d73117ad815fcf2552676c7110ba2414a19ed4.., flags: 0, data: 402a2c0
    type: overlay, src/dev: overlay, dest: /var/lib/docker/overlay2/d73117ad815fcf2552676c7110ba2414a19ed4.., flags: 0, data: 9bc420
    type:       , src/dev: /proc/self/exe, dest: /var/run/docker/runtime-runc/moby/6cfc4e88ba85db175e8e6caa449e8.., flags: 4096, data: e83dae0f
    type:       , src/dev: , dest: /var/run/docker/runtime-runc/moby/6cfc4e88ba85db175e8e6caa449e8.., flags: 4129, data: e83dae0f
    type:       , src/dev: , dest: /, flags: 540672, data: 0
    type:   bind, src/dev: /var/lib/docker/overlay2/d73117ad815fcf2552676c7110ba2414a19ed4.., dest: /var/lib/docker/overlay2/d73117ad815fcf2552676c7110ba2414a19ed4.., flags: 20480, data: 0
    type:   proc, src/dev: proc, dest: /proc/self/fd/7, flags: 14, data: 0
    type:  tmpfs, src/dev: tmpfs, dest: /proc/self/fd/7, flags: 16777218, data: 2ce80
    type: devpts, src/dev: devpts, dest: /proc/self/fd/7, flags: 10, data: 112570
    type:  sysfs, src/dev: sysfs, dest: /proc/self/fd/7, flags: 15, data: 0
    type:  tmpfs, src/dev: tmpfs, dest: /proc/self/fd/7, flags: 14, data: 29350
    type:   bind, src/dev: /sys/fs/cgroup/systemd/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/systemd/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/net_cls,net_prio/docker/6cfc4e88ba85db175e8e6caa.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/net_cls,net_prio/docker/6cfc4e88ba85db175e8e6caa.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/misc/docker/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/misc/docker/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/cpu,cpuacct/docker/6cfc4e88ba85db175e8e6caa449e8.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/cpu,cpuacct/docker/6cfc4e88ba85db175e8e6caa449e8.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/pids/docker/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/pids/docker/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/devices/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/devices/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/hugetlb/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/hugetlb/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/memory/docker/6cfc4e88ba85db175e8e6caa449e8c359a.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/memory/docker/6cfc4e88ba85db175e8e6caa449e8c359a.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/blkio/docker/6cfc4e88ba85db175e8e6caa449e8c359aa.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/blkio/docker/6cfc4e88ba85db175e8e6caa449e8c359aa.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/cpuset/docker/6cfc4e88ba85db175e8e6caa449e8c359a.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/cpuset/docker/6cfc4e88ba85db175e8e6caa449e8c359a.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/rdma/docker/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/rdma/docker/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/perf_event/docker/6cfc4e88ba85db175e8e6caa449e8c.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/perf_event/docker/6cfc4e88ba85db175e8e6caa449e8c.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/freezer/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20495, data: 0
    type:   bind, src/dev: /sys/fs/cgroup/freezer/docker/6cfc4e88ba85db175e8e6caa449e8c359.., dest: /proc/self/fd/7, flags: 20527, data: 0
    type: mqueue, src/dev: mqueue, dest: /proc/self/fd/7, flags: 14, data: 0
    type:  tmpfs, src/dev: shm, dest: /proc/self/fd/7, flags: 14, data: ca390
    type:   bind, src/dev: /var/lib/docker/containers/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20480, data: 0
    type:       , src/dev: , dest: /proc/self/fd/7, flags: 278528, data: 0
    type:   bind, src/dev: /var/lib/docker/containers/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20480, data: 0
    type:       , src/dev: , dest: /proc/self/fd/7, flags: 278528, data: 0
    type:   bind, src/dev: /var/lib/docker/containers/6cfc4e88ba85db175e8e6caa449e8c359aa3.., dest: /proc/self/fd/7, flags: 20480, data: 0
    type:       , src/dev: , dest: /proc/self/fd/7, flags: 278528, data: 0
    type:   bind, src/dev: /proc/534547/ns/net, dest: /var/run/docker/netns/85fb81ed04a2, flags: 4096, data: 0
    type:       , src/dev: , dest: ., flags: 540672, data: 0
    type:   bind, src/dev: /dev/pts/0, dest: /dev/console, flags: 4096, data: 0
    type:       , src/dev: /proc/bus, dest: /proc/bus, flags: 20480, data: 0
    type:       , src/dev: /proc/bus, dest: /proc/bus, flags: 4143, data: 0
    type:       , src/dev: /proc/fs, dest: /proc/fs, flags: 20480, data: 0
    type:       , src/dev: /proc/fs, dest: /proc/fs, flags: 4143, data: 0
    type:       , src/dev: /proc/irq, dest: /proc/irq, flags: 20480, data: 0
    type:       , src/dev: /proc/irq, dest: /proc/irq, flags: 4143, data: 0
    type:       , src/dev: /proc/sys, dest: /proc/sys, flags: 20480, data: 0
    type:       , src/dev: /proc/sys, dest: /proc/sys, flags: 4143, data: 0
    type:       , src/dev: /proc/sysrq-trigger, dest: /proc/sysrq-trigger, flags: 20480, data: 0
    type:       , src/dev: /proc/sysrq-trigger, dest: /proc/sysrq-trigger, flags: 4143, data: 0
    type:       , src/dev: /dev/null, dest: /proc/asound, flags: 4096, data: 0
    type:  tmpfs, src/dev: tmpfs, dest: /proc/asound, flags: 1, data: 0
    type:       , src/dev: /dev/null, dest: /proc/acpi, flags: 4096, data: 0
    type:  tmpfs, src/dev: tmpfs, dest: /proc/acpi, flags: 1, data: 0
    type:       , src/dev: /dev/null, dest: /proc/kcore, flags: 4096, data: 0
    type:       , src/dev: /dev/null, dest: /proc/keys, flags: 4096, data: 0
    type:       , src/dev: /dev/null, dest: /proc/latency_stats, flags: 4096, data: 0
    type:       , src/dev: /dev/null, dest: /proc/timer_list, flags: 4096, data: 0
    type:       , src/dev: /dev/null, dest: /proc/timer_stats, flags: 4096, data: 0
    type:       , src/dev: /dev/null, dest: /proc/sched_debug, flags: 4096, data: 0
    type:       , src/dev: /dev/null, dest: /proc/scsi, flags: 4096, data: 0
    type:  tmpfs, src/dev: tmpfs, dest: /proc/scsi, flags: 1, data: 0
    type:       , src/dev: /dev/null, dest: /sys/firmware, flags: 4096, data: 0
    type:  tmpfs, src/dev: tmpfs, dest: /sys/firmware, flags: 1, data: 0

Appendix II
---

How to use eBPF `bpftrace` to trace devices rootfs preparation by Docker:

    $ sudo cat /sys/kernel/debug/tracing/events/syscalls/sys_enter_mknodat/format

    name: sys_enter_mknodat
    ID: 799
    format:
        field:unsigned short common_type;	offset:0;	size:2;	signed:0;
        field:unsigned char common_flags;	offset:2;	size:1;	signed:0;
        field:unsigned char common_preempt_count;	offset:3;	size:1;	signed:0;
        field:int common_pid;	offset:4;	size:4;	signed:1;

        field:int __syscall_nr;	offset:8;	size:4;	signed:1;
        field:int dfd;	offset:16;	size:8;	signed:0;
        field:const char * filename;	offset:24;	size:8;	signed:0;
        field:umode_t mode;	offset:32;	size:8;	signed:0;
        field:unsigned int dev;	offset:40;	size:8;	signed:0;

    print fmt: "dfd: 0x%08lx, filename: 0x%08lx, mode: 0x%08lx, dev: 0x%08lx", ((unsigned long)(REC->dfd)), ((unsigned long)(REC->filename)), ((unsigned long)(REC->mode)), ((unsigned long)(REC->dev))

    $ sudo bpftrace -e 'tracepoint:syscalls:sys_enter_mknodat { printf("%d %s\n", args->dfd, str(args->filename+80)); }'

    $ docker run --rm -it debian bash

    -100 81b431d7e3b/fa97403ca7558aef29b65cd7c4a9fc0a7f190b029d4d4185c8e..
    -100 81b431d7e3b/fa97403ca7558aef29b65cd7c4a9fc0a7f190b029d4d4185c8e..
    -100 c0a7f190b029d4d4185c8e9881b431d7e3b/log
    -100 85c8e9881b431d7e3b/exec.fifo
    -100 064f73d33/merged/dev/null
    -100 064f73d33/merged/dev/random
    -100 064f73d33/merged/dev/full
    -100 064f73d33/merged/dev/tty
    -100 064f73d33/merged/dev/zero
    -100 064f73d33/merged/dev/urandom

Appendix III
---

How to debug tcpdump AppArmor `permission denied` issue.

Context:

    /var/log/app/log-generic is a HostPath Kubernetes volume with fine privileges.

Pod:

    $ /usr/sbin/tcpdump -ni eth0 -w /var/log/app/log-generic/trace

Does not work.

    $ /usr/sbin/tcpdump -ni eth0 -w /var/log/app/log-generic/trace.pcap

Works.

Let's start with `strace`:

    $ strace -f -v -T tcpdump -ni eth0 -w trace

And

    $ strace -f -v -T tcpdump -ni eth0 -w trace.pcap

Were identical besides 1 line:

    openat(AT_FDCWD, "./trace.pcap00", O_WRONLY|O_CREAT|O_TRUNC, 0666) = -1 EACCES (Permission denied)

Trace:

    $ sudo perf list | grep openat

        syscalls:sys_enter_openat                      	[Tracepoint event]

    $ sudo perf trace --call-graph=dwarf -a -e syscalls:sys_enter_openat --failure -T

        58315469.329 syscalls:sys_enter_openat:dfd: CWD, filename: 0x8c48290f, flags: CLOEXEC
                                            [0x1a4fd] (/usr/lib/x86_64-linux-gnu/ld-2.28.so)
                                   	…

Too many syscalls.

How could we limit the calls to the process tree, pod or an argument value, a return value?

GDB:

Use GDB to pause the process execution to capture its PID and trace the syscalls
of specific process:

    > catch syscall openat
    > run
    > c…

    Catchpoint 1 (call to syscall openat), 0x00007f092b8ec1ae in __libc_open64 (file=0x56190ddec500 "trace", oflag=577) at ../sysdeps/unix/sysv/linux/open64.c:48
    48	in ../sysdeps/unix/sysv/linux/open64.c

    (gdb) s

    __GI__IO_file_open (fp=fp@entry=0x56190ddeb280, filename=<optimized out>, posix_mode=<optimized out>, prot=prot@entry=438, read_write=4, is32not64=is32not64@entry=1) at fileops.c:190
    190	fileops.c: No such file or directory.

    (gdb) bt

    #0  __GI__IO_file_open (fp=fp@entry=0x56190ddeb280, filename=<optimized out>, posix_mode=<optimized out>, prot=prot@entry=438, read_write=4, is32not64=is32not64@entry=1) at fileops.c:190
    #1  0x00007f092b87dffd in _IO_new_file_fopen (fp=fp@entry=0x56190ddeb280, filename=filename@entry=0x56190ddec500 "trace", mode=<optimized out>, mode@entry=0x7f092b9ef696 "w", 
    is32not64=is32not64@entry=1) at fileops.c:281
    #2  0x00007f092b872159 in __fopen_internal (filename=0x56190ddec500 "trace", mode=0x7f092b9ef696 "w", is32=1) at iofopen.c:75
    #3  0x00007f092b9e323f in pcap_dump_open () from /usr/lib/x86_64-linux-gnu/libpcap.so.0.8
    #4  0x000056190cff7a74 in ?? ()
    #5  0x00007f092b82609b in __libc_start_main (main=0x56190cff6870, argc=5, argv=0x7fff633903d8, init=<optimized out>, fini=<optimized out>, rtld_fini=<optimized out>, 
    stack_end=0x7fff633903c8) at ../csu/libc-start.c:308
    #6  0x000056190cff85ca in ?? ()

FTrace:

How to trace syscalls that have specific return error code? With ftrace?

    $ sudo perf ftrace -p 1479571 -D 6 -v -G __x64_sys_openat

    0)               |  __x64_sys_openat() {
    0)               |    do_sys_open() {
    0)               |      getname() {
    0)               |        getname_flags() {
    0)               |          kmem_cache_alloc() {
    0)   0.374 us    |            _cond_resched();
    0)   0.249 us    |            should_failslab();
    0)   0.230 us    |            memcg_kmem_put_cache();
    0)   2.189 us    |          }
    0)               |          __check_object_size() {
    0)   0.210 us    |            check_stack_object();
    0)   0.324 us    |            __virt_addr_valid();
    0)   0.262 us    |            __check_heap_object();
    0)   2.017 us    |          }
    0)   5.920 us    |        }
    0)   6.360 us    |      }
    0)               |      get_unused_fd_flags() {
    0)               |        __alloc_fd() {
    0)   0.364 us    |          _raw_spin_lock();
    0)   0.336 us    |          expand_files.part.14();
    0) + 19.354 us   |        }
    0) + 20.039 us   |      }
    0)               |      do_filp_open() {
    0)               |        path_openat() {
    0)               |          alloc_empty_file() {
    0) + 25.861 us   |            __alloc_file();
    0) + 26.490 us   |          }
    0)   0.930 us    |          path_init();
    0)               |          link_path_walk.part.44() {
    0)   0.695 us    |            inode_permission();
    0)   1.422 us    |          }
    0)               |          complete_walk() {
    0)   1.069 us    |            unlazy_walk();
    0)   1.671 us    |          }
    0)               |          mnt_want_write() {
    0)   0.711 us    |            __sb_start_write();
    0)   0.339 us    |            __mnt_want_write();
    0)   1.905 us    |          }
    0)               |          down_write() {
    0)   0.327 us    |            _cond_resched();
    0)   0.915 us    |          }
    0)               |          d_lookup() {
    0)   0.934 us    |            __d_lookup();
    0)   1.576 us    |          }
    0)               |          security_path_mknod() {
    0) + 29.085 us   |            apparmor_path_mknod(); ←—---------
    0) + 29.773 us   |          }
    0)               |          dput() {
    0)               |            dput.part.33() {
    0) # 4278.908 us |            }
    0) # 4370.419 us |          }
    0)   0.553 us    |          up_write();
    0)     
              |     
    $ sudo perf trace --call-graph=dwarf -e probe:apparmor_path_mknod -p 1497933

        0.000 probe:apparmor_path_mknod:(ffffffff98b5afc0)
                                        apparmor_path_mknod ([kernel.kallsyms])
                                        security_path_mknod ([kernel.kallsyms])
                                        path_openat ([kernel.kallsyms])
                                        do_filp_open ([kernel.kallsyms])
                                        do_sys_open ([kernel.kallsyms])
                                        do_syscall_64 ([kernel.kallsyms])
                                        entry_SYSCALL_64_after_hwframe ([kernel.kallsyms])
                                        __GI___libc_open (/lib/x86_64-linux-gnu/libc-2.28.so)

    $ sudo perf probe --add 'apparmor_path_mknod%return $retval'

Added new event:

    probe:apparmor_path_mknod__return (on apparmor_path_mknod%return with $retval)

You can now use it in all perf tools, such as:

    $ perf record -e probe:apparmor_path_mknod__return -aR sleep 1

    $ sudo perf trace --call-graph=dwarf -e probe:apparmor_path_mknod__return -p 1498409

     0.000 probe:apparmor_path_mknod__return:(ffffffff98b5afc0 <- ffffffff98b18057) arg1=0xfffffff3
        kretprobe_trampoline ([kernel.kallsyms])
        __GI___libc_open (/lib/x86_64-linux-gnu/libc-2.28.so)

Syslog:

    $ sudo cat /var/log/syslog | grep denied

    Mar  3 15:06:12 ip-10-111-73-201 kernel: [4901776.160611] audit: type=1400 audit(1646319972.848:191): apparmor="DENIED" operation="mknod" profile="/usr/sbin/tcpdump" name="/var/log/app/log-generic/trace" pid=1498409 comm="tcpdump" requested_mask="c" denied_mask="c" fsuid=0 ouid=0
    Mar  3 15:10:08 ip-10-111-73-201 kernel: [4902012.284879] audit: type=1400 audit(1646320208.972:192): apparmor="DENIED" operation="mknod" profile="/usr/sbin/tcpdump" name="/var/log/app/log-generic/dump-8d5d4f32452f-2022-03-03-15:10:08.pcap00" pid=1509534 comm="tcpdump" requested_mask="c" denied_mask="c" fsuid=0 ouid=0

AppArmor:

- <https://gcplinux.com/tcpdump-permission-denied-running-as-root/>
