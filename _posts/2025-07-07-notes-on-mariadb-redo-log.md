---
layout: post
title: Scattered notes on MariaDB redo log internals and file checkpoints.
categories: [mariadb, innodb, redolog, recovery]
tags: [mariadb, innodb, redolog, recovery]
mathjax: false
desc: Scattered notes on MariaDB redo log or redo log internals.
---

# Redo log structure

The database log (aka redo log) is used to ensure data integrity in the case of
a crash or unexpected shutdown. It records changes made to the database before
they are actually written (?) so that they can be replayed during recovery.
Redo log is stored in `ib_logfileX` files. These files consist of the header
(512 bytes and 2 LSN checkpoints overall up to `START_OFFSET = FIRST_LSN =
12288` bytes) and the ring buffer of the log items. The header starts with 512
bytes dedicated to the purposes of upgrading and preventing downgrading
containing:

```
+-------------------------------------------------------------------------------+
|                                 Redo Log Header (512 bytes)                   |
+-------------------------------------------------------------------------------+
| Offset   | Length | Field Name                          | Description         |
|----------|--------|-------------------------------------|---------------------|
| 0x0000   |   4    | Format Version Identifier           | Log format version  |
| 0x0008   |   4    | Start LSN                           | First LSN           |
| 0x0010   | max 32 | Creator String                      | eg "MariaDB 11.6.2" |
| 0x01FC   |   4    | CRC-32C Checksum                    | Header checksum     |
+-------------------------------------------------------------------------------+
| 0x0200   | 3584   | Stub Area                           | Reserved space      |
+-------------------------------------------------------------------------------+
|                                 Redo Log Checkpoint Markers                   |
+-------------------------------------------------------------------------------+
| 0x1000   |   8    | Checkpoint LSN #1                   | 1st checkpoint LSN  |
|----------|--------|-------------------------------------|---------------------|
| 0x2000   |   8    | Checkpoint LSN #2                   | 2nd checkpoint LSN  |
+-------------------------------------------------------------------------------+
|                                 Mini-Transactions Log                         |
+-------------------------------------------------------------------------------+
| 0x3000   | ...    | Log of Mini-Transactions chains     | Ring-Buffer of MTRs |
+-------------------------------------------------------------------------------+
```

where Checkpoint LSN entries are used to indicate the coordinates of 2 latest
checkpoint entries in the redo log and known end of the log. Normally,
checkpoint record consists of a single MTR with the FILE_CHECKPOINT op type,
data LSN, redo log end position LSN and a checksum:

```
Version 10.8 (0x5068_7973) and later.

+---------------------------------+
|          Checkpoint LSN         |
+---------------------------------+
| 0x0  | 8  | FILE_CHECKPOINT LSN |
+---------------------------------+
| 0x8  | 8  | Redo Log End LSN    |
+---------------------------------+
| 0x10 | 44 | Reserved            |
+---------------------------------+
| 0x3C | 4  | CRC-32C Checksum    |
+---------------------------------+

64 bytes total.
```

