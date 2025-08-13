---
layout: post
title: Scattered notes on MariaDB undo log.
categories: [mariadb, innodb, undolog, recovery]
tags: [mariadb, innodb, undolog, recovery]
mathjax: false
desc: Scattered notes on MariaDB undo log and its internals.
---

# Undo log

Undo log in MariaDB/InnoDB is divided into a set of rollback segments which
basically are the dedicated tablespaces (data files) (`undo0XXX`) including
historically the one number Zero (0) that resides in the system tablespace
starting at page 6 (FSP_FIRST_RSEG_PAGE_NO / fsp0types.h) (at offset 6 * 16KB =
98304 or 0x18000) of system tablespace (`ibdata1`).

DB_ROLL_PTR column in MariaDB is an internal system column that is used to
store the rollback segment pointer for each row in a clustered index. It is
used along with the TRX_ID internal column to track tuples status. DB_ROLL_PTR
column can address up to 128 rollback segments (TRX_SYS_N_RSEGS).

Persistent tables cannot refer to temporary undo logs or vice versa. Therefore,
MariaDB keeps two distinct sets of rollback segments: one for persistent
tables and another for temporary tables. In this way, all 128 rollback segments
are available for both types of tables, which could improve performance
(see
[124bae082bf17e9af1fc77f78bbebd019635be5c](https://github.com/MariaDB/server/commit/124bae082bf17e9af1fc77f78bbebd019635be5c)).

```
trx->rsegs.m_redo.rseg = rseg;

struct trx_t {
  ...
  /** Rollback segments assigned to a transaction for undo logging. */
  trx_rsegs_t  rsegs;
  ...
};

/** Rollback segments assigned to a transaction for undo logging. */
struct trx_rsegs_t {
  /** undo log ptr holding reference to a rollback segment that resides in
  system/undo tablespace used for undo logging of tables that needs
  to be recovered on crash. */
  trx_undo_ptr_t  m_redo;

  /** undo log for temporary tables; discarded immediately after
  transaction commit/rollback */
  trx_temp_undo_t  m_noredo;
};
```

System tablespace (0) has page number 5 (`FSP_TRX_SYS_PAGE_NO 5U`) that keeps
transaction system header (TSH). TSH consists of the deprecated
`TRX_SYS_TRX_ID_STORE`, `TRX_SYS_FSEG_HEADER` - the file segment header for the
tablespace segment the trx system is created into, and `TRX_SYS_RSEGS`
- the rollback segments slots specification registry in the format of
(`TRX_SYS_RSEG_SPACE`, `TRX_SYS_RSEG_PAGE_NO`) 4 bytes each. See
`trx_rseg_get_n_undo_tablespaces()`. Referenced pages contain the rollback
segment headers (`TRX_UNDO_PAGE_HDR`) and the rollback slots.

```
+-------------------------------------------------+
| System Tablespace (0)                           |
| ...                                             |
+-------------------------------------------------+
| Page 5: Transaction system header (0x14000)     |
|                                                 |
| 0..37: FIL_HEADER (page header)                 |
| ---                                             |
| TRX_SYS = FSEG_PAGE_DATA = 38 bytes             |
| +0: TRX_SYS_TRX_ID_STORE (deprecated)           |
| +8: TRX_SYS_FSEG_HEADER (file segment header)   |
|     - FSEG_HDR_SPACE		0	/*!< space id of the inode */
|     - FSEG_HDR_PAGE_NO	4	/*!< page number of the inode */
|     - FSEG_HDR_OFFSET		8	/*!< byte offset of the inode */
| +18: TRX_SYS_RSEGS (rollback segments spec slots|
|+-----------------------------------------------+|
|| Slot 0                                        ||
|| +0: TRX_SYS_RSEG_SPACE                        ||
|| +4: TRX_SYS_RSEG_PAGE_NO                      ||
|+-----------------------------------------------+|
|| Slot ...                                      ||
|+-----------------------------------------------+|
|| Slot 126                                      ||
|+-----------------------------------------------+|
|                                                 |
| TRX_SYS_WSREP_XID_*                             |
| TRX_SYS_MYSQL_*                                 |
| TRX_SYS_DOUBLEWRITE_*                           |
| FIL_TAILER (page footer)                        |
+-------------------------------------------------+
| Page 6: First rollback segment first page       |
|                                                 |
+-------------------------------------------------+
| ...                                             |
```

From `trx_sys_t::reset_page(mtr_t *mtr)` we can see that page no 6
(`FSP_FIRST_RSEG_PAGE_NO`) of the system tablespace is reserved for the first
page of the first rollback segment in this table (`TRX_SYS` /
`TRX_SYS_FSEG_HEADER`).

The number of active rollback segments is stored in the data dictionary at
page 7 (`FSP_DICT_HDR_PAGE_NO 7U`).

Undo log rollback segment starts with a header (`TRX_UNDO_PAGE_HDR`) and is
divided into the rollback slots (`16KB_page_size / 16 = 1024`) and supports up
to `1024 / 2 = 512` transactions at the same time per single rollback segment.


```
/* The physical size of a list base node in bytes */
#define	FLST_BASE_NODE_SIZE	(4 + 2 * FIL_ADDR_SIZE)

/* The physical size of a list node in bytes */
#define	FLST_NODE_SIZE		(2 * FIL_ADDR_SIZE)

trx0rseg.h

/* Number of undo log slots in a rollback segment file copy */
#define TRX_RSEG_N_SLOTS	(srv_page_size / 16)

/* Maximum number of transactions supported by a single rollback segment */
#define TRX_RSEG_MAX_N_TRXS	(TRX_RSEG_N_SLOTS / 2)

+-------------------------------------------------+
| Rollback Segment (undo0XXX)                     |
| ...                                             |
+-------------------------------------------------+
| Page X: Transaction rollback segment header     |
| (trx0rseg.h:208)                                |
|                                                 |
| 0..37: FIL_HEADER (page header)                 |
| ---                                             |
| TRX_RSEG = FSEG_PAGE_DATA = 38 bytes            |
| +0: TRX_RSEG_FORMAT (0x0 since 10.3.5)          |
| +4: TRX_RSEG_HISTORY_SIZE (4)                   |
|     Number of pages in the TRX_RSEG_HISTORY list|
| +8: TRX_RSEG_HISTORY (8)                        |
|     Committed transaction logs that have not    |
|     been purged yet                             |
| +8+16: TRX_RSEG_FSEG_HEADER                     |
|     Header for the file segment where this page |
|     is placed                                   |
| +8+16+10: TRX_RSEG_UNDO_SLOTS                   |
|     Undo log segment slots                      |
|+-----------------------------------------------+|
|| Slot 0 (TRX_RSEG_SLOT_SIZE = 4 bytes)         ||
|| 0..3: Page number                             ||
|+-----------------------------------------------+|
|| ...                                           ||
|+-----------------------------------------------+|
|| Slot (TRX_RSEG_MAX_N_TRXS / TRX_RSEG_SLOT_SIZE)|
|+-----------------------------------------------+|
| +: TRX_RSEG_MAX_TRX_ID                          |
|     Maximum transaction ID                      |
| +: TRX_RSEG_BINLOG_OFFSET (8 bytes)             |
|     8 bytes offset within the binlog file       |
| +: TRX_RSEG_BINLOG_NAME (512 bytes)             |
|     MySQL log file name, including terminating  |
|     NUL (valid only if TRX_RSEG_FORMAT is 0)    |
| FIL_TAILER (page footer)                        |
+-------------------------------------------------+
```

Transaction rollback segment header slots point to the corresponding undo log
pages that contain the undo log header. For more info see
`trx_undo_lists_init()` and `trx_undo_mem_create_at_db_start()`.

```
+-------------------------------------------------+
| Page X: Undo log page header                    |
| (trx0undo.h:381)                                |
|                                                 |
| 0..37: FIL_HEADER (page header)                 |
| ---                                             |
| TRX_UNDO_PAGE_HDR = FSEG_PAGE_DATA = 38 bytes   |
| +0: TRX_UNDO_PAGE_TYPE - unused, b. 0/1 ins/upd |
| +2: TRX_UNDO_PAGE_START - byte offset where     |
|     the undo log records for the LATEST         |
|     transaction start on this page (remember    |
|     that in an update undo log, the first page  |
|     can contain several undo logs)              |
| +4: TRX_UNDO_PAGE_FREE - on each page of the    |
|     undo log this field contains the byte offset|
|     of the first free byte on the page.         |
| +6: TRX_UNDO_PAGE_NODE - the file list node     |
|     in the chain of undo log pages              |
|     (2 * FIL_ADDR_SIZE = 2 * 6 = 12 bytes)      |
| ...                                             |
| FIL_TAILER (page footer)                        |
+-------------------------------------------------+
```

An update undo segment with just one page can be reused. An update undo log
segment may contain several undo logs on its first page if the undo logs took
so little space that the segment could be cached and reused. All the undo log
headers are then on the first page, and the last one owns the undo log records
on subsequent pages if the segment is bigger than one page. If an undo log is
stored in a segment, then on the first page it is allowed to have zero undo
records, but if the segment extends to several pages, then all the rest of the
pages must contain at least one undo log record.

```
+-------------------------------------------------+
| Page X: Undo log page header                    |
| (trx0undo.h:381)                                |
|                                                 |
| 0..37: FIL_HEADER (page header)                 |
| ---                                             |
| TRX_UNDO_PAGE_HDR = FSEG_PAGE_DATA = 38 bytes   |
| +0: undo log page header                        |
| TRX_UNDO_SEG_HDR                                |
| +0: TRX_UNDO_STATE - TRX_UNDO_ACTIVE, ...       |
| ...                                             |
| FIL_TAILER (page footer)                        |
+-------------------------------------------------+
```

# Undo tablespaces selection

Undo tablespaces are selected in the round-robin fashion and are assigned to all
non read-only (rw) transactions. If additional (non-legacy) undo tablespaces
are configured, the algorithm in `trx_assign_rseg_low()` tries to bypass the
selection of the first (legacy) undo tablespace (0):

```
trx_start_low() | trx_set_rw_mode() ->

/** Assign a persistent rollback segment in a round-robin fashion,
evenly distributed between 0 and innodb_undo_logs-1
@param trx transaction */
static void trx_assign_rseg_low(trx_t *trx)
{
  ...

  /* Choose a rollback segment evenly distributed between 0 and
  innodb_undo_logs-1 in a round-robin fashion, skipping those
  undo tablespaces that are scheduled for truncation. */
  static Atomic_counter<unsigned>  rseg_slot;
  unsigned slot = rseg_slot++ % TRX_SYS_N_RSEGS;
  ...

  do {
    for (;;) {
      rseg = &trx_sys.rseg_array[slot];
      ...
      slot = (slot + 1) % TRX_SYS_N_RSEGS;
      ...

      if (rseg->space != fil_system.sys_space) {
        ...
      } else if (const fil_space_t *space =
           trx_sys.rseg_array[slot].space) {
        if (space != fil_system.sys_space
            && srv_undo_tablespaces > 0) {
          /** If dedicated
          innodb_undo_tablespaces have
          been configured, try to use them
          instead of the system tablespace. */
          continue;
        }
      }

      break;
    }

    ...
  } while (!allocated);

  trx->rsegs.m_redo.rseg = rseg;
}
```

In example, for INSERT a row operation the stack looks like this (11.8.2):

```
frame #0: mariadbd`trx_assign_rseg_low(trx=0x0000000140041980) at trx0trx.cc:800:2
frame #1: mariadbd`trx_start_low(trx=0x0000000140041980, read_write=true) at trx0trx.cc:947:4
frame #2: mariadbd`trx_start_if_not_started_xa_low(trx=0x0000000140041980, read_write=true) at trx0trx.cc:2162:3
frame #3: mariadbd`row_insert_for_mysql(mysql_rec="\xfe\U00000002", prebuilt=0x000000011a842690, ins_mode=ROW_INS_NORMAL) at row0mysql.cc:1265:3
frame #4: mariadbd`ha_innobase::write_row(this=0x000000011a82e0a8, record="\xfe\U00000002") at ha_innodb.cc:7781:10
frame #5: mariadbd`handler::ha_write_row(this=0x000000011a82e0a8, buf="\xfe\U00000002") at handler.cc:8221:3
frame #6: mariadbd`write_record(thd=0x000000011c008288, table=0x000000011a809488, info=0x0000000140beeaa0, sink=0x0000000000000000) at sql_insert.cc:2415:12
frame #7: mariadbd`select_insert::send_data(this=0x0000000140beea50, values=0x0000000140beb4e8) at sql_insert.cc:4426:12
frame #8: mariadbd`select_result_sink::send_data_with_check(this=0x0000000140beea50, items=0x0000000140beb4e8, u=0x000000011c00c7e0, sent=0) at sql_class.h:6248:12
frame #9: mariadbd`end_send(join=0x0000000140beeb10, join_tab=0x0000000140c638b8, end_of_records=false) at sql_select.cc:25604:9
frame #10: mariadbd`evaluate_join_record(join=0x0000000140beeb10, join_tab=0x0000000140c63440, error=0) at sql_select.cc:24505:11
frame #11: mariadbd`sub_select(join=0x0000000140beeb10, join_tab=0x0000000140c63440, end_of_records=false) at sql_select.cc:24272:9
frame #12: mariadbd`do_select(join=0x0000000140beeb10, procedure=0x0000000000000000) at sql_select.cc:23783:14
frame #13: mariadbd`JOIN::exec_inner(this=0x0000000140beeb10) at sql_select.cc:5059:50
frame #14: mariadbd`JOIN::exec(this=0x0000000140beeb10) at sql_select.cc:4842:8
frame #15: mariadbd`mysql_select(thd=0x000000011c008288, tables=0x0000000140bebf20, fields=0x0000000140beb4e8, conds=0x0000000000000000, og_num=0, order=0x0000000000000000, group=0x0000000000000000, having=0x0000000000000000, proc_param=0x0000000000000000, select_options=37385559870208, result=0x0000000140beea50, unit=0x000000011c00c7e0, select_lex=0x0000000140beb230) at sql_select.cc:5375:21
frame #16: mariadbd`handle_select(thd=0x000000011c008288, lex=0x000000011c00c700, result=0x0000000140beea50, setup_tables_done_option=35184372088832) at sql_select.cc:633:10
frame #17: mariadbd`mysql_execute_command(thd=0x000000011c008288, is_called_from_prepared_stmt=false) at sql_parse.cc:4676:16
```

For CREATE TABLE (11.8.2):

```
frame #0: mariadbd`trx_assign_rseg_low(trx=0x0000000140042600) at trx0trx.cc:800:2
frame #1: mariadbd`trx_start_low(trx=0x0000000140042600, read_write=true) at trx0trx.cc:947:4
frame #2: mariadbd`trx_start_internal_low(trx=0x0000000140042600, read_write=true) at trx0trx.cc:2221:3
frame #3: mariadbd`trx_start_for_ddl_low(trx=0x0000000140042600) at trx0trx.cc:2231:3
frame #4: mariadbd`ha_innobase::create(this=0x00000001180abea8, name="./dev/a", form=0x000000016ff84328, create_info=0x000000016ff878d8, file_per_table=true, trx=0x0000000140042600) at ha_innodb.cc:13269:7
frame #5: mariadbd`ha_innobase::create(this=0x00000001180abea8, name="./dev/a", form=0x000000016ff84328, create_info=0x000000016ff878d8) at ha_innodb.cc:13333:10
frame #6: mariadbd`handler::ha_create(this=0x00000001180abea8, name="./dev/a", form=0x000000016ff84328, info_arg=0x000000016ff878d8) at handler.cc:5936:14
frame #7: mariadbd`ha_create_table_from_share(thd=0x000000011c008288, share=0x000000016ff85770, create_info=0x000000016ff878d8, ref_length=0x000000016ff8484c) at handler.cc:6388:26
frame #8: mariadbd`ha_create_table(thd=0x000000011c008288, path="./dev/a", db="dev", table_name="a", create_info=0x000000016ff878d8, frm=0x000000016ff87038, skip_frm_file=false) at handler.cc:6455:15
```

# Normal server boot

For existing database Undo logs are opened during lists initialization
(`trx_rseg_array_init()` called from `trx_lists_init_at_db_start()`) in
`srv_start()`:

```
dberr_t srv_start(bool create_new_db) {
  ...
  // srv0start:1478
  err= srv_undo_tablespaces_init(create_new_db, &mtr);
  ...

  if (create_new_db) {
    ...
    err = fsp_header_init(fil_system.sys_space,
              uint32_t(sum_of_new_sizes), &mtr);
    ...

    /* To maintain backward compatibility we create only
    the first rollback segment before the double write buffer.
    All the remaining rollback segments will be created later,
    after the double write buffer has been created. */
    err = trx_sys_create_sys_pages(&mtr);
    //    -> buf_block_t *r= trx0sys:131:trx_rseg_header_create(fil_system.sys_space, ..);

    ...
  } else {
    ...
    srv_undo_tablespaces_active
            = trx_rseg_get_n_undo_tablespaces();
    ...
    err = trx_lists_init_at_db_start();
    // -> dberr_t err = trx_rseg_array_init();
  }

  // srv0start:1789
  /* Recreate the undo tablespaces */
  if (!high_level_read_only) {
    /** Reinitialize the undo tablespaces when there is no undo log
    left to purge/rollback and validate the number of undo opened
    undo tablespace and user given undo tablespace
    @return DB_SUCCESS if it is valid */
    err = srv_undo_tablespaces_reinitialize();
    //    -> /** Recreate the undo log tablespaces */
    //    -> srv_undo_tablespaces_reinit();
    //       -> trx_sys_t::reset_page(mtr_t *mtr)
    //       -> err= srv_undo_delete_old_tablespaces();
    //       -> err= srv_undo_tablespaces_init(true, &mtr);
  }

  ...

  /* Here the double write buffer has already been created and so
  any new rollback segments will be allocated after the double
  write buffer. The default segment should already exist.
  We create the new segments only if it's a new database or
  the database was shutdown cleanly. */

  // Create the rollback segments.
  if (!trx_sys_create_rsegs())
  // -> trx_rseg_t *trx_rseg_create(uint32_t space_id)

  ...
}
```

If they are missing, you will see the following error:

```
[ERROR] InnoDB: Failed to open the undo tablespace undo0XXX
```

# Related functions

```
/** Open the configured number of dedicated undo tablespaces.
@param[in]  create_new_undo  whether the undo tablespaces has to be created
@param[in,out]  mtr    mini-transaction
@return DB_SUCCESS or error code */
dberr_t srv0start:1478:srv_undo_tablespaces_init(bool create_new_undo, mtr_t *mtr) ->

/** Create an undo tablespace file
@param[in] name   file name
@return DB_SUCCESS or error code */
static dberr_t srv0start:srv_undo_tablespace_create(const char* name) ->

/** Open the configured number of dedicated undo tablespaces.
@param[in]  create_new_undo  whether the undo tablespaces has to be created
@param[in,out]  mtr    mini-transaction
@return DB_SUCCESS or error code */
dberr_t srv0start:srv_undo_tablespaces_init(bool create_new_undo, mtr_t *mtr) ->

dberr_t fsp_header_init(fil_space_t *space, uint32_t size, mtr_t *mtr) ->

fsp_init_file_page() ->

/** Initialize a file page whose prior contents should be ignored.
@param[in,out]  block  buffer pool block */
void fsp0fsp:fsp_apply_init_file_page(buf_block_t *block).

/** Assign a persistent rollback segment in a round-robin fashion,
evenly distributed between 0 and innodb_undo_logs-1
@param trx transaction */
static void trx_assign_rseg_low(trx_t *trx)
```

Links
===

- [MariaDB Redo Log Parser](https://github.com/sitano/mdbutil)
