---
layout: post
title: Scattered notes on MariaDB undo log.
categories: [mariadb, innodb, undolog, recovery]
tags: [mariadb, innodb, undolog, recovery]
mathjax: false
desc: Scattered notes on MariaDB undo log and its internals.
---

# Undo log

Undo log in MariaDB is represented by the set of rollback segments which basically
are the dedicated tablespaces (data files) (`undo0XXX`) including historically the
one number Zero (0) that resides in the system tablespace starting at page 6
(FSP_FIRST_RSEG_PAGE_NO / fsp0types.h) (at offset 6 * 16KB = 98304 or 0x18000)
of system tablespace (`ibdata1`).

# Undo tablespaces selection

Undo tablespaces are selected in the round-robin fasion and are assigned to all
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


# Related functions

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

TODO
===

- What exactly stored in page 6 of system tablespace? Probably the first page
of the first rollback segment (undo0XXX) which is created during the database
creation.
- Trace undo init during boot.
- How system detects redo log is empty if (trx_sys.is_undo_empty())?

Links
===

- [MariaDB Redo Log Parser](https://github.com/sitano/mdbutil)
