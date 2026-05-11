# Wasabi Zlib Extension

Compression handler extension for [Wasabi](https://github.com/uesleibros/wasabi). Implements permessage-deflate ([RFC 7692](https://datatracker.ietf.org/doc/html/rfc7692)) via `zlib1.dll`, enabling compressed WebSocket frames with no external COM dependencies.

## Requirements

- Wasabi v2.3.7-beta or later
- `zlib1.dll` accessible on the system PATH or in the same folder as the host application (Excel, Access, etc.)
  - A pre-built Windows binary is available at [zlib.net](https://zlib.net/), or you can grab it from [GnuWin32](https://gnuwin32.sourceforge.net/packages/zlib.htm)
- VBA7 (Office 2010+) or VB6

## Installation

1. Copy `ExtWasabiZlib.cls` into your VBA project (File > Import File, or drag into the VBE project tree)
2. Make sure `zlib1.dll` is reachable. Placing it next to your `.xlsm` / `.accdb` file works reliably

## Usage

### Basic setup (synchronous polling mode)

The call order matters. You connect first with `DeflateEnabled:=True`, and only after the connection is open do you attach the compression handler via `WasabiUseCompression`.

```vba
Dim zlib As New ExtWasabiZlib
Dim handle As Long

' Connect with deflate negotiation enabled
If Wasabi.WebSocketConnect("wss://echo.websocket.org", handle, DeflateEnabled:=True) Then

    ' Attach the compression handler after the connection is open
    Wasabi.WasabiUseCompression zlib, handle

    ' Send and receive as usual, compression is now transparent
    Wasabi.WebSocketSendText "hello compressed world", handle

    Dim msg As String
    msg = Wasabi.WebSocketReceiveText(handle)
    Debug.Print msg

    Wasabi.WebSocketDisconnect handle
Else
    Debug.Print Wasabi.WasabiGetErrorDescription(handle)
End If
```

### Async mode

The order is the same: connect first, attach the handler after.

```vba
Dim zlib As New ExtWasabiZlib
Dim handler As New cMyAsyncHandler
Dim handle As Long

If Wasabi.WebSocketConnect("wss://stream.example.com/ws", handle, DeflateEnabled:=True) Then
    Wasabi.WasabiUseCompression zlib, handle
    Wasabi.WasabiUseAsync handler, handle
End If
```

### Setting compression level

Call `SetCompressionLevel` before the connection is established. The default level (`-1`) lets zlib pick a balanced setting. Valid values are `1` (fastest) through `9` (best compression).

```vba
Dim zlib As New ExtWasabiZlib
zlib.SetCompressionLevel 6   ' good balance between speed and size

Dim handle As Long
Wasabi.WebSocketConnect "wss://...", handle, DeflateEnabled:=True
Wasabi.WasabiUseCompression zlib, handle
```

### Checking if the server actually negotiated compression

Not all servers support permessage-deflate. After connecting you can verify whether it was actually agreed on:

```vba
If Wasabi.WebSocketGetDeflateEnabled(handle) Then
    Debug.Print "Compression active"
Else
    Debug.Print "Server did not negotiate deflate, running uncompressed"
End If
```

If the server declined, Wasabi falls back to uncompressed frames automatically. The compression handler stays attached but sits idle.

### Checking for errors

```vba
Dim errMsg As String
errMsg = zlib.GetLastError()
If Len(errMsg) > 0 Then
    Debug.Print "zlib error: " & errMsg
End If
```

## How it works

When Wasabi negotiates `permessage-deflate` during the WebSocket handshake, it calls `CompressionHandler.Deflate(...)` before sending each frame and `CompressionHandler.Inflate(...)` when a compressed frame arrives. `extWasabiZlib` implements both using raw zlib deflate with negative window bits (raw deflate, no zlib or gzip header), which is exactly what RFC 7692 requires.

The trailing `00 00 FF FF` sync marker that zlib appends at the end of each `Z_SYNC_FLUSH` is stripped on the outbound side and re-appended on the inbound side before inflating, as the spec mandates.

Context takeover (`DeflateContextTakeover`) is controlled by whatever the server negotiates during the handshake. When it's enabled, the deflate and inflate streams are reused across frames for better compression ratios. When it's disabled, the streams are reset per frame.

## Notes

The `zlib1.dll` version string is hardcoded to `"1.2.11"` in the Declare statements. This works with any 1.2.x build. If you're using a newer build (1.3.x) and see initialization failures, update the `ZLIB_VERSION` constant at the top of the class to match.

zlib1.dll must match the bitness of your Office installation: 32-bit Office needs a 32-bit DLL, 64-bit Office needs a 64-bit DLL.
