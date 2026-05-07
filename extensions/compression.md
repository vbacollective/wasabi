# Compression Extensions

The Wasabi engine decouples compression from the core module. By registering a
compression handler, you can replace the built‑in `permessage‑deflate` (zlib) with
any algorithm – LZ4, Brotli, Zstandard, or a custom enterprise codec – without
modifying `Wasabi.bas`.

## Required Interface

Your class must implement these methods:

```vb
' MyCompressor.cls

Public Sub OnConnect(ByVal handle As Long)
    ' Called when the connection is ready (after WebSocket handshake).
    ' Can be used to initialise compressor/decompressor state.
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    ' Called before the connection is terminated.
    ' Release any resources, e.g., streaming state.
End Sub

Public Function Deflate(ByRef data() As Byte, _
                        ByVal windowBits As Long, _
                        ByVal contextTakeover As Boolean) As Byte()
    ' Compress the payload.
    ' windowBits: negotiated window size (negative value)
    ' contextTakeover: True if previous compression state should be retained
    ' Returns the compressed byte array (may be empty).
End Function

Public Function Inflate(ByRef data() As Byte, _
                        ByVal windowBits As Long, _
                        ByVal contextTakeover As Boolean) As Byte()
    ' Decompress the payload.
    ' Returns the decompressed byte array.
End Function
```

> [!NOTE]
> The engine calls `Deflate`/`Inflate` only when the WebSocket `permessage‑deflate`
> extension has been successfully negotiated (or when you manually force it for TCP).
> If you do not register any handler, no compression occurs.

## Registration

```vb
Dim myLZ4 As New LZ4Compressor
WasabiUseCompression myLZ4, handle
```

You can register a handler **before or after** connecting. If the connection is already
open, the handler receives an `OnConnect` callback immediately.

## Integration with `permessage‑deflate` Negotiation

To take advantage of automatic compression negotiation, set `DeflateEnabled = True` during
`WebSocketConnect`. The engine will still use your handler instead of the default zlib:

```vb
' Connect with compression negotiation enabled, but supply a custom LZ4 compressor
Dim lz4 As New LZ4Compressor
WebSocketConnect "wss://server/ws", h, True   ' True = negotiate permessage‑deflate
WasabiUseCompression lz4, h
```

The `windowBits` and `contextTakeover` parameters reflect the actual negotiated values,
so your implementation can honour them or ignore them.

## Example: Minimal Zlib‑Free Compressor (Identity)

If you just want to disable compression while keeping the negotiation active (for testing), create a pass‑through compressor:

```vb
' IdentityCompressor.cls

Public Sub OnConnect(ByVal handle As Long): End Sub
Public Sub OnDisconnect(ByVal handle As Long): End Sub

Public Function Deflate(ByRef data() As Byte, _
                        ByVal windowBits As Long, _
                        ByVal contextTakeover As Boolean) As Byte()
    Deflate = data   ' return data unchanged
End Function

Public Function Inflate(ByRef data() As Byte, _
                        ByVal windowBits As Long, _
                        ByVal contextTakeover As Boolean) As Byte()
    Inflate = data
End Function
```

## Example: LZ4 Fast Compression

A production LZ4 handler would look like:

```vb
' LZ4Compressor.cls
Private ctxDeflate As Long    ' LZ4 streaming context
Private ctxInflate As Long

Public Sub OnConnect(ByVal handle As Long)
    ' Allocate LZ4 streaming context (if using HC or streaming)
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    ' Free streaming context
End Sub

Public Function Deflate(ByRef data() As Byte, _
                        ByVal windowBits As Long, _
                        ByVal contextTakeover As Boolean) As Byte()
    ' Use LZ4_compress_fast or similar
    ' Return compressed frame
End Function

Public Function Inflate(ByRef data() As Byte, _
                        ByVal windowBits As Long, _
                        ByVal contextTakeover As Boolean) As Byte()
    ' Use LZ4_decompress_safe
    ' Return decompressed frame
End Function
```

> [!TIP]
> The engine never leaks memory: it calls `OnDisconnect` before releasing the
> connection, giving you a chance to destroy native resources.

## Compression and Middleware Order

Middlewares see **uncompressed** payloads. The processing order for outbound data is:

1. Middleware `OnBeforeSend`
2. Compression handler `Deflate` (if registered and active)
3. WebSocket framing

For inbound data, it is the reverse:

1. WebSocket deframing
2. Compression handler `Inflate`
3. Middleware `OnAfterReceive`
