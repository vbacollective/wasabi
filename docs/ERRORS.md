# Error Reference

This document describes every error code in the `WasabiError` enumeration, including what triggers each error, what the associated system codes mean, and how to diagnose and resolve common failures.

## Table of Contents

- [Reading Wasabi Errors](#reading-wasabi-errors)
- [Error Pattern](#error-pattern)
- [Complete Error Reference](#complete-error-reference)
  - [ERR_NONE (0)](#err_none-0)
  - [ERR_WSA_STARTUP_FAILED (1)](#err_wsa_startup_failed-1)
  - [ERR_SOCKET_CREATE_FAILED (2)](#err_socket_create_failed-2)
  - [ERR_DNS_RESOLVE_FAILED (3)](#err_dns_resolve_failed-3)
  - [ERR_CONNECT_FAILED (4)](#err_connect_failed-4)
  - [ERR_TLS_ACQUIRE_CREDS_FAILED (5)](#err_tls_acquire_creds_failed-5)
  - [ERR_TLS_HANDSHAKE_FAILED (6)](#err_tls_handshake_failed-6)
  - [ERR_TLS_HANDSHAKE_TIMEOUT (7)](#err_tls_handshake_timeout-7)
  - [ERR_WEBSOCKET_HANDSHAKE_FAILED (8)](#err_websocket_handshake_failed-8)
  - [ERR_WEBSOCKET_HANDSHAKE_TIMEOUT (9)](#err_websocket_handshake_timeout-9)
  - [ERR_SEND_FAILED (10)](#err_send_failed-10)
  - [ERR_RECV_FAILED (11)](#err_recv_failed-11)
  - [ERR_NOT_CONNECTED (12)](#err_not_connected-12)
  - [ERR_ALREADY_CONNECTED (13)](#err_already_connected-13)
  - [ERR_TLS_ENCRYPT_FAILED (14)](#err_tls_encrypt_failed-14)
  - [ERR_TLS_DECRYPT_FAILED (15)](#err_tls_decrypt_failed-15)
  - [ERR_INVALID_URL (16)](#err_invalid_url-16)
  - [ERR_HANDSHAKE_REJECTED (17)](#err_handshake_rejected-17)
  - [ERR_CONNECTION_LOST (18)](#err_connection_lost-18)
  - [ERR_INVALID_HANDLE (19)](#err_invalid_handle-19)
  - [ERR_MAX_CONNECTIONS (20)](#err_max_connections-20)
  - [ERR_PROXY_CONNECT_FAILED (21)](#err_proxy_connect_failed-21)
  - [ERR_PROXY_AUTH_FAILED (22)](#err_proxy_auth_failed-22)
  - [ERR_PROXY_TUNNEL_FAILED (23)](#err_proxy_tunnel_failed-23)
  - [ERR_INACTIVITY_TIMEOUT (24)](#err_inactivity_timeout-24)
  - [ERR_CERT_LOAD_FAILED (25)](#err_cert_load_failed-25)
  - [ERR_CERT_VALIDATE_FAILED (26)](#err_cert_validate_failed-26)
  - [ERR_FRAGMENT_OVERFLOW (27)](#err_fragment_overflow-27)
  - [ERR_TLS_RENEGOTIATE (28)](#err_tls_renegotiate-28)
- [Quick Diagnostic Checklist](#quick-diagnostic-checklist)
- [Common WSA Error Codes](#common-wsa-error-codes)
- [Common SSPI Error Codes](#common-sspi-error-codes)

## Reading Wasabi Errors

Wasabi exposes three levels of error information per connection.

```vb
Dim errType As WasabiError
Dim sysCode As Long
Dim details As String

errType = WebSocketGetLastError(handle)
sysCode = WebSocketGetLastErrorCode(handle)
details = WebSocketGetTechnicalDetails(handle)

Debug.Print "Error:", errType
Debug.Print "System code:", sysCode
Debug.Print "Details:", details
```

`errType` is the high-level Wasabi error category and tells you what failed. `sysCode` is the raw code from the underlying system call: a WSA error code for Winsock failures, an SSPI/HRESULT status for TLS failures, or zero on success. `details` is a human-readable string describing the specific failure, including the function name and numeric code, and is the most useful field for debugging.

> [!TIP]
> Always log all three values when diagnosing connection issues. The `WebSocketGetErrorDescription` function combines them into a single diagnostic string.

## Error Pattern

A typical error handling pattern looks like this:

```vb
Sub ConnectSafely()
    Dim h As Long

    If Not WebSocketConnect("wss://echo.websocket.org", h) Then
        Select Case WebSocketGetLastError(h)
            Case ERR_DNS_RESOLVE_FAILED
                Debug.Print "Cannot resolve hostname"
            Case ERR_CONNECT_FAILED
                Debug.Print "Server unreachable"
            Case ERR_TLS_HANDSHAKE_FAILED
                Debug.Print "TLS negotiation failed"
            Case ERR_HANDSHAKE_REJECTED
                Debug.Print "Server rejected WebSocket upgrade"
            Case ERR_PROXY_AUTH_FAILED
                Debug.Print "Proxy credentials rejected"
            Case ERR_MAX_CONNECTIONS
                Debug.Print "Connection pool full"
            Case Else
                Debug.Print "Unexpected error:", WebSocketGetLastError(h)
        End Select

        Debug.Print "System code:", WebSocketGetLastErrorCode(h)
        Debug.Print "Details:", WebSocketGetTechnicalDetails(h)
        Exit Sub
    End If

    Debug.Print "Connected successfully"
End Sub
```

> [!NOTE]
> Errors that occur inside registered extensions (middleware, protocol handler, or compression handler) are not automatically propagated to the `WasabiError` system. Each extension is responsible for its own error handling. The engine only reports errors from its own internal operations.

## Complete Error Reference

### ERR_NONE (0)

No error occurred. The operation completed successfully.

### ERR_WSA_STARTUP_FAILED (1)

**What happened:** `WSAStartup` returned a non-zero value. The Winsock subsystem could not be initialized.

**Common causes:** corrupted Winsock installation, or antivirus and security software blocking socket initialization. Extremely rare on modern Windows.

**What to check:** run `netsh winsock reset` from an elevated command prompt and reboot. Verify no security software is interfering with network initialization.

```vb
' Example diagnostic output
' Error: 1
' System code: 10091
' Details: WSAStartup failed with code 10091
```

### ERR_SOCKET_CREATE_FAILED (2)

**What happened:** `socket()` returned `INVALID_SOCKET`. A TCP socket could not be allocated.

**Common causes:** the system ran out of socket handles, a firewall is blocking socket creation at the OS level, or VPN software is intercepting socket calls.

**What to check:** close unused network connections and verify firewall and VPN configuration. Check `WebSocketGetConnectionCount` to see if the pool is near capacity.

```vb
' Example diagnostic output
' Error: 2
' System code: 10024
' Details: socket() failed with WSA error 10024
```

> [!NOTE]
> WSA error 10024 is `WSAEMFILE` (too many open sockets).

### ERR_DNS_RESOLVE_FAILED (3)

**What happened:** `getaddrinfo()` could not resolve the hostname to an IP address.

**Common causes:** misspelled hostname, unreachable DNS server, corporate proxy requiring direct IP or a different DNS, or no internet connectivity.

| WSA Code | Name | Meaning |
|:---|:---|:---|
| 11001 | WSAHOST_NOT_FOUND | The hostname does not exist in DNS |
| 11002 | WSATRY_AGAIN | Temporary DNS failure, try again later |
| 11003 | WSANO_RECOVERY | Non-recoverable DNS error |
| 11004 | WSANO_DATA | Hostname exists but has no IP address record |

**What to check:** verify the hostname is spelled correctly, try pinging it from a command prompt, check if a proxy is required for external access, and try using an IP address directly to isolate DNS issues.

```vb
' Example diagnostic output
' Error: 3
' System code: 11001
' Details: getaddrinfo() failed for 'bad.hostname.example' with WSAHOST_NOT_FOUND (11001)
```

> [!TIP]
> Error 11002 (`WSATRY_AGAIN`) is typically transient. Wait a moment and retry.

### ERR_CONNECT_FAILED (4)

**What happened:** the TCP connection could not be established. Either `connect()` failed immediately or `select()` timed out waiting for completion. This includes failures from the Happy Eyeballs dual-stack connection process.

**Common causes:** server is down or not listening on the specified port, a firewall is blocking outbound connections, a proxy is required but not configured, or the port number is wrong.

**What to check:** verify the server is running and accepting connections, try connecting from a browser or telnet, check if a proxy is needed via `WebSocketSetProxy`, and confirm the port (80 for `ws://`, 443 for `wss://`).

```vb
' Example diagnostic output
' Error: 4
' System code: 10060
' Details: Connect failed: WSAETIMEDOUT - Connection timed out
```

> [!NOTE]
> WSA error 10060 is `WSAETIMEDOUT`. WSA error 10061 is `WSAECONNREFUSED` (server actively refused the connection).

### ERR_TLS_ACQUIRE_CREDS_FAILED (5)

**What happened:** `AcquireCredentialsHandle` could not initialize the Schannel security provider.

**Common causes:** Schannel provider disabled or corrupted in the Windows registry, or a system-level security policy is blocking TLS. Extremely rare on properly configured systems.

**What to check:** verify TLS is enabled in Windows Internet Options, check the Windows Event Log for Schannel errors, and ensure the system clock is correct.

```vb
' Example diagnostic output
' Error: 5
' System code: -2146893043
' Details: AcquireCredentialsHandle failed: 0x8009030D
```

### ERR_TLS_HANDSHAKE_FAILED (6)

**What happened:** `InitializeSecurityContext` returned a fatal error during the TLS handshake.

**Common causes:** server does not support TLS 1.2 or 1.3, server requires a cipher suite that Schannel does not offer, server certificate is expired or untrusted, or a network device is intercepting and modifying TLS traffic (SSL inspection).

**What to check:** test the server with `openssl s_client`, verify its supported TLS versions and cipher suites, confirm no corporate SSL inspection proxy is interfering, and check the system clock.

```vb
' Example diagnostic output
' Error: 6
' System code: -2146893018
' Details: TLS handshake failed: 0x80090326
```

> [!WARNING]
> SSPI error `0x80090326` (`SEC_E_ILLEGAL_MESSAGE`) often indicates a middlebox such as a corporate proxy or firewall is intercepting and corrupting TLS traffic.

### ERR_TLS_HANDSHAKE_TIMEOUT (7)

**What happened:** the TLS handshake did not complete within the allowed time or iteration limit (30 rounds).

**Common causes:** server is extremely slow to respond, network latency is very high, server accepted the TCP connection but is not responding to TLS, or a firewall is silently dropping TLS packets.

**What to check:** increase the receive timeout via `WebSocketSetReceiveTimeout`, test connectivity from a browser, and verify the server is not behind a load balancer that accepted TCP but is not routing TLS.

```vb
' Example diagnostic output
' Error: 7
' System code: 0
' Details: TLS handshake timed out with api.example.com
```

### ERR_WEBSOCKET_HANDSHAKE_FAILED (8)

**What happened:** Wasabi could not send or receive the HTTP upgrade request that initiates the WebSocket connection.

**Common causes:** TLS was established but the HTTP request failed to send, server closed the connection before responding, or a network interruption occurred between TLS completion and the HTTP exchange.

**What to check:** verify the URL path is correct, check server logs for rejected requests, and ensure custom headers are not malformed.

```vb
' Example diagnostic output
' Error: 8
' System code: 10054
' Details: recv() WS handshake failed: WSAECONNRESET - Connection reset by peer
```

> [!NOTE]
> WSA error 10054 is `WSAECONNRESET` (connection reset by peer).

### ERR_WEBSOCKET_HANDSHAKE_TIMEOUT (9)

**What happened:** the server did not respond to the HTTP upgrade request within the timeout period (5 seconds by default).

**Common causes:** server is overloaded, the endpoint does not handle WebSocket, or a proxy or firewall is silently consuming the upgrade request.

**What to check:** verify the URL path supports WebSocket, increase the receive timeout, and check if the server requires specific headers or a subprotocol.

```vb
' Example diagnostic output
' Error: 9
' System code: 0
' Details: No WS handshake response within 5s
```

### ERR_SEND_FAILED (10)

**What happened:** a `send()` call returned zero or negative while writing data to the socket.

**Common causes:** server closed the connection unexpectedly, network cable disconnected, or VPN dropped.

**What to check:** check `WebSocketIsConnected` before sending, enable auto-reconnect for resilient applications, and log the technical details for the specific WSA error.

```vb
' Example diagnostic output
' Error: 10
' System code: 10054
' Details: send() failed: WSAECONNRESET - Connection reset by peer
```

### ERR_RECV_FAILED (11)

**What happened:** a `recv()` call returned a negative value.

**Common causes:** same as `ERR_SEND_FAILED`. The server may have forcibly closed the connection or hit a connection duration limit.

**What to check:** same diagnostics as send failure. Check if the server enforces connection duration limits.

### ERR_NOT_CONNECTED (12)

**What happened:** a send or receive operation was attempted on a handle that is not currently connected.

**Common causes:** connection was never established, connection was already closed or lost, or the wrong handle was passed.

**What to check:** verify the return value of `WebSocketConnect` before sending, call `WebSocketIsConnected` before each send in long-running loops, and confirm you are using the correct handle.

```vb
' Safe send pattern
If WebSocketIsConnected(h) Then
    WebSocketSend "data", h
Else
    Debug.Print "Not connected"
End If
```

### ERR_ALREADY_CONNECTED (13)

Reserved for future use.

### ERR_TLS_ENCRYPT_FAILED (14)

**What happened:** `EncryptMessage` returned a non-zero SSPI status. The outgoing data could not be encrypted.

**Common causes:** TLS context was invalidated, internal state corruption after a partial send. Extremely rare in normal operation.

**What to check:** disconnect and reconnect. Log the SSPI error code from `WebSocketGetLastErrorCode`.

### ERR_TLS_DECRYPT_FAILED (15)

**What happened:** `DecryptMessage` returned a fatal error other than `SEC_I_RENEGOTIATE` (which is handled separately as `ERR_TLS_RENEGOTIATE`).

**Common causes:** corrupted TLS record received, network device modifying encrypted traffic, or internal SSPI failure.

**What to check:** disconnect and reconnect. Check for SSL inspection proxies on the network.

### ERR_INVALID_URL (16)

**What happened:** the URL string could not be parsed by `ParseURL`.

**Common causes:** URL does not start with `ws://` or `wss://`, empty URL string, missing hostname, port number out of range (must be 1-65535), or non-numeric characters in the port field.

```vb
' Valid URLs
WebSocketConnect "ws://localhost/chat"
WebSocketConnect "wss://api.example.com/ws"
WebSocketConnect "wss://api.example.com:8443/stream"

' Invalid URLs
WebSocketConnect "http://example.com"       ' wrong scheme
WebSocketConnect "wss://"                   ' missing host
WebSocketConnect "wss://host:abc/path"      ' non-numeric port
WebSocketConnect "wss://host:99999/path"    ' port out of range
```

### ERR_HANDSHAKE_REJECTED (17)

**What happened:** the server responded with a status code other than 101, or the `Sec-WebSocket-Accept` header did not match the expected SHA-1 hash.

**Common causes:** server returned 403 (forbidden) or 401 (unauthorized), 404 (wrong path), the endpoint does not support WebSocket, authentication headers are missing, or a load balancer or CDN is intercepting the upgrade request.

**What to check:** verify the URL path is a WebSocket endpoint, add authentication headers via `WebSocketAddHeader` if required, read the technical details for the server's actual response line, and test the endpoint with a browser-based WebSocket client.

```vb
' Example diagnostic output
' Error: 17
' System code: 0
' Details: WebSocket upgrade rejected. Server response: HTTP/1.1 403 Forbidden
```

> [!TIP]
> The technical details string includes the server's HTTP status line, which is often sufficient to diagnose the issue without external tools.

### ERR_CONNECTION_LOST (18)

**What happened:** the connection was lost during normal operation. This can be triggered by `recv()` returning zero (clean server close), a failed `ioctlsocket` call, or an oversized frame being received.

**Common causes:** server closed the connection normally, network interruption, server sent a frame larger than the configured buffer size, or the idle connection timed out on the server side.

**What to check:** enable auto-reconnect for resilient applications, verify whether the server enforces idle timeouts, use `WebSocketSetPingInterval` to keep the connection alive, and if the error mentions an oversized frame, increase the buffer size via `WebSocketSetBufferSizes`.

```vb
' Resilient connection pattern
WebSocketSetAutoReconnect True, 10, 2000, h
WebSocketSetPingInterval 25000, h
```

### ERR_INVALID_HANDLE (19)

**What happened:** the handle passed to a function is outside the valid range (0 to 63).

**Common causes:** using an uninitialized handle variable, using a handle after it was cleaned up, or an arithmetic error producing an out-of-range value.

**What to check:** verify that `WebSocketConnect` returned `True` before using the handle, and do not reuse handles after calling `WebSocketDisconnect`.

### ERR_MAX_CONNECTIONS (20)

**What happened:** all 64 slots in the connection pool are occupied. `AllocConnection` found no free slot.

**Common causes:** opening connections without closing them, leaked handles from failed error handling paths, or genuinely needing more than 64 simultaneous connections.

**What to check:** call `WebSocketDisconnect` on handles you no longer need, monitor pool usage with `WebSocketGetConnectionCount`, and audit active connections with `WebSocketGetAllHandles`.

```vb
' Audit active connections
Dim handles() As Long
Dim i As Long

handles = WebSocketGetAllHandles()

Debug.Print "Active connections:", WebSocketGetConnectionCount()
For i = LBound(handles) To UBound(handles)
    Debug.Print "Handle", handles(i), _
                "Host:", WebSocketGetHost(handles(i)), _
                "Uptime:", WebSocketGetUptime(handles(i)), "s"
Next i
```

### ERR_PROXY_CONNECT_FAILED (21)

**What happened:** the HTTP CONNECT (or SOCKS5 greeting) to the proxy server failed. Either `send()` to the proxy failed, the proxy did not respond, or the response could not be read.

**Common causes:** wrong proxy host or port, proxy server is down, or a firewall is blocking the proxy port.

**What to check:** verify proxy host and port with `WebSocketGetProxyInfo`, test proxy connectivity independently, and check if the proxy requires authentication.

### ERR_PROXY_AUTH_FAILED (22)

**What happened:** the proxy returned HTTP 407 (Proxy Authentication Required) or the SOCKS5 authentication handshake failed.

**Common causes:** wrong proxy username or password, proxy requires NTLM/Kerberos but only Basic was attempted, or proxy credentials have expired.

**What to check:** verify credentials in `WebSocketSetProxy`. For HTTP corporate proxies that support Windows Integrated Authentication, enable NTLM via `WebSocketSetProxyNtlm True`. Confirm credentials with your network administrator.

> [!NOTE]
> Wasabi supports HTTP Basic and NTLM/Kerberos (via `WebSocketSetProxyNtlm`) for HTTP proxies. For SOCKS5, only username/password authentication is available.

### ERR_PROXY_TUNNEL_FAILED (23)

**What happened:** the proxy accepted the connection but returned a non-200 status for the CONNECT tunnel request.

**Common causes:** proxy policy blocks the target host or port, proxy does not allow CONNECT to non-443 ports, or the target hostname is blacklisted.

**What to check:** verify the target host and port are allowed through the proxy, read the technical details for the proxy's HTTP status line, and contact your network administrator if WebSocket traffic is being blocked.

```vb
' Example diagnostic output
' Error: 23
' System code: 0
' Details: Proxy CONNECT rejected: HTTP/1.1 403 Forbidden
```

### ERR_INACTIVITY_TIMEOUT (24)

**What happened:** no data was received from the server within the configured inactivity timeout period (`InactivityTimeoutMs`).

**Common causes:** server stopped sending data, a network interruption that did not fully close the socket, the inactivity timeout is set too short for the application protocol, or the server expects periodic client messages to keep the session alive.

**What to check:** increase the timeout via `WebSocketSetInactivityTimeout`, enable heartbeat via `WebSocketSetPingInterval`, verify whether the server requires periodic client messages, and enable auto-reconnect for automatic recovery.

```vb
' Recommended resilient configuration
WebSocketSetInactivityTimeout 60000, h
WebSocketSetPingInterval 25000, h
WebSocketSetAutoReconnect True, 5, 2000, h
```

> [!TIP]
> Combining `WebSocketSetInactivityTimeout` with `WebSocketSetPingInterval` and `WebSocketSetAutoReconnect` creates the most resilient connection configuration available in Wasabi.

### ERR_CERT_LOAD_FAILED (25)

**What happened:** Wasabi failed to load a client certificate from a PFX file or the Windows certificate store. The certificate was configured via `WebSocketSetClientCert` or `WebSocketSetClientCertPfx` but could not be found, imported, or parsed.

**Common causes:** path to the PFX file is incorrect or the file is missing, the PFX file is password-protected with the wrong password, the specified subject or thumbprint does not match any certificate in the store, or the user account lacks permission to read the certificate store or file.

**What to check:** verify the file path and that the PFX file exists, confirm the PFX password is correct, when using `WebSocketSetClientCert` ensure the subject or thumbprint matches a certificate installed in Current User\My, and verify the account has read access.

```vb
' Example diagnostic output
' Error: 25
' System code: 0
' Details: PFX file not found: C:\certs\client.pfx
```

> [!NOTE]
> If client certificate loading fails, Wasabi continues the connection without a client certificate and logs a warning. The server may then reject the TLS handshake if mutual TLS (mTLS) is required.

### ERR_CERT_VALIDATE_FAILED (26)

**What happened:** server certificate validation was enabled via `WebSocketSetCertValidation True` and `CertGetCertificateChain` / `CertVerifyCertificateChainPolicy` returned a failure.

**Common causes:** the server certificate is self-signed or issued by an untrusted CA, the certificate has expired or is not yet valid, the CN does not match the hostname, a required intermediate CA certificate is missing on the client machine, or (if `WebSocketSetRevocationCheck` is enabled) the certificate was revoked or the CRL/OCSP responder is unreachable.

**What to check:** verify the server certificate is trusted by opening the URL in a browser, add the certificate to the Trusted Root store or disable validation for self-signed scenarios, ensure the system clock is correct, and temporarily disable revocation checking to isolate CRL-related failures.

### ERR_FRAGMENT_OVERFLOW (27)

**What happened:** a fragmented WebSocket message grew larger than the configured `FragmentBuffer` size. The connection is closed to prevent memory corruption.

**Common causes:** the server is sending messages larger than the default 256 KB fragment buffer, a sender is streaming continuous continuation frames without a final FIN frame, or the buffer size is too small for the expected message size.

**What to check:** increase the fragment buffer via `WebSocketSetBufferSizes` before connecting, verify the maximum message size the remote API may send, and ensure the sender properly terminates fragmented messages with a FIN frame.

```vb
' Increasing the fragment buffer to 1 MB
WebSocketSetBufferSizes 262144, 1048576, h
```

### ERR_TLS_RENEGOTIATE (28)

**What happened:** `DecryptMessage` returned `SEC_I_RENEGOTIATE`. The server requested a TLS renegotiation after the initial handshake was complete. Wasabi does not support renegotiation and closes the connection.

**Common causes:** the server is configured to require periodic re-authentication, a security policy triggers renegotiation after a certain amount of data is transferred, or an older server renegotiates by default.

**What to check:** disable server-initiated TLS renegotiation if possible, enable auto-reconnect so the connection is re-established automatically, or adjust the server configuration to avoid renegotiation.

> [!NOTE]
> Wasabi intentionally does not implement TLS renegotiation due to the complexity of handling it correctly in a single-threaded VBA environment. Auto-reconnect is the recommended recovery mechanism.

## Quick Diagnostic Checklist

When a connection fails, run through this list in order:

| Step | Check | How |
|:---|:---|:---|
| 1 | Is the URL valid? | Verify scheme, host, port, and path |
| 2 | Can you reach the host? | Ping the hostname from a command prompt |
| 3 | Is DNS resolving? | Try using an IP address instead of hostname |
| 4 | Is a proxy required? | Check with your network administrator |
| 5 | Is TLS the issue? | Try `ws://` instead of `wss://` to isolate |
| 6 | Is the path correct? | Verify the WebSocket endpoint with a browser tool |
| 7 | Are headers required? | Check if the server needs `Authorization` or other headers |
| 8 | What did the server say? | Read `WebSocketGetTechnicalDetails` for the server response |
| 9 | Is the pool full? | Check `WebSocketGetConnectionCount` |
| 10 | Is auto-reconnect working? | Check `WebSocketGetReconnectInfo` |

## Common WSA Error Codes

These are the most frequently encountered Winsock error codes in Wasabi diagnostic output:

| Code | Name | Meaning |
|:---|:---|:---|
| 10035 | WSAEWOULDBLOCK | Operation would block (normal for non-blocking sockets) |
| 10038 | WSAENOTSOCK | Socket handle is not valid |
| 10053 | WSAECONNABORTED | Connection aborted by local software |
| 10054 | WSAECONNRESET | Connection reset by remote host |
| 10060 | WSAETIMEDOUT | Connection timed out |
| 10061 | WSAECONNREFUSED | Connection actively refused by target |
| 11001 | WSAHOST_NOT_FOUND | Hostname does not exist |
| 11002 | WSATRY_AGAIN | Temporary DNS failure |
| 11003 | WSANO_RECOVERY | Non-recoverable DNS error |
| 11004 | WSANO_DATA | Hostname valid but no IP address available |

## Common SSPI Error Codes

These are the most frequently encountered Schannel/SSPI error codes in Wasabi diagnostic output:

| Code (hex) | Name | Meaning |
|:---|:---|:---|
| 0x80090300 | SEC_E_INSUFFICIENT_MEMORY | Not enough memory for the security operation |
| 0x80090304 | SEC_E_INTERNAL_ERROR | Internal Schannel error |
| 0x80090305 | SEC_E_NOT_OWNER | Caller does not own the credentials |
| 0x8009030D | SEC_E_UNKNOWN_CREDENTIALS | Credentials not recognized |
| 0x80090311 | SEC_E_NO_AUTHENTICATING_AUTHORITY | No authority could be contacted for authentication |
| 0x80090318 | SEC_E_INCOMPLETE_MESSAGE | Received TLS record is incomplete (internal, handled by Wasabi) |
| 0x80090326 | SEC_E_ILLEGAL_MESSAGE | Received message is corrupted or unexpected |
| 0x00090312 | SEC_I_CONTINUE_NEEDED | Handshake needs more data (internal, handled by Wasabi) |
| 0x00090321 | SEC_I_RENEGOTIATE | Server requested TLS renegotiation (surfaces as `ERR_TLS_RENEGOTIATE`) |

> [!NOTE]
> Errors that occur inside registered extensions (middleware, protocol handler, or compression handler) are not automatically propagated to the `WasabiError` system. Each extension is responsible for its own error handling. The engine only reports errors from its own internal operations.

> [!NOTE]
> In MQTT operations, protocol-level errors such as a CONNACK with a non-zero return code are returned as human-readable strings through `MqttReceive` (e.g., `[CONNACK_ERROR] Code=5 | Erro: Not authorized`). These are not reflected in the `WasabiError` enumeration.
