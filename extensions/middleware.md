# Middleware Extensions

Middlewares are composable objects that allow you to intercept the raw byte arrays
flowing between Wasabi and the network, either before sending or after receiving.
They are the ideal place for logging, encryption, HMAC signing, message filtering,
or injecting custom headers.

## Required Interface

Implement a VBA class with the following four methods:

```vb
' MyMiddleware.cls

Public Sub OnConnect(ByVal handle As Long)
    ' Connection established. Use for initialisation (e.g., key exchange).
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    ' Connection terminated. Clean up any per‑connection state.
End Sub

Public Sub OnBeforeSend(ByVal handle As Long, ByRef data() As Byte)
    ' Outbound data, just before WebSocket framing.
    ' Modify the byte array in place, e.g., encrypt it.
End Sub

Public Sub OnAfterReceive(ByVal handle As Long, ByRef data() As Byte)
    ' Inbound data, immediately after decryption / deframing.
    ' Modify the byte array in place, e.g., decrypt it.
End Sub
```

> [!IMPORTANT]
> The `data()` array is passed **ByRef** – you can resize or replace it entirely.
> The engine will use the modified array for framing (send) or delivery (receive).

## Registration and Ordering

Middleware is registered **per handle** and executed in the order it was added:

```vb
Dim logger As New MyLogger
Dim encryptor As New MyAESEncryptor

WasabiUseMiddleware logger, handle      ' runs first
WasabiUseMiddleware encryptor, handle   ' runs second
```

During a **send** operation, the pipeline runs `OnBeforeSend` in registration order.
During **receive**, the same order is maintained for `OnAfterReceive`.

## Example: Transparent Logging

```vb
' Logger.cls
Public Sub OnConnect(ByVal handle As Long)
    Debug.Print "[CONNECT] handle=" & handle
End Sub

Public Sub OnDisconnect(ByVal handle As Long)
    Debug.Print "[DISCONNECT] handle=" & handle
End Sub

Public Sub OnBeforeSend(ByVal handle As Long, ByRef data() As Byte)
    Dim ub As Long
    ub = UBound(data) - LBound(data) + 1
    Debug.Print "[OUT] handle=" & handle & ", " & ub & " bytes"
End Sub

Public Sub OnAfterReceive(ByVal handle As Long, ByRef data() As Byte)
    Dim ub As Long
    ub = UBound(data) - LBound(data) + 1
    Debug.Print "[IN]  handle=" & handle & ", " & ub & " bytes"
End Sub
```

Usage:

```vb
Dim h As Long
Dim log As New Logger
WasabiUseMiddleware log, h

If WebSocketConnect("wss://example.com/ws", h) Then
    WebSocketSend "Hello", h
    ' … later …
    WebSocketDisconnect h
End If
```

## Example: End‑to‑End Encryption with AES‑256

A symmetric encryption middleware can encrypt everything on send and decrypt on receive,
effectively creating an application‑layer secure channel inside the TLS tunnel.

```vb
' AESEncryptor.cls
Private key() As Byte     ' pre‑shared or negotiated via OnConnect

Public Sub OnConnect(ByVal handle As Long)
    ' Could perform a Diffie‑Hellman key exchange via WebSocketSendBinary
End Sub

Public Sub OnBeforeSend(ByVal handle As Long, ByRef data() As Byte)
    ' Encrypt the entire byte array with AES‑CBC
    data = AES_Encrypt(data, key)
End Sub

Public Sub OnAfterReceive(ByVal handle As Long, ByRef data() As Byte)
    ' Decrypt the payload
    data = AES_Decrypt(data, key)
End Sub

' … OnDisconnect omitted
```

With this approach, the WebSocket frame itself is still transported inside TLS,
but the payload is additionally encrypted, protecting it even if the TLS session
were compromised.

## Middleware and Compression / Protocols

- Middlewares see **uncompressed** data: `OnBeforeSend` runs *before* compression,
  and `OnAfterReceive` runs *after* decompression.
- If a protocol handler is registered, middlewares still run – they see the raw
  byte arrays that become the WebSocket message payload.
