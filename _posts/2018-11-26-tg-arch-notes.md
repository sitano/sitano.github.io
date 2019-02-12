---
layout: post
title: Notes on Telegram (TG) instant messaging (IM) system data protocol
---

The protocol structure was reverse engineered from the prototypes of the
TG protocol and it's open source clients.

Telegram is an instance messaging (IM) platform. It consists of a users
who talk to each other in a chat rooms which can be public or private.
The problems in the design of the chat systems are fast and light
clients (devices) synchronization over the same view of the chat histories
and their states, distribution (routing) of the messages flows and reducing
overall overhead of storage keeping operational latency low.

Telegram uses encapsulated append-only logs (AOL) of events to model
robust replication machine. Multiple devices can agree on a single view
of the data (snapshot of the chats state) consuming an event log and
detect their synchronization state with O(1).

```
/------------------------------------------------------------------
|         |         |
| event 1 | event 2 | event 3 | ...         | event N |
|         |         |
\------------------------------------------------------------------
              ^                                  ^
              |                                  |
              read ptr                           last event ptr

Telegram protocol.
Replication machine based on ordered log of events.
```

This event log (EVL) is persistent (at least to some extent) and unique
for each user (single log per multiple clients/devices). It's implemented
as a ring buffer with a 32 bit events space. Clients consume tail of
the EVL from the known point to the end of the tail to get consistent
data view. All events has an associated monotonically increasing ID.
The volume of unsynced state may be expressed as a difference between
known state and the latest event in the log:
`last_event_id - device_read_event_id`.

This design allows to:

- organize replication in a simple lightweight and reliable way.
- synchronize data with a single RPC call (load the EVL tail) really quick;
- survive disconnections and bad network with little overhead;
- count unread events/messages for O(1);

Then, the EVL has layered structure it self:

```
/-----------------------------------------------------\/--------\
|  /----------------------\ /----------------------\  || Online |
|  | Public messaging log | | Secret messaging log |  || events |
|  \----------------------/ \----------------------/  || log    |
|            Application-level events log             ||        |
\-----------------------------------------------------/\--------/
|                                                               |
| In-house AES based encryption                                 |
| ------------------------------------------------------------- |
| Transport-level messages                                      |
\---------------------------------------------------------------/
```

Transport level (TL) has an output queue on the server side
per client (device). All application level events (messages) are
encapsulated into the transport level events (messages). On a
transport level clients explicitly acknowledge (ACK) that they
have successfully received every message in order. Application level
ACK allows to use any of the available protocols for the networking
(i.e. UDP).

TL network messages are ordered with monotonically increasing IDs.
TL queue is not persistent as serves the socket buffer purposes.

TODO: what to they use now?
TODO: how the IDs of the TL are encoded?
TODO: how the RPC calls are implemented on TL level?

TODO
===

- describe how EVL levels structured and what they do
- how different types of ID structured
- how messages/chats structured inside of the EVL
- described types of events
- on limitations and rotation of the EVL
- how exactly IDs are encoded in the transport level
