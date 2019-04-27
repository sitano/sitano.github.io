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
r
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

These two are interesting. The [doc](https://core.telegram.org/constructor/updates.state)
mentions them as follows:

- `pts` is a number of events occurred in a text box. That sounds misleading.
  It may stand for plain text sequence.
- `qts` is a position in a sequence of updates in secret chats.

`pts` is an Id of the message received by a user. The user EVL contains
all messages starting from 1. To synchronize state client downloads the tail
of the EVL based on `(pts, qts, date)` tuple. This allows to seeing whether
a client has seen all the messages since the last disconnection.

Both `pts` and `qts` are monotonically increasing sequences. `qts` starts from
some unreasonable number. Messages are identified uniquely by `pts` or `qts`
on a user level, and by a `Peer(chat_id, user_id) + date` on a global level.

Inbox and Outbox updates
===

Telegram uses separate entities to notify clients about what parts of the chats
history are read. It tracks incoming and outcoming histories separately. For a
client a set of incoming messages is a set of all messages of a chat history
written by others. An outcoming set of messages is a subset of chat history
which are written by a client. The client receives an event about what part of
incoming history is read by others along the updated unread count:

```
// @description Incoming messages were read or number of unread messages has been
// changed @chat_id Chat identifier @last_read_inbox_message_id Identifier of the
// last read incoming message @unread_count The number of unread messages left in
// the chat

updateChatReadInbox
    - chat_id:int53
    - last_read_inbox_message_id:int53
    - unread_count:int32 = Update;
```

A separate event on what part of the messages being sent by the client are read
by others:

```
// @description Outgoing messages were read @chat_id Chat identifier
// @last_read_outbox_message_id Identifier of last read outgoing message

updateChatReadOutbox
    - chat_id:int53
    - last_read_outbox_message_id:int53 = Update;
```

Inbox and outbox messages ids are user-level pts numbers. Thus evaluating these
events for every chat participant takes some effort for the backend system at they
are individual and relative. It's interesting what advantage this organization
provides over an absolute history updates. Having outbox updates separately
requires read history full scan to detect to which users the updates must be sent (imho).
Then the chat histories read ranges must be somehow mapped to the users events space.
Or if it uses a scan of a user events journal for finding out whose messages are
getting read when a user calls for readHistory, they still must be remapped to
the others pts spaces.

Channels and supergroups
===

They are fully separate entities. Their messages are no part of the users events
journal (EVL). Big problem for implementing such big groups of 100000 users is in
organization of the scalable fan-out and lazy updates.