More details at
[https://jira.mariadb.org/browse/MDEV-14425](https://jira.mariadb.org/browse/MDEV-14425).

# LSN to Redo log physical position

The redo log is a ring buffer with a header in front.

The formula for calculating the physical position of a log sequence number (LSN)
when it exceeds the header size is:

```
physical_position = START_OFFSET + (lsn - START_OFFSET) % RING_CAPACITY.

where RING_CAPACITY = FILE_SIZE - START_OFFSET.

START_OFFSET = fixed HEADER_SIZE.
```

# Log items or mini-transactions (mtr_t) chains

A mini-transaction (`mtr_t`) is a unit of work in the InnoDB storage. It
represents a single data modification operation, such as an memset X bytes.

```
Mini-Transaction Record (mtr_t)

+-------+
| mtr_t |
+-------+
```

An MTR chain is a sequence of mini-transactions that are grouped together to
form a single logical operation. In MariaDB, it is rather the MTRs themselves
are the stream of records, but for simplicity it makes sense to separate the
concept into 2 different entities: MTR and MTR chain.

```
MTR Chain

+-------+-------+-------+-------+---+----------+
| mtr_t | mtr_t | mtr_t | ..... |gen| checksum |
+-------+-------+-------+-------+---+----------+
```

Redo log items are composed of the mini-transactions (`mtr_t` objects) chains
that contain the information about the changes made to the tablespaces or some
special metadata. The first byte of the record of an MTR would contain a record
type, flags, and a length if it is less than 16. Then it is usually a tablespace
ID and page number, followed by the record payload, a termination byte if it is
the last record in the chain, and a CRC32C checksum.

```
+-------------------------------+
|   Mini-Transaction Structure  |
+-------------------------------+
| First Byte                    |
| - Bit  7: same page as prev f |
| - Bits 6..4: redo log type    |
| - Bits 3..0: payload len      |
+-------------------------------+
| Optional Length Bytes (0-3)   |
| - Only present if len > 15    |
+-------------------------------+
| Optional Tablespace ID/Page # |
| - if same_page=0              |
| - or FILE_ records            |
| - or FREE_PAGE / INIT_PAGE    |
| - or EXTENDED + Subtype       |
+-------------------------------+
| Subtype Code (Optional)       |
| - if EXTENDED and OPTION      |
+-------------------------------+
| Record Payload (Variable)     |
| - Depends on redo log type    |
+-------------------------------+
| ... other MTR in the chain .. |
+-------------------------------+
| Terminator Byte               |
| - Either 0x00 or 0x01         |
+-------------------------------+
| CRC32C checksum               |
+-------------------------------+
```

The examples of a mini-transaction (mtr) record types are:

- FREE_PAGE (0): corresponds to MLOG_INIT_FREE_PAGE
- INIT_PAGE (1): corresponds to MLOG_INIT_FILE_PAGE2
- EXTENDED (2): extended record; followed by subtype code @see mrec_ext_t
- WRITE (3): replaces MLOG_nBYTES, MLOG_WRITE_STRING, MLOG_ZIP_*
- MEMSET (4): extends the 10.4 MLOG_MEMSET record
- MEMMOVE (5): copy data within the page (avoids logging redundant data)
- ...

The termination byte may be 0x00 or 0x01 depending on the LSN wrap around
generation. See `log_sys.get_sequence_bit()` for details:

```
!(((lsn - first_lsn) / capacity()) & 1)
```

Redo log record examples
===

> INIT could be logged as 0x12 0x34 0x56, meaning "type code 1 (INIT), 2
bytes to follow" and "tablespace ID 0x34", "page number 0x56".
The first byte must be between 0x12 and 0x1a, and the total length of
the record must match the lengths of the encoded tablespace ID and
page number.

> WRITE could be logged as 0x36 0x40 0x57 0x60 0x12 0x34 0x56, meaning
"type code 3 (WRITE), 6 bytes to follow" and "tablespace ID 0x40",
"page number 0x57", "byte offset 0x60", data 0x34,0x56.

> A subsequent WRITE to the same page could be logged 0xb5 0x7f 0x23
0x34 0x56 0x78, meaning "same page, type code 3 (WRITE), 5 bytes to
follow", "byte offset 0x7f"+0x60+2, bytes 0x23,0x34,0x56,0x78.

> The end of the mini-transaction would be indicated by the end byte
0x00 or 0x01; @see log_sys.get_sequence_bit().
If log_sys.is_encrypted(), that is followed by 8 bytes of nonce
(part of initialization vector). That will be followed by 4 bytes
of CRC-32C of the entire mini-transaction, excluding the end byte.

Redo log file checkpoint record
===

FILE_CHECKPOINT is a special type of mini-transaction record that marks the
end of a checkpoint in the redo log. It is used to indicate that all changes
up to that point have been successfully flushed to disk and that the database
is in a consistent state. The FILE_CHECKPOINT record is written at the end of
the checkpoint process, and it contains the log sequence number (LSN) of the
checkpoint, the end LSN of the redo log, and a checksum to ensure data integrity.

It has the following structure:

```
0xFA, // FILE_CHECKPOINT + len 10 bytes (+1 1st byte + 1 termination marker)
0x00, 0x00, // tablespace id + page no (0x0000 for FILE_CHECKPOINT)
0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, // 8 bytes checkpoint LSN
0x0X, // termination marker
0xXX, 0xXX, 0xXX, 0xXX, // checksum
```

Redo log file operations
===

Among mtr_t record types there are also FILE_s related operations, such as
`FILE_CREATE`, `FILE_DELETE`, `FILE_RENAME`, `FILE_MODIFY`, and
`FILE_CHECKPOINT`. The most important for the checkpoint is `FILE_CHECKPOINT`,
which is used to mark the end of a checkpoint in the redo log. It is written at
the end of the checkpoint process to indicate that all changes up to that point
have been successfully flushed to disk and that the database is in a consistent
state. It's MTR size is defined as `SIZE_OF_FILE_CHECKPOINT` in `mtr0types.h` and
is 16 bytes (3 bytes for type and page ID, 8 bytes for LSN, 1 byte for end
byte, and 4 bytes).

Example of MariaDB shutdown with `--innodb_fast_shutdown=0`
===

```
Header block: 12288
Size: 10485760, Capacity: 10473472
RedoHeader {
    version: 1349024115,
    first_lsn: 12288,
    creator: "MariaDB 11.6.2",
    crc: 224651864,
}
RedoCheckpointCoordinate {
    checkpoints: [
        RedoHeaderCheckpoint {
            checkpoint_lsn: 60024,
            end_lsn: 60024,
            checksum: 1691141185,
        },
        RedoHeaderCheckpoint {
            checkpoint_lsn: 60123,
            end_lsn: 60123,
            checksum: 3550697051,
        },
    ],
    checkpoint_lsn: Some(
        60123,
    ),
    end_lsn: 60123,
    encrypted: false,
    version: 1349024115,
    start_after_restore: false,
}
MTR Chain count=1, len=16, lsn=60123
  1: Mtr { space_id: 0, page_no: 0, op: FileCheckpoint }
Checkpoint LSN/1: RedoHeaderCheckpoint { checkpoint_lsn: 60024, end_lsn: 60024, checksum: 1691141185 }
Checkpoint LSN/2: RedoHeaderCheckpoint { checkpoint_lsn: 60123, end_lsn: 60123, checksum: 3550697051 }
File checkpoint chain: Some(MtrChain { lsn: 60123, len: 16, checksum: 3572919866, mtr: [Mtr { space_id: 0, page_no: 0, op: FileCheckpoint, file_checkpoint_lsn: Some(60123), marker: 1 }] })
File checkpoint LSN: 60123
```

You can see that `checkpoint_lsn == end_lsn` and the FILE_CHECKPOINT record at
position 60123 is the last record in the redo log - there is a termination
marker after it and no valid MTRs.

Example of MariaDB shutdown with `pkill -9`
===

```
$ scripts/mariadb-install-db --datadir ./data --innodb-log-file-size=10M
$ bin/mariadbd --datadir ./data --innodb_fast_shutdown=0 --innodb-log-file-size=10M

$ mycli -S /tmp/mysql.sock
> CREATE TABLE a (id int not null auto_increment primary key, t TEXT);
> SET max_recursive_iterations = 1000000;
> INSERT INTO a (t)
  WITH RECURSIVE fill(n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM fill WHERE n < 60500
  )
  SELECT RPAD(CONCAT(FLOOR(RAND()*1000000)), 64, 'x') FROM fill;
$ pkill -9 mariadbd
$ cargo run -- --log-group-path data

Header block: 12288
Size: 10485760, Capacity: 10473472
RedoHeader {
    version: 1349024115,
    first_lsn: 12288,
    creator: "MariaDB 11.6.2",
    crc: 224651864,
}
RedoCheckpointCoordinate {
    checkpoints: [
        RedoHeaderCheckpoint {
            checkpoint_lsn: 6880644,
            end_lsn: 9694174,
            checksum: 1144991502,
        },
        RedoHeaderCheckpoint {
            checkpoint_lsn: 9691474,
            end_lsn: 10553265,
            checksum: 2431378773,
        },
    ],
    checkpoint_lsn: Some(
        9691474,
    ),
    checkpoint_no: Some(
        0,
    ),
    end_lsn: 10553265,
    encrypted: false,
    version: 1349024115,
    start_after_restore: false,
}
MTR Chain count=4, len=27, lsn=9691474
  1: Mtr { space_id: 8, page_no: 76, op: Memset }
  2: Mtr { space_id: 8, page_no: 76, op: Write }
  3: Mtr { space_id: 8, page_no: 76, op: Memset }
  4: Mtr { space_id: 8, page_no: 76, op: Option }
...
MTR Chain count=13, len=89, lsn=11344877
  1: Mtr { space_id: 3, page_no: 4, op: Write }
  2: Mtr { space_id: 3, page_no: 4, op: Write }
  ...
  10: Mtr { space_id: 3, page_no: 2, op: Memset }
  11: Mtr { space_id: 3, page_no: 4, op: Option }
  12: Mtr { space_id: 3, page_no: 2, op: Option }
  13: Mtr { space_id: 3, page_no: 0, op: Option }
Checkpoint LSN/1: RedoHeaderCheckpoint { checkpoint_lsn: 6880644, end_lsn: 9694174, checksum: 1144991502 }
Checkpoint LSN/2: RedoHeaderCheckpoint { checkpoint_lsn: 9691474, end_lsn: 10553265, checksum: 2431378773 }
File checkpoint chain: Some(MtrChain { lsn: 10553265, len: 31, checksum: 2542014928, mtr: [Mtr { space_id: 8, page_no: 0, op: FileModify, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 0, page_no: 0, op: FileCheckpoint, file_checkpoint_lsn: Some(9691474), marker: 0 }, Mtr { space_id: 5411, page_no: 6, op: Option, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 252, page_no: 0, op: FreePage, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 252, page_no: 0, op: Extended, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 8, page_no: 252, op: Memset, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 8, page_no: 252, op: Write, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 8, page_no: 252, op: Memset, file_checkpoint_lsn: None, marker: 0 }, Mtr { space_id: 8, page_no: 252, op: Option, file_checkpoint_lsn: None, marker: 0 }] })
File checkpoint LSN: 9691474
WARNING: checkpoint LSN is not at the end of the log.
```

Here you can observe that there is an MTR chain at `9691474` and it is not a
FILE_CHECKPOINT.

Source refs
===

From the source code PoV redo log subsystem resides in:

- storage/innobase/include/log0log.h - log system interface (log_t) (writer)
- storage/innobase/include/log0recv.h - recovery system interface (recv_sys_t) (reader)
- storage/innobase/include/mtr0types.h - mini-transaction interface (mtr_log_t, mrec_type_t, ...)
- storage/innobase/include/mtr0log.h - mini-transaction log record encoding and decoding
- storage/innobase/include/mtr0mtr.h - mini-transaction types (mtr_t)

and corresponding implementation CC files, where

    recv_sys - is recovery system for InnoDB redo logs.
    log_sys - is redo log system for InnoDB.
    mtr_t - is mini-transaction (mtr) for InnoDB redo logs.

    log_t:
      /** latest completed checkpoint (protected by latch.wr_lock()) */
      Atomic_relaxed<lsn_t> last_checkpoint_lsn;
      /** next checkpoint LSN (protected by latch.wr_lock()) */
      lsn_t next_checkpoint_lsn;

    recv_sys_t:

      /** number of bytes in log_sys.buf */
      size_t len;
      /** start offset of non-parsed log records in log_sys.buf */
      size_t offset;
      /** log sequence number of the first non-parsed record */
      lsn_t lsn;
      /** log sequence number of the last parsed mini-transaction */
      lsn_t scanned_lsn;
      /** log sequence number at the end of the FILE_CHECKPOINT record, or 0 */
      lsn_t file_checkpoint;

Data recovery process start during boot
===

The boot process consists of several steps:

1. Listing existing redo log files.
2. Reading the initial checkpoint LSN coordinates from the redo log files.
3. Initiating crash recovery process during which the redo log is scanned
   and the changes are applied to the database.
4. If the redo log is empty after the last checkpoint, it indicates that the
   database was shut down cleanly, and no recovery is needed.

AFAIS, MariaDB checks the end of the log first for the records if checkpoint
lsn != end_lsn, and only then goes to the scan of the log from the last
checkpoint position.

`storage/innobase/srv/srv0start.cc/srv_start()` is the initialization point for
the InnoDB storage engine. First of all it calls `recv_recovery_read_checkpoint()`
that in turn calls `storage/innobase/log/log0recv.cc/find_checkpoint()` to find
the list of existing redo log files and read initial checkpoint LSN
coordinates from predetermined locations:

```cpp
#0  recv_sys_t::find_checkpoint (this)
    at storage/innobase/log/log0recv.cc:1602
#1  recv_recovery_read_checkpoint ()
    at storage/innobase/log/log0recv.cc:4510
#2  srv_start (create_new_db=false)
    at storage/innobase/srv/srv0start.cc:1418
#3  innodb_init (p)
    at storage/innobase/handler/ha_innodb.cc:4222
#4  ha_initialize_handlerton (plugin)
    at sql/handler.cc:697
#5  plugin_do_initialize (plugin, state)
    at sql/sql_plugin.cc:1455
#6  plugin_initialize (tmp_root, plugin, argc <remaining_argc>, argv, options_only)
    at sql/sql_plugin.cc:1508
#7  plugin_init (argc <remaining_argc>, argv, flags)
    at sql/sql_plugin.cc:1753
#8  init_server_components ()
    at sql/mysqld.cc:5324
#9  mysqld_main (argc, argv)
    at sql/mysqld.cc:6015
#10 main (argc, argv)
    at sql/main.cc:34
```

That finally does:

    const lsn_t checkpoint_lsn{mach_read_from_8(buf)};
    ...
    if (checkpoint_lsn >= log_sys.next_checkpoint_lsn)
    {
      log_sys.next_checkpoint_lsn= checkpoint_lsn;
      log_sys.next_checkpoint_no= field == log_t::CHECKPOINT_1;
      lsn= end_lsn;
    }

The only case when it is allowed to skip this step is when force_recovery is >=
6 (SRV_FORCE_NO_LOG_REDO).

How MariaDB understands no crash recovery is needed during startup?
===

Then `srv0start.c/srv_start()` calls
`log0recv.c/recv_recovery_read_checkpoint_start()` which in turn calls
`innobase/log/log0recv.c/recv_scan_log(false)` to understand the state of the
redo log. `log0recv.c/recv_scan_log(last_phase)` just scans the redo log store
records to the parsing buffer, but first it tries to determine
`recv_sys_t::file_checkpoint` that is the log sequence number (LSN) of the last
checkpoint (at the end of the last FILE_CHECKPOINT record).

If the checkpoint is found and the log is empty after the checkpoint, it
indicates that the database was shut down cleanly. In this case, no recovery is
needed. This is determined by checking if found FILE_CHECKPOINT entry is the
last entry in the log and if there are no records after it:

```cpp
  if (c == log_sys.next_checkpoint_lsn)
  {
    /* There can be multiple FILE_CHECKPOINT for the same LSN. */
    if (file_checkpoint)
      continue;
    file_checkpoint= lsn;
    return GOT_EOF;
  }
```

`recv_scan_log()` may set `recv_needed_recovery == true` is something goes
wrong.

Additionally, the invariants are checked at `recv_sys.validate_checkpoint()`.

How FILE_CHECKPOINT record looks like in the log?
===

```
Version 10.8 (0x5068_7973) and later.

+---------------------------------+
|          Checkpoint LSN         |
+---------------------------------+
| 0x0  | 8  | FILE_CHECKPOINT LSN |
+---------------------------------+
| 0x8  | 8  | Redo Log End LSN    |
+---------------------------------+
| 0x10 | 44 | Reserved            |
+---------------------------------+
| 0x3C | 4  | CRC-32C Checksum    |
+---------------------------------+

64 bytes total.
```

FILE_CHECKPOINT correctness rules for correct shutdown
===

1. The FILE_CHECKPOINT record must be the last record in the redo log.
   Is is checked by verifying that the checkpoint LSN entries point to the
   end of the redo log (end LSN == FILE_CHECKPOINT LSN).
2. The FILE_CHECKPOINT LSN must be not less than any tablespace page
   modification LSN.

Where FILE_CHECKPOINT record is written?
===

TODO

Undo log scan
===

TODO

Wrap around and alignment
===

TODO

Links
===

- [MariaDB Redo Log Parser](https://github.com/sitano/mdbutil)
