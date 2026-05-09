# Middleware Extensions

Middlewares are composable objects that intercept the raw byte arrays flowing between
Wasabi and the network, either before sending or after receiving. They are the right
place for logging, encryption, HMAC signing, message filtering, or any transformation
that must be transparent to the rest of the application.

## Required interface

Implement a VBA class with the following four methods:

```vb
' MyMiddleware.cls

Public Sub OnConnect(ByVal handle As Long)
    ' Connection established. Use for initialisation, e.g. key exchange.
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    ' Connection terminated. Clean up any per-connection state.
End Sub

Public Sub OnBeforeSend(ByVal handle As Long, ByRef data() As Byte)
    ' Outbound data, just before WebSocket framing.
    ' Modify the byte array in place, e.g. encrypt it.
End Sub

Public Sub OnAfterReceive(ByVal handle As Long, ByRef data() As Byte)
    ' Inbound data, immediately after decryption and deframing.
    ' Modify the byte array in place, e.g. decrypt it.
End Sub
```

> [!IMPORTANT]
> `data()` is passed `ByRef`. You can resize or replace it entirely, and the engine
> will use the modified array for framing (on send) or delivery (on receive).

## Registration and ordering

Middleware is registered per handle and executed in the order it was added:

```vb
Dim logger    As New MyLogger
Dim encryptor As New MyAESEncryptor

WasabiUseMiddleware logger,    handle   ' runs first
WasabiUseMiddleware encryptor, handle   ' runs second
```

On send, the pipeline calls `OnBeforeSend` in registration order. On receive, the same
order is maintained for `OnAfterReceive`.

## Example: transparent logging

```vb
' Logger.cls

Public Sub OnConnect(ByVal handle As Long)
    Debug.Print "[CONNECT] handle=" & handle
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    Debug.Print "[DISCONNECT] handle=" & handle
End Sub

Public Sub OnBeforeSend(ByVal handle As Long, ByRef data() As Byte)
    Debug.Print "[OUT] handle=" & handle & ", " & (UBound(data) - LBound(data) + 1) & " bytes"
End Sub

Public Sub OnAfterReceive(ByVal handle As Long, ByRef data() As Byte)
    Debug.Print "[IN]  handle=" & handle & ", " & (UBound(data) - LBound(data) + 1) & " bytes"
End Sub
```

Usage:

```vb
Dim h   As Long
Dim log As New Logger

WasabiUseMiddleware log, h

If WebSocketConnect("wss://example.com/ws", h) Then
    WebSocketSend "Hello", h
    WebSocketDisconnect h
End If
```

## Example: end-to-end encryption with AES-256

A symmetric encryption middleware encrypts everything on send and decrypts on receive,
creating an application-layer secure channel inside the existing TLS tunnel.

```vb
' AESEncryptor.cls

Private key() As Byte   ' pre-shared or negotiated during OnConnect

Public Sub OnConnect(ByVal handle As Long)
    ' Could perform a Diffie-Hellman key exchange via WebSocketSendBinary.
End Sub

Public Sub OnBeforeSend(ByVal handle As Long, ByRef data() As Byte)
    data = AES_Encrypt(data, key)
End Sub

Public Sub OnAfterReceive(ByVal handle As Long, ByRef data() As Byte)
    data = AES_Decrypt(data, key)
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    Erase key
End Sub
```

With this approach the WebSocket frame is still transported inside TLS, but the payload
is additionally encrypted, protecting it even if the TLS session were compromised.

## Interaction with compression and protocol handlers

Middlewares always see uncompressed data. `OnBeforeSend` runs before the compression
handler's `Deflate`, and `OnAfterReceive` runs after `Inflate`. If a protocol handler
is also registered, middlewares still run and see the raw byte arrays that will become
the WebSocket message payload.
