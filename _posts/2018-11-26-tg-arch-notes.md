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

TL network messages have ordered monotonically increasing IDs.
TL queue is not persistent as serves the socket buffer purposes.

```
Transport-level message ID structure

/63<------------------------64 bits---------------------------0\
|63                          20                               0|
| sign bit = 0 | id = 43 bits |   full type mask = 17 bits 0 + |
|                             |       type flag = 3 lowers bit |
\--------------------------------------------------------------/

Flags:
- OK     = 000
- UNSENT = 001
- LOCAL  = 002

uint64_t ID >= 0
```

RPC
===

RPC is implemented as an asynchronous system of events running over a
transport level. Each RPC query has an Id for which the client
awaits a result with status. Status can be error or ok. Client
registers waiting handlers for specific Ids when making a requests.
For handling waiting handlers simple vector is used in TDLib,
besides the actors model for all other running state machines.

RPC queries IDs are usual monotonically increasing sequence of 
natural numbers starting from 1.

RPC net layer uses gzip for compressing bodies of the events.
Events are usually of type: request, response_ok, response_error.

Chats and messages
===

There are chat containers and dialogs. Dialogs are about a
chat container state with unreads and other specific data 
related to the caller.

Chat containers may be of personal chats or groups. Super groups
are handled separately as well as read-only channels.

A chat message is identified globally with a pair of (chat_id, date).
A chat message has also a `message id` which is a natural number
monotonically increasing starting from 1. This message id exists
outside of the chat container in which a message resides. For each
user, a message has it's own unique id.

Messages IDs define a total order of all messages received by the
client/user from the beginning. This totally ordered stream of messages
embed into an event journal of the user (EVL).

```
/--------------------------------------------------------------\
| msg(id=1, chat_id=100500)  ->
|   msg(id=2, chat_id=3)     ->
|     msg(id=3, chat_id=999) ->
|       msg(id=4, chat_id=3) -> ...

Message ID is a natural number counting all messages received by
the user starting from 1.
```

Unreads may be calculated for O(1).

QPS and PTS
===
