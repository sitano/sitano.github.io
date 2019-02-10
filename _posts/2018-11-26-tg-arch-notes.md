---
layout: post
title: Notes on Telegram (TG) instant messaging (IM) system data protocol
---

The protocol structure was reverse engineered from the prototypes of the
TG protocol and it's open source clients.

Telegram uses encapsulated append-only logs (AOL) of events to build
robust replication machine. Multiple devices can agree on a single view
of the data (snapshot of the chats state) consuming this event log and
detect their synchronization state with O(1).

```
/------------------------------------------------------------------
|         |         |
| event 1 | event 2 | event 3 | ...
|         |         |
\------------------------------------------------------------------
              ^                                  ^
              |                                  |
              read ptr                           last event ptr
```

This events log (EVL) is persistent and unique for each client. Thus, the
only data clients need to consume to get the latest data view is to
load and consume this events log to the end. All events has an associated
monotonically increasing ID. The amount of unsynced state may be expressed
as a difference between known state and the last event in the log:
`last_event_id - device_read_event_id`. This design allows to:

- synchronize data with a single RPC call (load the EVL tail) really quick;
- count unread events/messages for O(1);
- organize replicate in a simple and reliable way.

Then, the EVL has layered structure it self:

```
/-----------------------------------------------------\/--------\
|  /----------------------\ /----------------------\  || Online |
|  | Public messaging log | | Secret messaging log |  || events |
|  \----------------------/ \----------------------/  || log    |
|            Application-level events log             ||        |
\-----------------------------------------------------/\--------/
|                                                               |
|            Transport-level events log                         |
\---------------------------------------------------------------/
```

TODO
===

- describe how EVL levels structured and what they do
- how different types of ID structured
- how messages/chats structured inside of the EVL
- described types of events
- on limitations and rotation of the EVL
- how exactly IDs are encoded in the transport level
