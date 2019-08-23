::    Ames extends Arvo's %pass/%give move semantics across the network.
::
::    A "forward flow" message, which is like a request, is passed to
::    Ames from a local vane.  Ames transmits the message to the peer's
::    Ames, which passes the message to the destination vane.
::
::    Once the peer has processed the "forward flow" message, it sends a
::    message acknowledgment over the wire back to the local Ames.  This
::    ack can either be positive or negative, in which case we call it a
::    "nack".  (Don't confuse Ames nacks with TCP nacks, which are a
::    different concept).
::
::    When the local Ames receives either a positive message ack or a
::    combination of a nack and nack-trace (explained in more detail
::    below), it gives an %done move to the local vane that had
::    requested the original "forward flow" message be sent.
::
::    A "backward flow" message, which is similar to a response or a
::    subscription update, is given to Ames from a local vane.  Ames
::    transmits the message to the peer's Ames, which gives the message
::    to the destination vane.
::
::    Ames will give a %memo to a vane upon hearing the message from a
::    remote. This message is a "backward flow" message, forming one of
::    potentially many responses to a "forward flow" message that a
::    local vane had passed to our local Ames, and which local Ames had
::    relayed to the remote.  Ames gives the %memo on the same duct the
::    local vane had originally used to pass Ames the "forward flow"
::    message.
::
::    Backward flow messages are acked automatically by the receiver.
::    They cannot be nacked, and Ames only uses the ack internally,
::    without notifying the client vane.
::
::    Forward flow messages can be nacked, in which case the peer will
::    send both a message-nack packet and a nack-trace message, which is
::    sent on a special diagnostic flow so as not to interfere with
::    normal operation.  The nack-trace is sent as a full Ames message,
::    instead of just a packet, because the contained error information
::    can be arbitrarily large.
::
::    Once the local Ames has received the nack-trace, it knows the peer
::    has received the full message and failed to process it.  This
::    means if we later hear an ack packet on the failed message, we can
::    ignore it.
::
::    Also, due to Ames's exactly-once delivery semantics, we know that
::    when we receive a nack-trace for message n, we know the peer has
::    positively acked all messages m+1 through n-1, where m is the last
::    message for which we heard a nack-trace.  If we haven't heard acks
::    on all those messages, we apply positive acks when we hear the
::    nack-trace.
::
::  protocol-version: current version of the ames wire protocol
::
!:
=/  protocol-version=?(%0 %1 %2 %3 %4 %5 %6 %7)  %0
=,  ames
=,  able
=*  point               point:able:jael
=*  public-keys-result  public-keys-result:able:jael
::
=>
|%
+|  %generics
::  $mk-item: constructor for +ordered-map item type
::
+*  mk-item  [key val]  [key=key val=val]
::  +ordered-map: treap with user-specified horizontal order
::
::    Conceptually smaller items go on the left, so the item with the
::    smallest key can be popped off the head. If $key is `@` and
::    .compare is +lte, then the numerically smallest item is the head.
::
++  ordered-map
  |*  [key=mold val=mold]
  =>  |%
      +$  item  (mk-item key val)
      --
  ::  +compare: item comparator for horizontal order
  ::
  |=  compare=$-([key key] ?)
  |%
  ::  +check-balance: verify horizontal and vertical orderings
  ::
  ++  check-balance
    =|  [l=(unit key) r=(unit key)]
    |=  a=(tree item)
    ^-  ?
    ::  empty tree is valid
    ::
    ?~  a  %.y
    ::  nonempty trees must maintain several criteria
    ::
    ?&  ::  if .n.a is left of .u.l, assert horizontal comparator
        ::
        ?~(l %.y (compare key.n.a u.l))
        ::  if .n.a is right of .u.r, assert horizontal comparator
        ::
        ?~(r %.y (compare u.r key.n.a))
        ::  if .a is not leftmost element, assert vertical order between
        ::  .l.a and .n.a and recurse to the left with .n.a as right
        ::  neighbor
        ::
        ?~(l.a %.y &((mor key.n.a key.n.l.a) $(a l.a, l `key.n.a)))
        ::  if .a is not rightmost element, assert vertical order
        ::  between .r.a and .n.a and recurse to the right with .n.a as
        ::  left neighbor
        ::
        ?~(r.a %.y &((mor key.n.a key.n.r.a) $(a r.a, r `key.n.a)))
    ==
  ::  +put: ordered item insert
  ::
  ++  put
    |=  [a=(tree item) =key =val]
    ^-  (tree item)
    ::  base case: replace null with single-item tree
    ::
    ?~  a  [n=[key val] l=~ r=~]
    ::  base case: overwrite existing .key with new .val
    ::
    ?:  =(key.n.a key)  a(val.n val)
    ::  if item goes on left, recurse left then rebalance vertical order
    ::
    ?:  (compare key key.n.a)
      =/  l  $(a l.a)
      ?>  ?=(^ l)
      ?:  (mor key.n.a key.n.l)
        a(l l)
      l(r a(l r.l))
    ::  item goes on right; recurse right then rebalance vertical order
    ::
    =/  r  $(a r.a)
    ?>  ?=(^ r)
    ?:  (mor key.n.a key.n.r)
      a(r r)
    r(l a(r l.r))
  ::  +peek: produce head (smallest item) or null
  ::
  ++  peek
    |=  a=(tree item)
    ^-  (unit item)
    ::
    ?~  a    ~
    ?~  l.a  `n.a
    $(a l.a)
  ::  +pop: produce .head (smallest item) and .rest or crash if empty
  ::
  ++  pop
    |=  a=(tree item)
    ^-  [head=item rest=(tree item)]
    ::
    ?~  a    !!
    ?~  l.a  [n.a r.a]
    ::
    =/  l  $(a l.a)
    :-  head.l
    ::  load .rest.l back into .a and rebalance
    ::
    ?:  |(?=(~ rest.l) (mor key.n.a key.n.rest.l))
      a(l rest.l)
    rest.l(r a(r r.rest.l))
  ::  +nip: remove root; for internal use
  ::
  ++  nip
    |=  a=(tree item)
    ^-  (tree item)
    ::
    ?>  ?=(^ a)
    ::  delete .n.a; merge and balance .l.a and .r.a
    ::
    |-  ^-  (tree item)
    ?~  l.a  r.a
    ?~  r.a  l.a
    ?:  (mor key.n.l.a key.n.r.a)
      l.a(r $(l.a r.l.a))
    r.a(l $(r.a l.r.a))
  ::  +traverse: stateful partial inorder traversal
  ::
  ::    Mutates .state on each run of .f.  Starts at .start key, or if
  ::    .start is ~, starts at the head (item with smallest key).  Stops
  ::    when .f produces .stop=%.y.  Traverses from smaller to larger
  ::    keys.  Each run of .f can replace an item's value or delete the
  ::    item.
  ::
  ++  traverse
    |*  state=mold
    |=  $:  a=(tree item)
            =state
            f=$-([state item] [(unit val) ? state])
        ==
    ^+  [state a]
    ::  acc: accumulator
    ::
    ::    .stop: set to %.y by .f when done traversing
    ::    .state: threaded through each run of .f and produced by +abet
    ::
    =/  acc  [stop=`?`%.n state=state]
    =<  abet  =<  main
    |%
    ++  abet  [state.acc a]
    ::  +main: main recursive loop; performs a partial inorder traversal
    ::
    ++  main
      ^+  .
      ::  stop if empty or we've been told to stop
      ::
      ?~  a  .
      ?:  stop.acc  .
      ::  inorder traversal: left -> node -> right, until .f sets .stop
      ::
      =>  left
      ?:  stop.acc  .
      =>  node
      ?:  stop.acc  .
      right
    ::  +node: run .f on .n.a, updating .a, .state, and .stop
    ::
    ++  node
      ^+  .
      ::  run .f on node, updating .stop.acc and .state.acc
      ::
      =^  res  acc
        ?>  ?=(^ a)
        (f state.acc n.a)
      ::  apply update to .a from .f's product
      ::
      =.  a
        ::  if .f requested node deletion, merge and balance .l.a and .r.a
        ::
        ?~  res  (nip a)
        ::  we kept the node; replace its .val; order is unchanged
        ::
        ?>  ?=(^ a)
        a(val.n u.res)
      ::
      ..node
    ::  +left: recurse on left subtree, copying mutant back into .l.a
    ::
    ++  left
      ^+  .
      ?~  a  .
      =/  lef  main(a l.a)
      lef(a a(l a.lef))
    ::  +right: recurse on right subtree, copying mutant back into .r.a
    ::
    ++  right
      ^+  .
      ?~  a  .
      =/  rig  main(a r.a)
      rig(a a(r a.rig))
    --
  ::  +tap: convert to list, smallest to largest
  ::
  ++  tap
    |=  a=(tree item)
    ^-  (list item)
    ::
    =|  b=(list item)
    |-  ^+  b
    ?~  a  b
    ::
    $(a l.a, b [n.a $(a r.a)])
  ::  +gas: put a list of items
  ::
  ++  gas
    |=  [a=(tree item) b=(list item)]
    ^-  (tree item)
    ::
    ?~  b  a
    $(b t.b, a (put a i.b))
  ::  +uni: unify two ordered maps
  ::
  ::    .b takes precedence over .a if keys overlap.
  ::
  ++  uni
    |=  [a=(tree item) b=(tree item)]
    ^-  (tree item)
    ::
    ?~  b  a
    ?~  a  b
    ?:  (mor key.n.a key.n.b)
      ::
      ?:  =(key.n.b key.n.a)
        [n.b $(a l.a, b l.b) $(a r.a, b r.b)]
      ::
      ?:  (compare key.n.b key.n.a)
        $(l.a $(a l.a, r.b ~), b r.b)
      $(r.a $(a r.a, l.b ~), b l.b)
    ::
    ?:  =(key.n.a key.n.b)
      [n.b $(b l.b, a l.a) $(b r.b, a r.a)]
    ::
    ?:  (compare key.n.a key.n.b)
      $(l.b $(b l.b, r.a ~), a r.a)
    $(r.b $(b r.b, l.a ~), a l.a)
  --
::
+|  %atomics
::
+$  bone           @udbone
+$  fragment       @uwfragment
+$  fragment-num   @udfragmentnum
+$  message-blob   @udmessageblob
+$  message-num    @udmessagenum
+$  private-key    @uwprivatekey
+$  public-key     @uwpublickey
+$  signature      @uwsignature
+$  symmetric-key  @uwsymmetrickey
::  $rank: which kind of ship address, by length
::
::    0: galaxy or star -- 2  bytes
::    1: planet         -- 4  bytes
::    2: moon           -- 8  bytes
::    3: comet          -- 16 bytes
::
+$  rank  ?(%0 %1 %2 %3)
::
+|  %kinetics
::  $channel: combined sender and receiver identifying data
::
+$  channel
  $:  [our=ship her=ship]
      now=@da
      ::  our data, common to all dyads
      ::
      $:  =our=life
          crypto-core=acru:ames
      ==
      ::  her data, specific to this dyad
      ::
      $:  =symmetric-key
          =her=life
          =her=public-key
          her-sponsor=ship
  ==  ==
::  $dyad: pair of sender and receiver ships
::
+$  dyad  [sndr=ship rcvr=ship]
::  $packet: noun representation of an ames datagram packet
::
::    Roundtrips losslessly through atom encoding and decoding.
::
::    .origin is ~ unless the packet is being forwarded.  If present,
::    it's an atom that encodes a route to another ship, such as an IPv4
::    address.  Routes are opaque to Arvo and only have meaning in the
::    interpreter. This enforces that Ames is transport-agnostic.
::
+$  packet  [dyad encrypted=? origin=(unit lane) content=*]
::  $open-packet: unencrypted packet payload, for comet self-attestation
::
::    The .signature applies to all other fields in this data structure.
::
+$  open-packet
  $:  =signature
      =public-key
      sndr=ship
      =sndr=life
      rcvr=ship
      =rcvr=life
  ==
::  $shut-packet: encrypted packet payload
::
+$  shut-packet
  $:  =sndr=life
      =rcvr=life
      =bone
      =message-num
      meat=(each fragment-meat ack-meat)
  ==
::  $fragment-meat: contents of a message-fragment packet
::
+$  fragment-meat
  $:  num-fragments=fragment-num
      =fragment-num
      =fragment
  ==
::  $ack-meat: contents of an acknowledgment packet; fragment or message
::
::    Fragment acks reference the $fragment-num of the target packet.
::
::    Message acks contain a success flag .ok, which is %.n in case of
::    negative acknowledgment (nack), along with .lag that describes the
::    time it took to process the message. .lag is zero if the message
::    was processed during a single Arvo event. At the moment, .lag is
::    always zero.
::
+$  ack-meat  (each fragment-num [ok=? lag=@dr])
::
+|  %statics
::
::  $ames-state: state for entire vane
::
+$  ames-state
  $:  peers=(map ship ship-state)
      =unix=duct
      =life
      crypto-core=acru:ames
  ==
::  $ship-state: all we know about a peer
::
::    %alien: no PKI data, so enqueue actions to perform once we learn it
::    %known: we know their life and public keys, so we have a channel
::
+$  ship-state
  $%  [%alien pending-requests]
      [%known peer-state]
  ==
::  $pending-requests: what to do when we learn a peer's life and keys
::
::    snd-messages: pleas local vanes have asked us to send
::    snd-packets: packets we've tried to send
::
+$  pending-requests
  $:  snd-messages=(list [=duct =plea])
      snd-packets=(set =blob)
  ==
::  $peer-state: state for a peer with known life and keys
::
::    route: transport-layer destination for packets to peer
::    qos: quality of service; connection status to peer
::    ossuary: bone<->duct mapper
::    snd: per-bone message pumps to send messages as fragments
::    rcv: per-bone message stills to assemble messages from fragments
::    nax: unprocessed nacks (negative acknowledgments)
::         Each value is ~ when we've received the ack packet but not a
::         nack-trace, or an error when we've received a nack-trace but
::         not the ack packet.
::
::         When we hear a nack packet or an explanation, if there's no
::         entry in .nax, we make a new entry. Otherwise, if this new
::         information completes the packet+nack-trace, we remove the
::         entry and emit a nack to the local vane that asked us to send
::         the message.
::
+$  peer-state
  $:  $:  =symmetric-key
          =life
          =public-key
          sponsor=ship
      ==
      route=(unit [direct=? =lane])
      =qos
      =ossuary
      snd=(map bone message-pump-state)
      rcv=(map bone message-still-state)
      nax=(set [=bone =message-num])
  ==
::  $qos: quality of service; how is our connection to a peer doing?
::
+$  qos
  $~  [%unborn ~]
  $%  [%live last-contact=@da]
      [%dead last-contact=@da]
      [%unborn ~]
  ==
::  $ossuary: bone<->duct bijection and .next-bone to map to a duct
::
::    The first bone is 0. They increment by 4, since each flow includes
::    a bit for each message determining forward vs. backward and a
::    second bit for whether the message is on the normal flow or the
::    associated diagnostic flow (for nack-traces).
::
+$  ossuary
  $:  =next=bone
      by-duct=(map duct bone)
      by-bone=(map bone duct)
  ==
::  $message-pump-state: persistent state for |message-pump
::
::    Messages queue up in |message-pump's .unsent-messages until they
::    can be packetized and fed into |packet-pump for sending.  When we
::    pop a message off .unsent-messages, we push as many fragments as
::    we can into |packet-pump, then place the remaining in
::    .unsent-fragments.
::
::    When we hear a packet ack, we send it to |packet-pump.  If we
::    haven't seen it before, |packet-pump reports the fresh ack.
::
::    When we hear a message ack (positive or negative), we treat that
::    as though all fragments have been acked.  If this message is not
::    .current, then it's a future message and .current has not yet been
::    acked, so we place the message in .queued-message-acks.
::
::    If we hear a message ack before we've sent all the
::    fragments for that message, clear .unsent-fragments. If the
::    message ack was positive, print it out because it indicates the
::    peer is not behaving properly.
::
::    If the ack is for the current message, emit the message ack,
::    increment .current, and check if this next message is in
::    .queued-message-acks.  If it is, emit the message (n)ack,
::    increment .current, and check the next message.  Repeat until
::    .current is not fully acked.
::
::    When we hear a message nack, we send it to |packet-pump, which
::    deletes all packets from that message.  If .current gets nacked,
::    clear .unsent-fragments and go into the same flow as when we hear
::    the last packet ack on a message.
::
::    The following equation is always true:
::    .next - .current == number of messages in flight
::
::    At the end of a task, |message-pump sends a %halt task to
::    |packet-pump, which can trigger a timer to be set or cleared based
::    on congestion control calculations. When it fires, the timer will
::    generally cause one or more packets to be resent.
::
::    Message sequence numbers start at 1 so the first message will be
::    greater than .last-acked.message-still-state on the receiver.
::
::    current: sequence number of earliest message sent or being sent
::    next: sequence number of next message to send
::    unsent-messages: messages to be sent after current message
::    unsent-fragments: fragments of current message waiting for sending
::    queued-message-acks: future message acks to be applied after current
::    packet-pump-state: state of corresponding |packet-pump
::
+$  message-pump-state
  $:  current=_`message-num`1
      next=_`message-num`1
      unsent-messages=(qeu message-blob)
      unsent-fragments=(list static-fragment)
      queued-message-acks=(map message-num ok=?)
      =packet-pump-state
  ==
::  $packet-pump-state: persistent state for |packet-pump
::
::    next-wake: last timer we've set, or null
::    live: packets in flight; sent but not yet acked
::    lost: packets to retry, since they timed out with no ack
::    metrics: congestion control information
::
+$  packet-pump-state
  $:  next-wake=(unit @da)
      live=(tree [live-packet-key live-packet-val])
      metrics=pump-metrics
  ==
::  $pump-metrics: congestion control statistics for the |pump-gauge
::
::    num-live: number of sent packets in flight
::    num-lost: number of expired packets
::    last-sent-at: last date at which we sent a packet
::    last-dead-at: most recently packet expiry
::    rtt: roundtrip time estimate
::    max-live: current window size
::
+$  pump-metrics
  $:  num-live=@ud
      num-lost=@ud
      last-sent-at=@da
      last-dead-at=@da
      rtt=@dr
      max-live=_7
  ==
+$  live-packet-key  [=message-num =fragment-num]
+$  live-packet-val
  $:  sent-packet-state
      num-fragments=fragment-num
      =fragment
  ==
+$  sent-packet-state
  $:  expiry=@da
      sent-date=@da
      retried=?
  ==
+$  static-fragment
  $:  =message-num
      num-fragments=fragment-num
      =fragment-num
      =fragment
  ==
::  $message-still-state: state of |message-still to assemble messages
::
::    last-acked: highest $message-num we've fully acknowledged
::    last-heard: highest $message-num we've heard all fragments on
::    pending-vane-ack: heard but not processed by local vane
::    live-messages: partially received messages
::
+$  message-still-state
  $:  last-acked=message-num
      last-heard=message-num
      pending-vane-ack=(qeu [=message-num message=*])
      live-messages=(map message-num partial-rcv-message)
      nax=(set message-num)
  ==
::  $partial-rcv-message: message for which we've received some fragments
::
::    num-fragments: total number of fragments in this message
::    num-received: how many fragments we've received so far
::    fragments: fragments we've received, eventually producing a $message
::
+$  partial-rcv-message
  $:  num-fragments=fragment-num
      num-received=fragment-num
      fragments=(map fragment-num fragment)
  ==
::
+|  %dialectics
::
::  $move: output effect; either request or response
::
+$  move  [=duct card=(wind note gift)]
::  $queued-event: event to be handled after initial boot completes
::
+$  queued-event
  $%  [%call =duct type=* wrapped-task=(hobo task)]
      [%take =wire =duct type=* =sign]
  ==
::  $note: request to other vane
::
::    TODO: specialize gall interface for subscription management
::
::    Ames passes a %plea note to another vane when it receives a
::    message on a "forward flow" from a peer, originally passed from
::    one of the peer's vanes to the peer's Ames.
::
::    Ames passes a %plea to itself to trigger a heartbeat message to
::    our sponsor.
::
::    Ames passes a %private-keys to Jael to request our private keys.
::    Ames passes a %public-keys to Jael to request a peer's public
::    keys.
::
+$  note
  $~  [%b %wait *@da]
  $%  $:  %b
      $%  [%wait date=@da]
          [%rest date=@da]
      ==  ==
      $:  %d
      $%  [%flog flog:dill]
      ==  ==
      $:  %j
      $%  [%private-keys ~]
          [%public-keys ships=(set ship)]
          [%turf ~]
      ==  ==
      $:  @tas
      $%  [%plea =ship =plea]
  ==  ==  ==
::  $sign: response from other vane
::
::    A vane gives a %boon sign to Ames on a duct on which it had
::    previously received a message on a "forward flow".  Ames will
::    transmit the message to the peer that had originally sent the
::    message on the forward flow.  The peer's Ames will then give the
::    message to the remote vane from which the forward flow message
::    originated.
::
+$  sign
  $~  [%b %wake ~]
  $%  $:  %b
      $%  [%wake error=(unit tang)]
      ==  ==
      $:  %j
      $%  [%private-keys =life vein=(map life ring)]
          [%public-keys =public-keys-result]
          [%turf turfs=(list turf)]
      ==  ==
      $:  @tas
      $%  [%done error=(unit error)]
          [%boon payload=*]
  ==  ==  ==
::  $message-pump-task: job for |message-pump
::
::    %memo: packetize and send application-level message
::    %hear: handle receipt of ack on fragment or message
::    %wake: handle timer firing
::
+$  message-pump-task
  $%  [%memo =message-blob]
      [%hear =message-num =ack-meat]
      [%wake ~]
  ==
::  $message-pump-gift: effect from |message-pump
::
::    %done: report message acknowledgment
::    %send: emit message fragment
::    %wait: set a new timer at .date
::    %rest: cancel timer at .date
::
+$  message-pump-gift
  $%  [%done =message-num ok=?]
      [%send =static-fragment]
      [%wait date=@da]
      [%rest date=@da]
  ==
::  $packet-pump-task: job for |packet-pump
::
::    %hear: deal with a packet acknowledgment
::    %done: deal with message acknowledgment
::    %halt: finish event, possibly updating timer
::    %wake: handle timer firing
::
+$  packet-pump-task
  $%  [%hear =message-num =fragment-num]
      [%done =message-num lag=@dr]
      [%halt ~]
      [%wake ~]
  ==
::  $packet-pump-gift: effect from |packet-pump
::
::    %send: emit message fragment
::    %wait: set a new timer at .date
::    %rest: cancel timer at .date
::
+$  packet-pump-gift
  $%  [%send =static-fragment]
      [%wait date=@da]
      [%rest date=@da]
  ==
::  $message-still-task: job for |message-still
::
::    %done: receive confirmation from vane of processing or failure
::    %drop: clear .message-num from .nax.state
::    %hear: handle receiving a message fragment packet
::      .ok: %.y unless previous failed attempt
::
+$  message-still-task
  $%  [%done ok=?]
      [%drop =message-num]
      [%hear =lane =shut-packet ok=?]
  ==
::  $message-still-gift: effect from |message-still
::
::    %memo: assembled from received packets
::    %send: emit an ack packet
::
+$  message-still-gift
  $%  [%memo =message-num message=*]
      [%send =message-num =ack-meat]
  ==
--
::  external vane interface
::
|=  pit=vase
::  larval ames, before %born sets .unix-duct; wraps adult ames core
::
=<  =*  adult-gate  .
    =|  queued-events=(qeu queued-event)
    ::
    |=  [our=ship now=@da eny=@ scry-gate=sley]
    =*  larval-gate  .
    =*  adult-core   (adult-gate +<)
    |%
    ::  +call: handle request $task
    ::
    ++  call
      |=  [=duct type=* wrapped-task=(hobo task)]
      ::
      =/  =task
        ?.  ?=(%soft -.wrapped-task)
          wrapped-task
        ~|  our^%ames-fail-soft
        ;;(task p.wrapped-task)
      ::  %born: set .unix-duct and start draining .queued-events
      ::
      ?:  ?=(%born -.task)
        ::  process %born using wrapped adult ames
        ::
        =^  moves  adult-gate  (call:adult-core duct type task)
        ::  if no events were queued up, metamorphose
        ::
        ?~  queued-events
          ~>  %slog.0^leaf/"ames: metamorphosis"
          [moves adult-gate]
        ::  kick off a timer to process the first of .queued-events
        ::
        =.  moves  :_(moves [duct %pass /larva %b %wait now])
        [moves larval-gate]
      ::  any other event: enqueue it until we have a .unix-duct
      ::
      =.  queued-events  (~(put to queued-events) %call duct type task)
      [~ larval-gate]
    ::  +take: handle response $sign
    ::
    ++  take
      |=  [=wire =duct type=* =sign]
      ::  enqueue event if not a larval drainage timer
      ::
      ?.  =(/larva wire)
        =.  queued-events  (~(put to queued-events) %take wire duct type sign)
        [~ larval-gate]
      ::  larval event drainage timer; pop and process a queued event
      ::
      ?.  ?=([%b %wake *] sign)
        ~>  %slog.0^leaf/"ames: larva: strange sign"
        [~ larval-gate]
      =^  first-event  queued-events  ~(get to queued-events)
      =^  moves  adult-gate
        ?-  -.first-event
          %call  (call:adult-core +.first-event)
          %take  (take:adult-core +.first-event)
        ==
      ::  .queued-events has been cleared; metamorphose
      ::
      ?~  queued-events
        ~>  %slog.0^leaf/"ames: metamorphosis"
        [moves adult-gate]
      ~>  %slog.0^leaf/"ames: larva: drain"
      ::  set timer to drain next event
      ::
      =.  moves  :_(moves [duct %pass /larva %b %wait now])
      [moves larval-gate]
    ::  lifecycle arms; mostly pass-throughs to the contained adult ames
    ::
    ::  TODO: don't coerce the old state
    ::
    ++  scry  scry:adult-core
    ++  stay  [%larva queued-events ames-state.adult-gate]
    ++  load
      |=  $=  old
          $%  [%larva events=_queued-events state=_ames-state.adult-gate]
              [%adult state=_ames-state.adult-gate]
          ==
      ::
      ?-    -.old
          %adult
        (load:adult-core state.old)
      ::
          %larva
        ~>  %slog.0^leaf/"ames: larva: load"
        =.  queued-events  events.old
        =.  adult-gate     (load:adult-core state.old)
        larval-gate
      ==
    --
::  adult ames, after metamorphosis from larva
::
=<
=|  =ames-state
|=  [our=ship now=@da eny=@ scry-gate=sley]
=*  ames-gate  .
|%
::  +call: handle request $task
::
::    TODO: better %crud and %hole handling
::
++  call
  |=  [=duct type=* wrapped-task=(hobo task)]
  ^-  [(list move) _ames-gate]
  ::
  =/  =task
    ?.  ?=(%soft -.wrapped-task)
      wrapped-task
    ~|  %ames-bad-task^p.wrapped-task
    ;;(task p.wrapped-task)
  ::
  =/  event-core  (per-event [our now eny scry-gate] duct ames-state)
  ::
  =^  moves  ames-state
    =<  abet
    ?-  -.task
      %born  on-born:event-core
      %crud  (on-crud:event-core [p q]:task)
      %hear  (on-hear:event-core [lane blob]:task)
      %hole  (on-hole:event-core [lane blob]:task)
      %init  (on-init:event-core ship=p.task)
      %vega  on-vega:event-core
      %wegh  on-wegh:event-core
      %plea  (on-plea:event-core [ship plea]:task)
    ==
  ::
  [moves ames-gate]
::  +take: handle response $sign
::
++  take
  |=  [=wire =duct type=* =sign]
  ^-  [(list move) _ames-gate]
  ::
  =/  event-core  (per-event [our now eny scry-gate] duct ames-state)
  ::
  =^  moves  ames-state
    =<  abet
    ?-  sign
      [@ %done *]   (on-take-done:event-core wire error.sign)
      [@ %boon *]   (on-take-boon:event-core wire payload.sign)
    ::
      [%b %wake *]  (on-take-wake:event-core wire error.sign)
    ::
      [%j %turf *]          (on-take-turf:event-core turfs.sign)
      [%j %private-keys *]  (on-priv:event-core [life vein]:sign)
      [%j %public-keys *]   (on-publ:event-core wire public-keys-result.sign)
    ==
  ::
  [moves ames-gate]
::  +stay: extract state before reload
::
++  stay  [%adult ames-state]
::  +load: load in old state after reload
::
++  load
  |=  old-state=_ames-state
  ^+  ames-gate
  ames-gate(ames-state old-state)
::  +scry: dereference namespace
::
++  scry
  |=  [fur=(unit (set monk)) ren=@tas why=shop syd=desk lot=coin tyl=path]
  ^-  (unit (unit cage))
  ::
  [~ ~]
--
::  helpers
::
|%
++  per-event
  =|  moves=(list move)
  |=  [[our=ship now=@da eny=@ scry-gate=sley] =duct =ames-state]
  |%
  ++  event-core  .
  ++  abet  [(flop moves) ames-state]
  ++  emit  |=(=move event-core(moves [move moves]))
  ::  +on-take-done: handle notice from vane that it processed a message
  ::
  ++  on-take-done
    |=  [=wire error=(unit error)]
    ^+  event-core
    ::  relay the vane ack to the foreign peer
    ::
    =+  ^-  [her=ship =bone]  (parse-bone-wire wire)
    ::
    =/  =peer-state  (got-peer-state her)
    =/  =channel     [[our her] now |2.ames-state -.peer-state]
    =/  peer-core    (make-peer-core peer-state channel)
    ::  if processing succeded, send positive ack packet and exit
    ::
    ?~  error
      abet:(run-message-still:peer-core bone %done ok=%.y)
    ::  failed; send message nack packet
    ::
    =.  event-core  abet:(run-message-still:peer-core bone %done ok=%.n)
    ::  construct nack-trace message, referencing .failed $message-num
    ::
    =/  failed=message-num  last-acked:(~(got by rcv.peer-state) bone)
    =/  =message-blob       (jam [failed u.error])
    ::  send nack-trace message on associated .nack-trace-bone
    ::
    =.  peer-core              (make-peer-core peer-state channel)
    =/  nack-trace-bone=^bone  (mix 0b10 bone)
    ::
    abet:(run-message-pump:peer-core nack-trace-bone %memo message-blob)
  ::  +on-crud: handle event failure; print to dill
  ::
  ++  on-crud
    |=  =error
    ^+  event-core
    (emit duct %pass /crud %d %flog %crud error)
  ::  +on-hear: handle raw packet receipt
  ::
  ++  on-hear
    |=  [=lane =blob]
    ^+  event-core
    (on-hear-packet lane (decode-packet blob) ok=%.y)
  ::  +on-hole: handle packet crash notification
  ::
  ++  on-hole
    |=  [=lane =blob]
    ^+  event-core
    ::
    ~>  %slog.0^leaf/"ames: %hole"
    (on-hear-packet lane (decode-packet blob) ok=%.n)
  ::  +on-hear-packet: handle mildly processed packet receipt
  ::
  ++  on-hear-packet
    |=  [=lane =packet ok=?]
    ^+  event-core
    ::
    ?:  =(our sndr.packet)
      event-core
    ::
    %.  +<
    ::
    ?.  =(our rcvr.packet)
      on-hear-forward
    ::
    ?:  encrypted.packet
      on-hear-shut
    on-hear-open
  ::  +on-hear-forward: maybe forward a packet to someone else
  ::
  ::    TODO: DDoS protection, possibly in Vere
  ::
  ++  on-hear-forward
    |=  [=lane =packet ok=?]
    ^+  event-core
    ::  set .origin.packet if it doesn't already have one, re-encode, and send
    ::
    =?  origin.packet  ?=(~ origin.packet)  `lane
    =/  =blob  (encode-packet packet)
    (send-blob rcvr.packet blob)
  ::  +on-hear-open: handle receipt of plaintext comet self-attestation
  ::
  ++  on-hear-open
    |=  [=lane =packet ok=?]
    ^+  event-core
    ::  if we already know .sndr, ignore duplicate attestation
    ::
    =/  ship-state  (~(get by peers.ames-state) sndr.packet)
    ?:  ?=([~ %known *] ship-state)
      event-core
    ::
    =/  =open-packet  ;;(open-packet packet)
    ::  assert .our and .her and lives match
    ::
    ?>  .=       sndr.open-packet  sndr.packet
    ?>  .=       rcvr.open-packet  our
    ?>  .=  sndr-life.open-packet  1
    ?>  .=  rcvr-life.open-packet  life.ames-state
    ::  no ghost comets allowed
    ::
    ?>  (lte 256 (^sein:title sndr.packet))
    ::  comet public-key must hash to its @p address
    ::
    ::    TODO how does this validation work elsewhere?
    ::
    ?>  =(`@`sndr.packet `@`(shaf %pawn public-key.open-packet))
    ::  everything after .signature is signed
    ::
    ::    TODO: should this double-cue instead of re-jamming?
    ::
    =/  signed=@  (jam +.open-packet)
    ?>  (verify-signature signed [public-key signature]:open-packet)
    ::  store comet as peer in our state
    ::
    =.  peers.ames-state
      %+  ~(put by peers.ames-state)  sndr.packet
      ^-  ^ship-state
      :-  %known
      =|  =peer-state
      =/  our-private-key  sec:ex:crypto-core.ames-state
      =/  =symmetric-key
        (derive-symmetric-key public-key.open-packet our-private-key)
      ::
      %_  peer-state
        symmetric-key  symmetric-key
        life           sndr-life.open-packet
        public-key     public-key.open-packet
        sponsor        (^sein:title sndr.packet)
        route          `[direct=%.y lane]
      ==
    ::
    event-core
  ::  +on-hear-shut: handle receipt of encrypted packet
  ::
  ++  on-hear-shut
    |=  [=lane =packet ok=?]
    ^+  event-core
    ::  encrypted packet content must be an encrypted atom
    ::
    ?>  ?=(@ content.packet)
    ::
    =/  sndr-state  (~(get by peers.ames-state) sndr.packet)
    ::  if we don't know them, maybe enqueue a jael %public-keys request
    ::
    ?.  ?=([~ %known *] sndr-state)
      (enqueue-alien-todo sndr.packet (bake same pending-requests))
    ::  decrypt packet contents using symmetric-key.channel
    ::
    ::    If we know them, we have a $channel with them, which we've
    ::    populated with a .symmetric-key derived from our private key
    ::    and their public key using elliptic curve Diffie-Hellman.
    ::
    =/  =peer-state   +.u.sndr-state
    =/  =channel      [[our sndr.packet] now |2.ames-state -.peer-state]
    =/  =shut-packet  (decrypt symmetric-key.channel content.packet)
    ::  ward against replay attacks
    ::
    ::    We only accept packets from a ship at their known life, and to
    ::    us at our current life.
    ::
    ?>  =(sndr-life.shut-packet her-life.channel)
    ?>  =(rcvr-life.shut-packet our-life.channel)
    ::  non-galaxy: update route with heard lane or forwarded lane
    ::
    =?  route.peer-state  !=(%czar (clan:title her.channel))
      ?~  origin.packet
        `[direct=%.y lane]
      `[direct=%.n u.origin.packet]
    ::  perform peer-specific handling of packet
    ::
    =/  peer-core  (make-peer-core peer-state channel)
    abet:(on-hear-shut-packet:peer-core lane shut-packet ok)
  ::  +on-take-boon: receive request to give message to peer
  ::
  ++  on-take-boon
    |=  [=wire payload=*]
    ^+  event-core
    ::
    =+  ^-  [her=ship =bone]  (parse-bone-wire wire)
    ::
    =/  =peer-state  (got-peer-state her)
    =/  =channel     [[our her] now |2.ames-state -.peer-state]
    ::
    abet:(on-memo:(make-peer-core peer-state channel) bone payload)
  ::  +on-plea: handle request to send message
  ::
  ++  on-plea
    |=  [=ship =plea]
    ^+  event-core
    ::  .plea is from local vane to foreign ship
    ::
    =/  ship-state  (~(get by peers.ames-state) ship)
    ::
    ?.  ?=([~ %known *] ship-state)
      %+  enqueue-alien-todo  ship
      |=  todos=pending-requests
      todos(snd-messages [[duct plea] snd-messages.todos])
    ::
    =/  =peer-state  +.u.ship-state
    =/  =channel     [[our ship] now |2.ames-state -.peer-state]
    ::
    =^  =bone  ossuary.peer-state  (bind-duct ossuary.peer-state duct)
    ~>  %slog.0^leaf/"ames: plea {<[our our-life.channel]^[ship her-life.channel]^bone^vane.plea^path.plea>}"
    ::
    abet:(on-memo:(make-peer-core peer-state channel) bone plea)
  ::  +on-take-wake: receive wakeup or error notification from behn
  ::
  ++  on-take-wake
    |=  [=wire error=(unit tang)]
    ^+  event-core
    ::
    =+  ^-  [her=ship =bone]  (parse-pump-timer-wire wire)
    ::
    =/  =peer-state  (got-peer-state her)
    =/  =channel     [[our her] now |2.ames-state -.peer-state]
    ::
    abet:(on-wake:(make-peer-core peer-state channel) bone error)
  ::  +on-init: first boot; subscribe to our info from jael
  ::
  ::    A non-galaxy ship makes a %public-keys subscription to stay
  ::    updated about its sponsor.  A galaxy is its own sponsor, so it
  ::    does not make such a request.
  ::
  ++  on-init
    |=  our=ship
    ^+  event-core
    ::
    =~  (emit duct %pass /turf %j %turf ~)
        (emit duct %pass /private-keys %j %private-keys ~)
    ==
  ::  +on-priv: set our private key to jael's response
  ::
  ++  on-priv
    |=  [=life vein=(map life private-key)]
    ^+  event-core
    ::
    =/  =private-key            (~(got by vein) life)
    =.  life.ames-state         life
    =.  crypto-core.ames-state  (nol:nu:crub:crypto private-key)
    ::  recalculate each peer's symmetric key
    ::
    =/  our-private-key  sec:ex:crypto-core.ames-state
    =.  peers.ames-state
      %-  ~(run by peers.ames-state)
      |=  =ship-state
      ^+  ship-state
      ::
      ?.  ?=(%known -.ship-state)
        ship-state
      ::
      =/  =peer-state  +.ship-state
      =.  symmetric-key.peer-state
        (derive-symmetric-key public-key.+.ship-state our-private-key)
      ::
      [%known peer-state]
    ::
    event-core
  ::  +on-publ: update pki data for peer or self
  ::
  ++  on-publ
    |=  [=wire =public-keys-result]
    ^+  event-core
    ::
    |^  ^+  event-core
        ::
        ?-    public-keys-result
            [%diff @ %rift *]
          (on-publ-breach [who to.diff]:public-keys-result)
        ::
            [%diff @ %keys *]
          (on-publ-rekey [who to.diff]:public-keys-result)
        ::
            [%diff @ %spon *]
          (on-publ-sponsor [who to.diff]:public-keys-result)
        ::
            [%full *]  (on-publ-full points.public-keys-result)
        ==
    ::  +on-publ-breach: handle continuity breach of .ship; wipe its state
    ::
    ::    Abandon all pretense of continuity and delete all messaging state
    ::    associated with .ship, including sent and unsent messages.
    ::
    ::    TODO: cancel all timers? otherwise we'll get spurious firings
    ::    from behn
    ::
    ::    TODO: cancel gall subscriptions on breach
    ::
    ++  on-publ-breach
      |=  [=ship =rift]
      ^+  event-core
      ::
      =/  ship-state  (~(get by peers.ames-state) ship)
      ::  we shouldn't be hearing about ships we don't care about
      ::
      ?~  ship-state
        ~>  %slog.0^leaf/"ames: breach unknown {<our^ship^rift>}"
        event-core
      ::  if an alien breached, this doesn't affect us
      ::
      ?:  ?=([~ %alien *] ship-state)
        ~>  %slog.0^leaf/"ames: breach alien {<our^ship^rift>}"
        event-core
      ~>  %slog.0^leaf/"ames: breach peer {<our^ship^rift>}"
      ::  a peer breached; drop messaging state
      ::
      =/  =peer-state  +.u.ship-state
      =/  old-qos=qos  qos.peer-state
      ::  reset all peer state other than pki data
      ::
      =.  +.peer-state  +:*^peer-state
      ::  print change to quality of service, if any
      ::
      =/  text=(unit tape)  (qos-update-text ship old-qos qos.peer-state)
      ::
      =?  event-core  ?=(^ text)
        (emit duct %pass /qos %d %flog %text u.text)
      ::  reinitialize galaxy route if applicable
      ::
      =?  route.peer-state  =(%czar (clan:title ship))
        `[direct=%.y lane=[%& ship]]
      ::
      =.  peers.ames-state
        (~(put by peers.ames-state) ship [%known peer-state])
      ::
      event-core
    ::  +on-publ-rekey: handle new key for peer
    ::
    ::    TODO: assert .crypto-suite compatibility
    ::
    ++  on-publ-rekey
      |=  $:  =ship
              =life
              crypto-suite=@ud
              =public-key
          ==
      ^+  event-core
      ::
      ~>  %slog.0^leaf/"ames: rekey {<our^ship^life>}"
      ::
      =/  ship-state  (~(get by peers.ames-state) ship)
      ?.  ?=([~ %known *] ship-state)
        =|  =point
        =.  life.point     life
        =.  keys.point     (my [life crypto-suite public-key]~)
        =.  sponsor.point  `(^sein:title ship)
        ::
        (on-publ-full (my [ship point]~))
      ::
      =/  =peer-state  +.u.ship-state
      ::
      =/  =private-key              sec:ex:crypto-core.ames-state
      =.  symmetric-key.peer-state
        (derive-symmetric-key public-key private-key)
      ::
      =.  life.peer-state           life
      =.  public-key.peer-state     public-key
      ::
      =.  peers.ames-state  (~(put by peers.ames-state) ship %known peer-state)
      event-core
    ::  +on-publ-sponsor: handle new or lost sponsor for peer
    ::
    ::    TODO: handle sponsor loss
    ::
    ++  on-publ-sponsor
      |=  [=ship sponsor=(unit ship)]
      ^+  event-core
      ::
      ?~  sponsor
        ~|  %ames-lost-sponsor^our^ship  !!
      ::
      =/  =peer-state         (got-peer-state ship)
      =.  sponsor.peer-state  u.sponsor
      ::
      =.  peers.ames-state  (~(put by peers.ames-state) ship %known peer-state)
      event-core
    ::  +on-publ-full: handle new pki data for peer(s)
    ::
    ++  on-publ-full
      |=  points=(map ship point)
      ^+  event-core
      ::
      =>  .(points ~(tap by points))
      |^  ^+  event-core
          ?~  points  event-core
          ::
          =+  ^-  [=ship =point]  i.points
          ::
          =/  old-ship-state  (~(get by peers.ames-state) ship)
          ::
          =.  event-core  (insert-peer-state ship point)
          ::
          =?  event-core  ?=([~ %alien *] old-ship-state)
            (meet-alien ship point +.u.old-ship-state)
          ::
          $(points t.points)
      ::
      ++  meet-alien
        |=  [=ship =point todos=pending-requests]
        ^+  event-core
        ::  if we're a comet, send self-attestation packet first
        ::
        =?  event-core  =(%pawn (clan:title our))
          (send-blob ship (attestation-packet ship life.point))
        ::  apply outgoing messages
        ::
        =.  event-core
          |-  ^+  event-core
          ?~  snd-messages.todos  event-core
          ::
          =.  event-core
            %-  on-plea(duct duct.i.snd-messages.todos)
            [ship plea.i.snd-messages.todos]
          ::
          $(snd-messages.todos t.snd-messages.todos)
        ::  apply outgoing packet blobs
        ::
        =.  event-core
          =/  blobs  ~(tap in snd-packets.todos)
          |-  ^+  event-core
          ?~  blobs  event-core
          ::
          =.  event-core  (send-blob ship i.blobs)
          $(blobs t.blobs)
        ::
        event-core
      --
    ::
    ++  insert-peer-state
      |=  [=ship =point]
      ^+  event-core
      ::
      =/  =peer-state     (gut-peer-state ship)
      =/  =public-key     pass:(~(got by keys.point) life.point)
      =/  =private-key    sec:ex:crypto-core.ames-state
      =/  =symmetric-key  (derive-symmetric-key public-key private-key)
      ::
      =.  life.peer-state           life.point
      =.  public-key.peer-state     public-key
      =.  symmetric-key.peer-state  symmetric-key
      =.  sponsor.peer-state        (fall sponsor.point (^sein:title ship))
      ::  automatically set galaxy route, since unix handles lookup
      ::
      =?  route.peer-state  ?=(%czar (clan:title ship))
        `[direct=%.y lane=[%& ship]]
      ::
      =.  peers.ames-state
        (~(put by peers.ames-state) ship %known peer-state)
      ::
      event-core
    --
  ::  +on-take-turf: relay %turf move from jael to unix
  ::
  ++  on-take-turf
    |=  turfs=(list turf)
    ^+  event-core
    ::
    (emit unix-duct.ames-state %give %turf turfs)
  ::  +on-wegh: produce memory usage report
  ::
  ++  on-wegh
    ^+  event-core
    ::
    =+  [known alien]=(skid ~(tap by peers.ames-state) |=(^ =(%known +<-)))
    ::
    %-  emit
    :^  duct  %give  %mass
    :+  %ames  %|
    :~  peers-known+&+known
        peers-alien+&+alien
        dot+&+ames-state
    ==
  ::  +on-born: handle unix process restart
  ::
  ++  on-born
    ^+  event-core
    ::
    =.  unix-duct.ames-state  duct
    ::
    =/  turfs
      ;;  (list turf)
      =<  q.q  %-  need  %-  need
      (scry-gate [%141 %noun] ~ %j `beam`[[our %turf %da now] /])
    ::
    (emit unix-duct.ames-state %give %turf turfs)
  ::  +on-vega: handle kernel reload
  ::
  ++  on-vega  event-core
  ::  +enqueue-alien-todo: helper to enqueue a pending request
  ::
  ::    Also requests key and life from Jael on first request.
  ::    On a comet, enqueues self-attestation packet on first request.
  ::
  ++  enqueue-alien-todo
    |=  [=ship mutate=$-(pending-requests pending-requests)]
    ^+  event-core
    ::
    =/  ship-state  (~(get by peers.ames-state) ship)
    ::  create a default $pending-requests on first contact
    ::
    =+  ^-  [already-pending=? todos=pending-requests]
        ?~  ship-state
          [%.n *pending-requests]
        [%.y ?>(?=(%alien -.u.ship-state) +.u.ship-state)]
    ::  mutate .todos and apply to permanent state
    ::
    =.  todos             (mutate todos)
    =.  peers.ames-state  (~(put by peers.ames-state) ship %alien todos)
    ::  ask jael for .sndr life and keys on first contact
    ::
    ?:  already-pending
      event-core
    (emit duct %pass /public-keys %j %public-keys [n=ship ~ ~])
  ::  +send-blob: fire packet at .ship and maybe sponsors
  ::
  ::    Send to .ship and sponsors until we find a direct lane or
  ::    encounter .our in the sponsorship chain.
  ::
  ::    If we have no PKI data for a recipient, enqueue the packet and
  ::    request the information from Jael if we haven't already.
  ::
  ++  send-blob
    |=  [=ship =blob]
    ::
    |^  ^+  event-core
        ::
        =/  ship-state  (~(get by peers.ames-state) ship)
        ::
        ?.  ?=([~ %known *] ship-state)
          %+  enqueue-alien-todo  ship
          |=  todos=pending-requests
          todos(snd-packets (~(put in snd-packets.todos) blob))
        ::
        =/  =peer-state  +.u.ship-state
        ::
        ?~  route=route.peer-state
          (try-next-sponsor sponsor.peer-state)
        ::
        =.  event-core
          (emit unix-duct.ames-state %give %send lane.u.route blob)
        ::
        ?:  direct.u.route
          event-core
        (try-next-sponsor sponsor.peer-state)
    ::
    ++  try-next-sponsor
      |=  sponsor=^ship
      ^+  event-core
      ::
      ?:  =(ship sponsor)
        event-core
      ?:  =(our sponsor)
        event-core
      ^$(ship sponsor)
    --
  ::  +attestation-packet: generate signed self-attestation for .her
  ::
  ::    Sent by a comet on first contact with a peer.  Not acked.
  ::
  ++  attestation-packet
    |=  [her=ship =her=life]
    ^-  blob
    ::
    =/  signed=_+:*open-packet
      :*  ^=  public-key  pub:ex:crypto-core.ames-state
          ^=        sndr  our
          ^=   sndr-life  life.ames-state
          ^=        rcvr  her
          ^=   rcvr-life  her-life
      ==
    ::
    =/  =private-key  sec:ex:crypto-core.ames-state
    =/  =signature    (sign-open-packet private-key signed)
    =/  =open-packet  [signature signed]
    =/  =packet       [[our her] encrypted=%.n origin=~ open-packet]
    ::
    (encode-packet packet)
  ::  +got-peer-state: lookup .her state or crash
  ::
  ++  got-peer-state
    |=  her=ship
    ^-  peer-state
    ::
    ~|  %freaky-alien^her
    =-  ?>(?=(%known -<) ->)
    (~(got by peers.ames-state) her)
  ::  +gut-peer-state: lookup .her state or default
  ::
  ++  gut-peer-state
    |=  her=ship
    ^-  peer-state
    =/  ship-state  (~(get by peers.ames-state) her)
    ?.  ?=([~ %known *] ship-state)
      *peer-state
    +.u.ship-state
  ::  +make-peer-core: create nested |peer-core for per-peer processing
  ::
  ++  make-peer-core
    |=  [=peer-state =channel]
    |%
    ++  peer-core  .
    ++  emit  |=(move peer-core(event-core (^emit +<)))
    ::
    ++  abet
      ^+  event-core
      ::
      =.  peers.ames-state
        (~(put by peers.ames-state) her.channel %known peer-state)
      ::
      event-core
    ::  +update-qos: update and maybe print connection status
    ::
    ++  update-qos
      |=  =new=qos
      ^+  peer-core
      ::
      =^  old-qos  qos.peer-state  [qos.peer-state new-qos]
      ::
      ?~  text=(qos-update-text her.channel old-qos new-qos)
        peer-core
      (emit duct %pass /qos %d %flog %text u.text)
    ::  +on-hear-shut-packet: handle receipt of ack or message fragment
    ::
    ++  on-hear-shut-packet
      |=  [=lane =shut-packet ok=?]
      ^+  peer-core
      ::  update and print connection status
      ::
      =.  peer-core  (update-qos %live last-contact=now)
      ::
      =/  =bone  bone.shut-packet
      ::
      ?:  ?=(%& -.meat.shut-packet)
        (run-message-still bone %hear lane shut-packet ok)
      ::  ignore .ok for |message-pump; just try again on error
      ::
      (run-message-pump bone %hear [message-num +.meat]:shut-packet)
    ::  +on-memo: handle request to send message
    ::
    ++  on-memo
      |=  [=bone payload=*]
      ^+  peer-core
      ::
      =/  =message-blob  (jam payload)
      (run-message-pump bone %memo message-blob)
    ::  +on-wake: handle timer expiration
    ::
    ++  on-wake
      |=  [=bone error=(unit tang)]
      ^+  peer-core
      ::  if we previously errored out, print and try again
      ::
      =?  peer-core  ?=(^ error)
        (emit duct %pass /wake-fail %d %flog %crud %ames-wake u.error)
      ::  update and print connection state
      ::
      =.  peer-core  %-  update-qos
        ?:  ?=(%unborn -.qos.peer-state)
          [%dead now]
        ?.  ?&  ?=(%live -.qos.peer-state)
                (gte now (add ~s30 last-contact.qos.peer-state))
            ==
          qos.peer-state
        [%dead last-contact.qos.peer-state]
      ::  expire direct route
      ::
      ::    Since a packet's timer expired, mark the .lane.route as
      ::    indirect.  The next packets we emit will be sent to the
      ::    receiver's sponsorship chain in case the receiver's
      ::    transport address has changed and this lane is no longer
      ::    valid.
      ::
      ::    If .her is a galaxy, the lane will always remain direct.
      ::
      =?    route.peer-state
          ?&  ?=(^ route.peer-state)
              direct.u.route.peer-state
              !=(%czar (clan:title her.channel))
          ==
        route.peer-state(direct.u %.n)
      ::  resend comet attestation packet if first message times out
      ::
      ::    The attestation packet doesn't get acked, so if we tried to
      ::    send a packet but it timed out, maybe they didn't get our
      ::    attestation.
      ::
      ::    Only resend on timeout of packets in the first message we
      ::    send them, since they should remember forever.
      ::
      =?    event-core
          ?&  ?=(%pawn (clan:title our))
              =(1 current:(~(got by snd.peer-state) bone))
          ==
        (send-blob her.channel (attestation-packet [her her-life]:channel))
      ::  maybe resend some timed out packets
      ::
      (run-message-pump bone %wake ~)
    ::  +send-shut-packet: fire encrypted packet at rcvr and maybe sponsors
    ::
    ++  send-shut-packet
      |=  =shut-packet
      ^+  peer-core
      ::  swizzle bone just before sending; TODO document
      ::
      =.  bone.shut-packet  (mix 1 bone.shut-packet)
      ::
      =/  content  (encrypt symmetric-key.channel shut-packet)
      =/  =packet  [[our her.channel] encrypted=%.y origin=~ content]
      =/  =blob    (encode-packet packet)
      ::
      =.  event-core  (send-blob her.channel blob)
      peer-core
    ::  +got-duct: look up $duct by .bone, asserting already bound
    ::
    ++  got-duct
      |=  =bone
      ^-  ^duct
      ~|  %dangling-bone^her.channel^bone
      (~(got by by-bone.ossuary.peer-state) bone)
    ::  +run-message-pump: process $message-pump-task and its effects
    ::
    ++  run-message-pump
      |=  [=bone task=message-pump-task]
      ^+  peer-core
      ::  pass .task to the |message-pump and apply state mutations
      ::
      =/  =message-pump-state
        (~(gut by snd.peer-state) bone *message-pump-state)
      ::
      =/  message-pump    (make-message-pump message-pump-state channel)
      =^  pump-gifts      message-pump-state  (work:message-pump task)
      =.  snd.peer-state  (~(put by snd.peer-state) bone message-pump-state)
      ::  process effects from |message-pump
      ::
      |^  ^+  peer-core
          ?~  pump-gifts  peer-core
          =*  gift  i.pump-gifts
          =.  peer-core
            ?-  -.gift
              %done  (on-pump-done [message-num ok]:gift)
              %send  (on-pump-send static-fragment.gift)
              %wait  (on-pump-wait date.gift)
              %rest  (on-pump-rest date.gift)
            ==
          $(pump-gifts t.pump-gifts)
      ::  +on-pump-done: handle |message-pump's report of message (n)ack
      ::
      ++  on-pump-done
        |=  [=message-num ok=?]
        ^+  peer-core
        ::  if odd bone, ack is on "subscription update" message; no-op
        ::
        ?:  =(1 (end 0 1 bone))
          peer-core
        ::  even bone; is this bone a nack-trace bone?
        ::
        ?:  =(1 (end 0 1 (rsh 0 1 bone)))
          ::  nack-trace bone; assume .ok, clear nack from |message-still
          ::
          =/  target-bone=^bone  (mix 0b10 bone)
          ::
          (run-message-still target-bone %drop message-num)
        ::  not a nack-trace bone; positive ack gets emitted trivially
        ::
        ?:  ok
          (emit (got-duct bone) %give %done error=~)
        ::  nack; enqueue, pending nack-trace message
        ::
        ::    The pump must never emit duplicate acks.  If we heard the
        ::    nack-trace message already, the pump should not generate a
        ::    duplicate %done event when we hear a message nack packet.
        ::
        =/  nax-key  [bone message-num]
        ?<  (~(has in nax.peer-state) nax-key)
        =.  nax.peer-state  (~(put in nax.peer-state) nax-key)
        ::
        peer-core
      ::  +on-pump-send: emit message fragment requested by |message-pump
      ::
      ++  on-pump-send
        |=  =static-fragment
        ^+  peer-core
        ::  encrypt and encode .static-fragment to .blob bitstream
        ::
        %-  send-shut-packet  :*
          our-life.channel
          her-life.channel
          bone
          message-num.static-fragment
          %&  +.static-fragment
        ==
      ::  +on-pump-wait: relay |message-pump's set-timer request
      ::
      ++  on-pump-wait
        |=  date=@da
        ^+  peer-core
        ::
        =/  =wire  (make-pump-timer-wire her.channel bone)
        (emit duct %pass wire %b %wait date)
      ::  +on-pump-rest: relay |message-pump's unset-timer request
      ::
      ++  on-pump-rest
        |=  date=@da
        ^+  peer-core
        ::
        =/  =wire  (make-pump-timer-wire her.channel bone)
        (emit duct %pass wire %b %rest date)
      --
    ::  +run-message-still: process $message-still-task and its effects
    ::
    ++  run-message-still
      |=  [=bone task=message-still-task]
      ^+  peer-core
      ::  pass .task to the |message-still and apply state mutations
      ::
      =/  =message-still-state
        (~(gut by rcv.peer-state) bone *message-still-state)
      ::
      =/  message-still   (make-message-still message-still-state channel)
      =^  still-gifts     message-still-state  (work:message-still task)
      =.  rcv.peer-state  (~(put by rcv.peer-state) bone message-still-state)
      ::  process effects from |message-still
      ::
      |^  ^+  peer-core
          ?~  still-gifts  peer-core
          =*  gift  i.still-gifts
          =.  peer-core
            ?-  -.gift
              %memo  (on-still-memo [message-num message]:gift)
              %send  (on-still-send [message-num ack-meat]:gift)
            ==
          $(still-gifts t.still-gifts)
      ::  +on-still-send: emit ack packet as requested by |message-still
      ::
      ++  on-still-send
        |=  [=message-num =ack-meat]
        ^+  peer-core
        ::
        %-  send-shut-packet  :*
          our-life.channel
          her-life.channel
          bone
          message-num
          %|  ack-meat
        ==
      ::  +on-still-memo: dispatch message received by |message-still
      ::
      ::    odd bone:                %plea request message
      ::    even bone, 0 second bit: %boon response message
      ::    even bone, 1 second bit: nack-trace %boon message
      ::
      ++  on-still-memo
        ?:  =(1 (end 0 1 bone))
          on-still-plea
        ?:  =(0 (end 0 1 (rsh 0 1 bone)))
          on-still-boon
        on-still-nack-trace
      ::  +on-still-boon: handle response message received by |message-still
      ::
      ::    .bone must be mapped in .ossuary.peer-state, or we crash.
      ::    This means a malformed message will kill a channel.  We
      ::    could change this to a no-op if we had some sort of security
      ::    reporting.
      ::
      ++  on-still-boon
        |=  [=message-num message=*]
        ^+  peer-core
        ~>  %slog.0^leaf/"ames: boon {<her.channel^bone>}"
        ::  send ack unconditionally
        ::
        =.  peer-core  (run-message-still bone %done ok=%.y)
        ::  give message to client vane
        ::
        (emit (got-duct bone) %give %boon message)
      ::  +on-still-nack-trace: handle nack-trace received by |message-still
      ::
      ++  on-still-nack-trace
        |=  [=message-num message=*]
        ^+  peer-core
        ~>  %slog.0^leaf/"ames: nack trace {<her.channel^bone>}"
        ::
        =+  ;;  [=failed=^message-num =error]  message
        ::  ack nack-trace message (only applied if we don't later crash)
        ::
        =.  peer-core  (run-message-still bone %done ok=%.y)
        ::  flip .bone's second bit to find referenced flow
        ::
        =/  target-bone=^bone  (mix 0b10 bone)
        =/  nax-key            [target-bone failed-message-num]
        ::  if we haven't heard a message nack, pretend we have
        ::
        ::    The nack-trace message counts as a valid message nack on
        ::    the original failed message.
        ::
        ::    This prevents us from having to wait for a message nack
        ::    packet, which would mean we couldn't immediately ack the
        ::    nack-trace message, which would in turn violate the
        ::    semantics of backward flows.
        ::
        =?  peer-core  !(~(has in nax.peer-state) nax-key)
          %-  run-message-pump
          [target-bone %hear failed-message-num %| ok=%.n lag=`@dr`0]
        ::  clear the nack from our state and relay to vane
        ::
        =.  nax.peer-state  (~(del in nax.peer-state) nax-key)
        ::
        (emit (got-duct target-bone) %give %done `error)
      ::  +on-still-plea: handle request message received by |message-still
      ::
      ++  on-still-plea
        |=  [=message-num message=*]
        ^+  peer-core
        ~>  %slog.0^leaf/"ames: plea {<her.channel^bone>}"
        ::  is this the first time we're trying to process this message?
        ::
        ?.  ?=([%hear * * ok=%.n] task)
          ::  fresh plea; pass to client vane
          ::
          =+  ;;  =plea  message
          ::
          =/  =wire  (make-bone-wire her.channel bone)
          ::
          ?+  vane.plea  ~|  %ames-evil-vane^our^her.channel^vane.plea  !!
            %a  (emit duct %pass wire %a %plea her.channel plea)
            %c  (emit duct %pass wire %c %plea her.channel plea)
            %g  (emit duct %pass wire %g %plea her.channel plea)
            %j  (emit duct %pass wire %j %plea her.channel plea)
          ==
        ::  we previously crashed on this message; send nack
        ::
        =.  peer-core  (run-message-still bone %done ok=%.n)
        ::  also send nack-trace
        ::
        =/  nack-trace-bone=^bone  (mix 0b10 bone)
        =/  =message-blob          (jam [message-num ~])
        ::
        (run-message-pump nack-trace-bone %memo message-blob)
      --
    --
  --
::  +make-message-pump: constructor for |message-pump
::
++  make-message-pump
  |=  [state=message-pump-state =channel]
  =|  gifts=(list message-pump-gift)
  ::
  |%
  ++  message-pump  .
  ++  give  |=(gift=message-pump-gift message-pump(gifts [gift gifts]))
  ++  packet-pump  (make-packet-pump packet-pump-state.state channel)
  ::  +work: handle a $message-pump-task
  ::
  ++  work
    |=  task=message-pump-task
    ^+  [gifts state]
    ::
    =~  (dispatch-task task)
        feed-packets
        (run-packet-pump %halt ~)
        [(flop gifts) state]
    ==
  ::  +dispatch-task: perform task-specific processing
  ::
  ++  dispatch-task
    |=  task=message-pump-task
    ^+  message-pump
    ::
    ?-  -.task
      %memo  (on-memo message-blob.task)
      %wake  (run-packet-pump task)
      %hear
        ?-  -.ack-meat.task
          %&  (on-hear [message-num fragment-num=p.ack-meat]:task)
          %|  (on-done [message-num [ok lag]:p.ack-meat]:task)
    ==  ==
  ::  +on-memo: handle request to send a message
  ::
  ++  on-memo
    |=  =message-blob
    ^+  message-pump
    ::
    =.  unsent-messages.state  (~(put to unsent-messages.state) message-blob)
    message-pump
  ::  +on-hear: handle packet acknowledgment
  ::
  ++  on-hear
    |=  [=message-num =fragment-num]
    ^+  message-pump
    ::  pass to |packet-pump unless duplicate or future ack
    ::
    ?.  (is-message-num-in-range message-num)
      message-pump
    (run-packet-pump %hear message-num fragment-num)
  ::  +on-done: handle message acknowledgment
  ::
  ++  on-done
    ::  check-old: loop terminator variable
    ::
    =/  check-old=?  %.y
    |=  [=message-num ok=? lag=@dr]
    ^+  message-pump
    ::  unsent messages from the future should never get acked
    ::
    ?>  (lth message-num next.state)
    ::  ignore duplicate message acks
    ::
    ?:  (lth message-num current.state)
      message-pump
    ::  future nack implies positive ack on all earlier messages
    ::
    ?:  &(!ok check-old)
      |-  ^+  message-pump
      ::  base case: current message got nacked; handle same as ack
      ::
      ?:  =(message-num current.state)
        ^$(check-old %.n)
      ::  recursive case: future message got nacked
      ::
      =.  message-pump  ^$(ok %.y, message-num current.state)
      $
    ::  ignore duplicate and future acks
    ::
    ?.  (is-message-num-in-range message-num)
      message-pump
    ::  clear and print .unsent-fragments if nonempty
    ::
    =?    unsent-fragments.state
        &(=(current next) ?=(^ unsent-fragments)):state
      ::
      ~>  %slog.0^leaf/"ames: early message ack {<ok^her.channel>}"
      ~
    ::  clear all packets from this message from the packet pump
    ::
    =.  message-pump  (run-packet-pump %done message-num lag)
    ::  enqueue this ack to be sent back to local client vane
    ::
    =.  queued-message-acks.state
      (~(put by queued-message-acks.state) message-num ok)
    ::  emit local acks from .queued-message-acks until incomplete
    ::
    |-  ^+  message-pump
    ::  if .current hasn't been fully acked, we're done
    ::
    ?~  ack=(~(get by queued-message-acks.state) current.state)
      message-pump
    ::  .current is complete; pop, emit local ack, and try next message
    ::
    =.  queued-message-acks.state
      (~(del by queued-message-acks.state) current.state)
    ::
    =.  message-pump  (give %done current.state ok.u.ack)
    ::
    $(current.state +(current.state))
  ::  +is-message-num-in-range: %.y unless duplicate or future ack
  ::
  ++  is-message-num-in-range
    |=  =message-num
    ^-  ?
    ::
    ?:  (gte message-num next.state)
      %.n
    ?:  (lth message-num current.state)
      %.n
    !(~(has by queued-message-acks.state) message-num)
  ::  +feed-packets: give packets to |packet-pump until full
  ::
  ++  feed-packets
    ::  if nothing to send, no-op
    ::
    ?:  &(=(~ unsent-messages) =(~ unsent-fragments)):state
      message-pump
    ::  we have unsent fragments of the current message; feed them
    ::
    ?.  =(~ unsent-fragments.state)
      =/  res  (feed:packet-pump unsent-fragments.state)
      =+  [unsent packet-pump-gifts packet-pump-state]=res
      ::
      =.  unsent-fragments.state   unsent
      =.  packet-pump-state.state  packet-pump-state
      ::
      =.  message-pump  (process-packet-pump-gifts packet-pump-gifts)
      ::  if it sent all of them, feed it more; otherwise, we're done
      ::
      ?~  unsent
        feed-packets
      message-pump
    ::  .unsent-messages is nonempty; pop a message off and feed it
    ::
    =^  =message-blob  unsent-messages.state  ~(get to unsent-messages.state)
    ::  break .message into .chunks and set as .unsent-fragments
    ::
    =.  unsent-fragments.state  (split-message next.state message-blob)
    ::  try to feed packets from the next message
    ::
    =.  next.state  +(next.state)
    feed-packets
  ::  +run-packet-pump: call +work:packet-pump and process results
  ::
  ++  run-packet-pump
    |=  =packet-pump-task
    ^+  message-pump
    ::
    =^  packet-pump-gifts  packet-pump-state.state
      (work:packet-pump packet-pump-task)
    ::
    (process-packet-pump-gifts packet-pump-gifts)
  ::  +process-packet-pump-gifts: pass |packet-pump effects up the chain
  ::
  ++  process-packet-pump-gifts
    |=  packet-pump-gifts=(list packet-pump-gift)
    ^+  message-pump
    ::
    ?~  packet-pump-gifts
      message-pump
    =.  message-pump  (give i.packet-pump-gifts)
    ::
    $(packet-pump-gifts t.packet-pump-gifts)
  --
::  +make-packet-pump: construct |packet-pump core
::
++  make-packet-pump
  |=  [state=packet-pump-state =channel]
  =|  gifts=(list packet-pump-gift)
  |%
  ++  packet-pump  .
  ++  give  |=(packet-pump-gift packet-pump(gifts [+< gifts]))
  ::  +packet-queue: type for all sent fragments, ordered by sequence number
  ::
  ++  packet-queue
    %-  (ordered-map live-packet-key live-packet-val)
    |=  [a=live-packet-key b=live-packet-key]
    ^-  ?
    ::
    ?:  (lth message-num.a message-num.b)
      %.y
    ?:  (gth message-num.a message-num.b)
      %.n
    (lte fragment-num.a fragment-num.b)
  ::  +gauge: inflate a |pump-gauge to track congestion control
  ::
  ++  gauge  (make-pump-gauge now.channel metrics.state)
  ::  +work: handle $packet-pump-task request
  ::
  ++  work
    |=  task=packet-pump-task
    ^+  [gifts state]
    ::
    =-  [(flop gifts) state]
    ::
    ?-  -.task
      %hear  (on-hear [message-num fragment-num]:task)
      %done  (on-done message-num.task)
      %wake  resend-lost(next-wake.state ~)
      %halt  set-wake
    ==
  ::  +resend-lost: resend as many lost packets as .gauge will allow
  ::
  ++  resend-lost
    ^+  packet-pump
    ::
    =-  =.  packet-pump  core.-
        =.  live.state   live.-
        packet-pump
    ::  acc: state to thread through traversal
    ::
    ::    num-slots: start with max retries; decrement on each resend
    ::
    =|  $=  acc
        $:  num-slots=_num-retry-slots:gauge
            core=_packet-pump
        ==
    ::
    ^+  [acc live=live.state]
    ::
    %^  (traverse:packet-queue _acc)  live.state  acc
    |=  $:  acc=_acc
            key=live-packet-key
            val=live-packet-val
        ==
    ^-  [new-val=(unit live-packet-val) stop=? _acc]
    ::  load mutant environment
    ::
    =.  packet-pump  core.acc
    ::  if we can't send any more packets, we're done
    ::
    ?:  =(0 num-slots.acc)
      [`val stop=%.y acc]
    ::  if the packet hasn't expired, we're done
    ::
    ?:  (gte expiry.val now.channel)
      [`val stop=%.y acc]
    ::  packet has expired so re-send it
    ::
    =/  =static-fragment
      =>  [key val]
      [message-num num-fragments fragment-num fragment]
    ::
    =.  packet-pump    (give %send static-fragment)
    =.  metrics.state  (on-resent:gauge -.val)
    ::  update $sent-packet-state in .val and continue
    ::
    =.  expiry.val     (next-retry-expiry:gauge -.val)
    =.  sent-date.val  now.channel
    =.  retried.val    %.y
    ::
    ~&  [%ames-resend [our our-life her her-life]:channel key]
    ::
    [`val stop=%.n (dec num-slots.acc) packet-pump]
  ::  +feed: try to send a list of packets, returning unsent and effects
  ::
  ++  feed
    |=  fragments=(list static-fragment)
    ^+  [fragments gifts state]
    ::  return unsent back to caller and reverse effects to finalize
    ::
    =-  ::~&  %ames-feed^(lent fragments)^%unsent^(lent unsent)
        [unsent (flop gifts) state]
    ::
    ^+  [unsent=fragments packet-pump]
    ::  resend lost packets first, possibly adjusting congestion control
    ::
    =.  packet-pump  resend-lost
    ::  bite off as many fragments as we can send
    ::
    =/  num-slots  num-slots:gauge
    =/  sent       (scag num-slots fragments)
    =/  unsent     (slag num-slots fragments)
    ::
    :-  unsent
    ^+  packet-pump
    ::  if nothing to send, we're done
    ::
    ?~  sent  packet-pump
    ::  convert $static-fragment's into +ordered-set [key val] pairs
    ::
    =/  send-list
      %+  turn  sent
      |=  static-fragment
      ^-  [key=live-packet-key val=live-packet-val]
      ::
      :-  [message-num fragment-num]
      :-  :+  expiry=next-expiry:gauge
            sent-date=now.channel
          retried=%.n
      [num-fragments fragment]
    ::  update .live and .metrics
    ::
    =.  live.state     (gas:packet-queue live.state send-list)
    =.  metrics.state  (on-sent:gauge (lent send-list))
    ::  TMI
    ::
    =>  .(sent `(list static-fragment)`sent)
    ::  emit a $packet-pump-gift for each packet to send
    ::
    |-  ^+  packet-pump
    ?~  sent  packet-pump
    =.  packet-pump  (give %send i.sent)
    $(sent t.sent)
  ::  +on-hear: handle ack on a live packet
  ::
  ::    Traverse .live from the head, marking packets as lost until we
  ::    find the acked packet. Then delete the acked packet and try to
  ::    resend lost packets.
  ::
  ::    If we don't find the acked packet, no-op: no mutations, effects,
  ::    or resending of lost packets.
  ::
  ++  on-hear
    |=  [=message-num =fragment-num]
    ^+  packet-pump
    ::
    =-  ::  if no sent packet matches the ack, don't apply mutations or effects
        ::
        ?.  found.-
          ~>  %slog.0^leaf/"ames: hear: no-op"
          packet-pump
        ::~&  %ames-hear-ack^message-num^fragment-num
        ::
        =.  metrics.state  metrics.-
        =.  live.state     live.-
        ::
        resend-lost
    ::
    ^-  $:  [found=? metrics=pump-metrics]
            live=(tree [live-packet-key live-packet-val])
        ==
    ::
    =/  acc=[found=? metrics=pump-metrics]  [%.n metrics.state]
    ::
    %^  (traverse:packet-queue _acc)  live.state  acc
    |=  $:  acc=_acc
            key=live-packet-key
            val=live-packet-val
        ==
    ^-  [new-val=(unit live-packet-val) stop=? _acc]
    ::
    =/  gauge  (make-pump-gauge now.channel metrics.acc)
    ::  is this the acked packet?
    ::
    ?:  =(key [message-num fragment-num])
      ::  delete acked packet, update metrics, and stop traversal
      ::
      :+  new-val=~
        stop=%.y
      [found=%.y metrics=(on-ack:gauge -.val)]
    ::  ack was out of order; mark expired, tell gauge, and continue
    ::
    :+  new-val=`val(expiry `@da`0)
      stop=%.n
    [found=%.n metrics=(on-skipped-packet:gauge -.val)]
  ::  +on-done: apply ack to all packets from .message-num
  ::
  ++  on-done
    |=  =message-num
    ^+  packet-pump
    ::
    =-  =.  metrics.state  metrics.-
        =.  live.state     live.-
        ::
        resend-lost
    ::
    ^-  $:  metrics=pump-metrics
            live=(tree [live-packet-key live-packet-val])
        ==
    ::
    %^  (traverse:packet-queue pump-metrics)  live.state  acc=metrics.state
    |=  $:  metrics=pump-metrics
            key=live-packet-key
            val=live-packet-val
        ==
    ^-  [new-val=(unit live-packet-val) stop=? pump-metrics]
    ::
    =/  gauge  (make-pump-gauge now.channel metrics)
    ::  if ack was out of order, mark expired and continue
    ::
    ?:  (lth message-num.key message-num)
      :+  new-val=`val(expiry `@da`0)
        stop=%.n
      metrics=(on-skipped-packet:gauge -.val)
    ::  if packet was from acked message, delete it and continue
    ::
    ?:  =(message-num.key message-num)
      [new-val=~ stop=%.n metrics=(on-ack:gauge -.val)]
    ::  we've gone past the acked message; we're done
    ::
    [new-val=`val stop=%.y metrics]
  ::  +set-wake: set, unset, or reset timer, emitting moves
  ::
  ++  set-wake
    ^+  packet-pump
    ::  if nonempty .live, peek at head to get next wake time
    ::
    =/  new-wake=(unit @da)
      ?~  head=(peek:packet-queue live.state)
        ~
      `expiry.val.u.head
    ::  no-op if no change
    ::
    ?:  =(new-wake next-wake.state)  packet-pump
    ::  unset old timer if non-null
    ::
    =?  packet-pump  !=(~ next-wake.state)
      =/  old  (need next-wake.state)
      =.  next-wake.state  ~
      (give %rest old)
    ::  set new timer if non-null
    ::
    =?  packet-pump  ?=(^ new-wake)
      =.  next-wake.state  new-wake
      (give %wait u.new-wake)
    ::
    packet-pump
  --
::  +make-pump-gauge: construct |pump-gauge congestion control core
::
::    TODO: actual congestion control
::
++  make-pump-gauge
  |=  [now=@da pump-metrics]
  =*  metrics  +<+
  |%
  ::  +next-expiry: when should a newly sent fresh packet time out?
  ::
  ++  next-expiry
    ^-  @da
    ::
    (add now ~s5)
  ::  +next-retry-expiry: when should a resent packet time out?
  ::
  ++  next-retry-expiry
    |=  sent-packet-state
    ^-  @da
    (add now ~s10)
  ::  +has-slot: can we send a packet right now?
  ::
  ++  has-slot
    ^-  ?
    (gth num-slots 0)
  ::  +num-slots: how many packets can we send right now?
  ::
  ++  num-slots
    ^-  @ud
    ?.  (gth max-live num-live)
      0
    (sub max-live num-live)
  ::  +num-retry-slots: how many lost packets can we resend right now?
  ::
  ++  num-retry-slots
    ^-  @ud
    max-live
  ::  +on-skipped-packet: adjust metrics based on a misordered ack
  ::
  ::    TODO: decrease .max-live
  ::
  ++  on-skipped-packet
    |=  sent-packet-state
    metrics
  ::  +on-ack: adjust metrics based on a packet getting acknowledged
  ::
  ::    TODO: adjust .rtt and .max-live
  ::
  ++  on-ack
    |=  sent-packet-state
    ^-  pump-metrics
    ::
    metrics(num-live (dec num-live))
  ::  +on-sent: adjust metrics based on sending .num-sent fresh packets
  ::
  ++  on-sent
    |=  num-sent=@ud
    ^-  pump-metrics
    ::
    metrics(num-live (add num-sent num-live))
  ::  +on-resent: adjust metrics based on retrying an expired packet
  ::
  ++  on-resent
    |=  sent-packet-state
    ^-  pump-metrics
    metrics
  --
::  +make-message-still: construct |message-still message receiver core
::
++  make-message-still
  |=  [state=message-still-state =channel]
  =|  gifts=(list message-still-gift)
  |%
  ++  message-still  .
  ++  give  |=(message-still-gift message-still(gifts [+< gifts]))
  ++  work
    |=  task=message-still-task
    ^+  [gifts state]
    ::
    =-  [(flop gifts) state]
    ::
    ?-  -.task
      %done  (on-done ok.task)
      %drop  (on-drop message-num.task)
      %hear  (on-hear [lane shut-packet ok]:task)
    ==
  ::  +on-hear: receive message fragment, possibly completing message
  ::
  ++  on-hear
    |=  [=lane =shut-packet ok=?]
    ^+  message-still
    ::  we know this is a fragment, not an ack; expose into namespace
    ::
    ?>  ?=(%& -.meat.shut-packet)
    =+  [num-fragments fragment-num fragment]=+.meat.shut-packet
    ::  seq: message sequence number, for convenience
    ::
    =/  seq  message-num.shut-packet
    ::  ignore messages from far future; limit to 10 in progress
    ::
    ?:  (gte seq (add 10 last-acked.state))
      ~>  %slog.0^leaf/"ames: future %hear {<seq^last-acked.state>}"
      message-still
    ::
    =/  is-last-fragment=?  =(+(fragment-num) num-fragments)
    ::  always ack a dupe!
    ::
    ?:  (lte seq last-acked.state)
      ?.  is-last-fragment
        ::  single packet ack
        ::
        ~>  %slog.0^leaf/"ames: send dupe ack {<seq^fragment-num>}"
        (give %send seq %& fragment-num)
      ::  whole message (n)ack
      ::
      =/  ok=?  !(~(has in nax.state) seq)
      ~>  %slog.0^leaf/"ames: send dupe message ack {<seq>} ok={<ok>}"
      (give %send seq %| ok lag=`@dr`0)
    ::  last-acked<seq<=last-heard; heard message, unprocessed
    ::
    ?:  (lte seq last-heard.state)
      ?:  is-last-fragment
        ::  drop last packet since we don't know whether to ack or nack
        ::
        ~>  %slog.0^leaf/"ames: hear last in-progress {<her.channel^seq>}"
        message-still
      ::  ack all other packets
      ::
      ::~&  %send-ack^seq^fragment-num
      (give %send seq %& fragment-num)
    ::  last-heard<seq<10+last-heard; this is a packet in a live message
    ::
    =/  =partial-rcv-message
      ::  create default if first fragment
      ::
      ?~  existing=(~(get by live-messages.state) seq)
        [num-fragments num-received=0 fragments=~]
      ::  we have an existing partial message; check parameters match
      ::
      ?>  (gth num-fragments.u.existing fragment-num)
      ?>  =(num-fragments.u.existing num-fragments)
      ::
      u.existing
    ::
    =/  already-heard-fragment=?
      (~(has by fragments.partial-rcv-message) fragment-num)
    ::  ack dupes except for the last fragment, in which case drop
    ::
    ?:  already-heard-fragment
      ?:  is-last-fragment
        ~>  %slog.0^leaf/"ames: hear last dupe {<her.channel^seq>}"
        message-still
      ~>  %slog.0^leaf/"ames: send dupe ack {<her.channel^seq^fragment-num>}"
      (give %send seq %& fragment-num)
    ::  new fragment; store in state and check if message is done
    ::
    =.  num-received.partial-rcv-message
      +(num-received.partial-rcv-message)
    ::
    =.  fragments.partial-rcv-message
      (~(put by fragments.partial-rcv-message) fragment-num fragment)
    ::
    =.  live-messages.state
      (~(put by live-messages.state) seq partial-rcv-message)
    ::  ack any packet other than the last one, and continue either way
    ::
    =?  message-still  !is-last-fragment
      ::~&  %send-ack^seq^fragment-num
      (give %send seq %& fragment-num)
    ::  enqueue all completed messages starting at +(last-heard.state)
    ::
    |-  ^+  message-still
    ::  if this is not the next message to ack, we're done
    ::
    ?.  =(seq +(last-heard.state))
      message-still
    ::  if we haven't heard anything from this message, we're done
    ::
    ?~  live=(~(get by live-messages.state) seq)
      message-still
    ::  if the message isn't done yet, we're done
    ::
    ?.  =(num-received num-fragments):u.live
      message-still
    ::  we have whole message; update state, assemble, and send to vane
    ::
    =.  last-heard.state     +(last-heard.state)
    =.  live-messages.state  (~(del by live-messages.state) seq)
    ::
    ~>  %slog.0^leaf/"ames: hear {<her.channel>} {<num-fragments.u.live>}kb"
    =/  message=*  (assemble-fragments [num-fragments fragments]:u.live)
    =.  message-still  (enqueue-to-vane seq message)
    ::
    $(seq +(seq))
  ::  +enqueue-to-vane: enqueue message to be sent to local vane
  ::
  ++  enqueue-to-vane
    |=  [seq=message-num message=*]
    ^+  message-still
    ::
    =/  empty=?  =(~ pending-vane-ack.state)
    =.  pending-vane-ack.state  (~(put to pending-vane-ack.state) seq message)
    ?.  empty
      message-still
    (give %memo seq message)
  ::  +on-done: handle confirmation of message processing from vane
  ::
  ++  on-done
    |=  ok=?
    ^+  message-still
    ::
    =^  pending  pending-vane-ack.state  ~(get to pending-vane-ack.state)
    =/  =message-num  message-num.p.pending
    ::
    =.  last-acked.state  +(last-acked.state)
    =?  nax.state  !ok  (~(put in nax.state) message-num)
    ::
    (give %send message-num %| ok lag=`@dr`0)
  ::  +on-drop: drop .message-num from our .nax state
  ::
  ++  on-drop
    |=  =message-num
    ^+  message-still
    ::
    =.  nax.state  (~(del in nax.state) message-num)
    ::
    message-still
  --
::  +qos-update-text: notice text for if connection state changes
::
++  qos-update-text
  |=  [=ship old=qos new=qos]
  ^-  (unit tape)
  ::
  ?+  [-.old -.new]  ~
    [%unborn %live]  `"; {(scow %p ship)} is your neighbor"
    [%dead %live]    `"; {(scow %p ship)} is ok"
    [%live %dead]    `"; {(scow %p ship)} not responding still trying"
    [%unborn %dead]  `"; {(scow %p ship)} not responding still trying"
    [%live %unborn]  `"; {(scow %p ship)} is dead"
    [%dead %unborn]  `"; {(scow %p ship)} is dead"
  ==
::  +split-message: split message into kilobyte-sized fragments
::
++  split-message
  |=  [=message-num =message-blob]
  ^-  (list static-fragment)
  ::
  =/  fragments=(list fragment)   (rip 13 message-blob)
  =/  num-fragments=fragment-num  (lent fragments)
  =|  counter=@
  ::
  |-  ^-  (list static-fragment)
  ?~  fragments  ~
  ::
  :-  [message-num num-fragments counter i.fragments]
  ::
  $(fragments t.fragments, counter +(counter))
::  +assemble-fragments: concatenate fragments into a $message
::
++  assemble-fragments
  |=  [num-fragments=fragment-num fragments=(map fragment-num fragment)]
  ^-  *
  ::
  =|  sorted=(list fragment)
  =.  sorted
    =/  index=fragment-num  0
    |-  ^+  sorted
    ?:  =(index num-fragments)
      sorted
    $(index +(index), sorted [(~(got by fragments) index) sorted])
  ::
  %-  cue
  %+  can   13
  %+  turn  (flop sorted)
  |=(a=@ [1 a])
::  +bind-duct: find or make new $bone for .duct in .ossuary
::
++  bind-duct
  |=  [=ossuary =duct]
  ^+  [next-bone.ossuary ossuary]
  ::
  ?^  existing=(~(get by by-duct.ossuary) duct)
    [u.existing ossuary]
  ::
  :-  next-bone.ossuary
  :+  (add 4 next-bone.ossuary)
    (~(put by by-duct.ossuary) duct next-bone.ossuary)
  (~(put by by-bone.ossuary) next-bone.ossuary duct)
::  +make-bone-wire: encode ship and bone in wire for sending to vane
::
++  make-bone-wire
  |=  [her=ship =bone]
  ^-  wire
  ::
  /bone/(scot %p her)/(scot %ud bone)
::  +parse-bone-wire: decode ship and bone from wire from local vane
::
++  parse-bone-wire
  |=  =wire
  ^-  [her=ship =bone]
  ::
  ~|  %ames-wire-bone^wire
  ?>  ?=([%bone @ @ ~] wire)
  [`@p`(slav %p i.t.wire) `@ud`(slav %ud i.t.t.wire)]
::  +make-pump-timer-wire: construct wire for |packet-pump timer
::
++  make-pump-timer-wire
  |=  [her=ship =bone]
  ^-  wire
  /pump/(scot %p her)/(scot %ud bone)
::  +parse-pump-timer-wire: parse .her and .bone from |packet-pump wire
::
++  parse-pump-timer-wire
  |=  =wire
  ^-  [her=ship =bone]
  ::
  ~|  %ames-wire-timer^wire
  ?>  ?=([%pump @ @ ~] wire)
  [`@p`(slav %p i.t.wire) `@ud`(slav %ud i.t.t.wire)]
::  +sign-open-packet: sign the contents of an $open-packet
::
++  sign-open-packet
  |=  [=private-key signed=_+:*open-packet]
  ^-  signature
  ::
  (sign:ed:crypto private-key (jam signed))
::  +verify-signature: use .public-key to verify .signature on .content
::
++  verify-signature
  |=  [content=@ =public-key =signature]
  ^-  ?
  ::
  (veri:ed:crypto signature content public-key)
::  +derive-symmetric-key: $symmetric-key from $private-key and $public-key
::
::    Assumes keys have a tag on them like the result of the |ex:crub core.
::
++  derive-symmetric-key
  |=  [=public-key =private-key]
  ^-  symmetric-key
  ::
  ~|  [public-key=public-key private-key=private-key]
  ::
  ?>  =('b' (end 3 1 public-key))
  =.  public-key  (rsh 8 1 (rsh 3 1 public-key))
  ::
  ?>  =('B' (end 3 1 private-key))
  =.  private-key  (rsh 8 1 (rsh 3 1 private-key))
  ::
  `@`(shar:ed:crypto public-key private-key)
::  +encrypt: encrypt $shut-packet into atomic packet content
::
++  encrypt
  |=  [=symmetric-key plaintext=shut-packet]
  ^-  @
  ::
  (en:crub:crypto symmetric-key (jam plaintext))
::  +decrypt: decrypt packet content to a $shut-packet or die
::
++  decrypt
  |=  [=symmetric-key ciphertext=@]
  ^-  shut-packet
  ::
  ;;  shut-packet
  %-  cue
  %-  need
  (de:crub:crypto symmetric-key ciphertext)
::  +encode-packet: serialize a packet into a bytestream
::
++  encode-packet
  |=  packet
  ^-  blob
  ::
  =/  sndr-meta  (encode-ship-metadata sndr)
  =/  rcvr-meta  (encode-ship-metadata rcvr)
  ::  body: <<sndr rcvr (jam [origin content])>>
  ::
  ::    The .sndr and .rcvr ship addresses are encoded with fixed
  ::    lengths specified by the packet header. They live outside
  ::    the jammed-data section to simplify packet filtering in the
  ::    interpreter.
  ::
  =/  body=@
    ;:  mix
      sndr
      (lsh 3 size.sndr-meta rcvr)
      (lsh 3 (add size.sndr-meta size.rcvr-meta) (jam [origin content]))
    ==
  ::  header: 32-bit header assembled from bitstreams of fields
  ::
  ::    <<version checksum sndr-rank rcvr-rank encryption-type unused>>
  ::    4 bits at the end of the header are unused.
  ::
  =/  header=@
    %+  can  0
    :~  [3 protocol-version]
        [20 (mug body)]
        [2 rank.sndr-meta]
        [2 rank.rcvr-meta]
        [5 ?:(encrypted %0 %1)]
    ==
  ::  result is <<header body>>
  ::
  (mix header (lsh 5 1 body))
::  +decode-packet: deserialize packet from bytestream or crash
::
++  decode-packet
  |=  =blob
  ^-  packet
  ::  first 32 (2^5) bits are header; the rest is body
  ::
  =/  header  (end 5 1 blob)
  =/  body    (rsh 5 1 blob)
  ::
  =/  version    (end 0 3 header)
  =/  checksum   (cut 0 [3 20] header)
  =/  sndr-size  (decode-ship-size (cut 0 [23 2] header))
  =/  rcvr-size  (decode-ship-size (cut 0 [25 2] header))
  =/  encrypted  ?+((cut 0 [27 5] header) !! %0 %.y, %1 %.n)
  ::
  =/  =dyad
    :-  sndr=(end 3 sndr-size body)
    rcvr=(cut 3 [sndr-size rcvr-size] body)
  ::
  ?.  =(protocol-version version)
    ~|  %ames-protocol^version^dyad  !!
  ?.  =(checksum (end 0 20 (mug body)))
    ~|  %ames-checksum^dyad  !!
  ::
  =+  ~|  %ames-invalid-packet
      ;;  [origin=(unit lane) content=*]
      ~|  %ames-invalid-noun
      %-  cue
      (rsh 3 (add rcvr-size sndr-size) body)
  ::
  [dyad encrypted origin content]
::  +decode-ship-size: decode a 2-bit ship type specifier into a byte width
::
::    Type 0: galaxy or star -- 2 bytes
::    Type 1: planet         -- 4 bytes
::    Type 2: moon           -- 8 bytes
::    Type 3: comet          -- 16 bytes
::
++  decode-ship-size
  |=  rank=@
  ^-  @
  ::
  ?+  rank  !!
    %0  2
    %1  4
    %2  8
    %3  16
  ==
::  +encode-ship-metadata: produce size (in bytes) and address rank for .ship
::
::    0: galaxy or star
::    1: planet
::    2: moon
::    3: comet
::
++  encode-ship-metadata
  |=  =ship
  ^-  [size=@ =rank]
  ::
  =/  size=@  (met 3 ship)
  ::
  ?:  (lte size 2)  [2 %0]
  ?:  (lte size 4)  [4 %1]
  ?:  (lte size 8)  [8 %2]
  [16 %3]
--
