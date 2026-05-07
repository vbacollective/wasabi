# Protocol Extensions

Protocol handlers let you intercept WebSocket text and binary messages directly,
bypassing the internal message queue. This is the cleanest way to add a new
application‑layer protocol (MQTT 5, AMQP, custom binary protocol) without
polluting your main VBA loop.

## Required Interface

Create a VBA class that implements the following public methods:

```vb
' MyProtocol.cls

Public Sub OnConnect(ByVal handle As Long)
    ' Called once, immediately after the WebSocket handshake completes.
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    ' Called when the connection closes (normal close, error, or manual disconnect).
End Sub

Public Sub OnTextMessage(ByVal handle As Long, ByVal message As String)
    ' Delivers every received TEXT frame as a UTF‑8 string.
End Sub

Public Sub OnBinaryMessage(ByVal handle As Long, ByRef data() As Byte)
    ' Delivers every received BINARY frame.
End Sub
```

> [!NOTE]
> If you register a protocol handler, the default `WebSocketReceive` / `WebSocketReceiveBinary` queues
> are **bypassed** for that connection – you must consume messages inside your handler.
> This guarantees zero‑copy and full control over the data flow.

## Registration

Register per‑handle with `WasabiUseProtocol`:

```vb
Dim h As Long
If WebSocketConnect("wss://broker.example.com/mqtt", h, , , "mqtt") Then
    Dim myMqtt As New Mqtt5Protocol
    WasabiUseProtocol myMqtt, h
End If
```

You can change the handler at any time; the new handler receives an `OnConnect` callback
if the connection is currently open.

## Lifecycle Example: MQTT 5 Client

Below is a simplified sketch of an MQTT 5 protocol handler. The full version would manage
session state, packet IDs, and publish/subscribe workflows entirely inside the class.

```vb
' Mqtt5Protocol.cls

Private m_Handle As Long
Private m_State As Byte           ' 0 = disconnected, 1 = connecting, 2 = connected

Public Sub OnConnect(ByVal handle As Long)
    m_Handle = handle
    m_State = 1
    ' Send MQTT CONNECT with MQTT 5 properties
    BuildAndSendConnect handle
End Sub

Public Sub OnTextMessage(ByVal handle As Long, ByVal message As String)
    ' Text frames are unusual in MQTT – ignore or log
End Sub

Public Sub OnBinaryMessage(ByVal handle As Long, ByRef data() As Byte)
    ' Parse MQTT packet and dispatch:
    '   – CONNACK -> transition to connected, start subscriptions
    '   – PUBLISH -> call user callback, send PUBACK/PUBREC as needed
    '   – SUBACK / PUBREC / PUBREL -> update inflight tracker
    '   – DISCONNECT -> handle reason codes and metadata
    ParseAndProcess handle, data
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    m_State = 0
End Sub
```

> [!TIP]
> Because your protocol handler runs inside the `ProcessTextFrame`/`ProcessBinaryFrame`
> pipeline, it can call the public Wasabi API (e.g., `WebSocketSendBinary`) directly
> from `OnBinaryMessage` without re‑entering the frame queue.

## Integration with the Engine

- The handler is called **after** all inbound middlewares have run.
- The `handle` parameter always corresponds to the connection that triggered the callback.
- The protocol handler does **not** affect compression – messages arrive already inflated.
