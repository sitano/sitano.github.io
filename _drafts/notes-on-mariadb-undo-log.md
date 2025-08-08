---
layout: post
title: Scattered notes on MariaDB undo log.
categories: [mariadb, innodb, undolog, recovery]
tags: [mariadb, innodb, undolog, recovery]
mathjax: false
desc: Scattered notes on MariaDB undo log and its internals.
---

# Undo log

Undo log in MariaDB represented by a set of undo tablespaces (data pages) and
the undo (rollback) segments (rseg0) that start at page 6
(FSP_FIRST_RSEG_PAGE_NO / fsp0types.h) (at offset 6 * 16KB = 98304 or 0x18000)
of system tablespace (`ibdata1`).

# Related functions

```
/** Open the configured number of dedicated undo tablespaces.
@param[in]	create_new_undo	whether the undo tablespaces has to be created
@param[in,out]	mtr		mini-transaction
@return DB_SUCCESS or error code */
dberr_t srv0start:srv_undo_tablespaces_init(bool create_new_undo, mtr_t *mtr) ->

/** Create an undo tablespace file
@param[in] name	 file name
@return DB_SUCCESS or error code */
static dberr_t srv0start:srv_undo_tablespace_create(const char* name) ->

/** Open the configured number of dedicated undo tablespaces.
@param[in]	create_new_undo	whether the undo tablespaces has to be created
@param[in,out]	mtr		mini-transaction
@return DB_SUCCESS or error code */
dberr_t srv0start:srv_undo_tablespaces_init(bool create_new_undo, mtr_t *mtr) ->

dberr_t fsp_header_init(fil_space_t *space, uint32_t size, mtr_t *mtr) ->

fsp_init_file_page() ->

/** Initialize a file page whose prior contents should be ignored.
@param[in,out]	block	buffer pool block */
void fsp0fsp:fsp_apply_init_file_page(buf_block_t *block) ->

/** Initialize a tablespace header.
@param[in,out]	space	tablespace
@param[in]	size	current size in blocks
@param[in,out]	mtr	mini-transaction
@return error code */
dberr_t fsp0fsp:fsp_header_init(fil_space_t *space, uint32_t size, mtr_t *mtr)
```

Links
===

- [MariaDB Redo Log Parser](https://github.com/sitano/mdbutil)
