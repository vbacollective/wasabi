bits 64
global safe_thunk_x64

; CallWindowProcW/WndProc signature (x64):
; RCX = hWnd, RDX = uMsg, R8 = wParam, R9 = lParam
safe_thunk_x64:
    ; --- PROLOGUE & SAVE STATE ---
    push rbp
    mov rbp, rsp
    push rcx                        ; Save hWnd
    push rdx                        ; Save uMsg
    push r8                         ; Save wParam
    push r9                         ; Save lParam
    sub rsp, 32                     ; Allocate 32 bytes for shadow space (x64 ABI requirement for API calls)

    ; --- 1. HEARTBEAT FLAG CHECK (m_AppIsAlive) ---
    mov rax, 0x1122334455667788     ; [OFFSET 16] Pointer to m_AppIsAlive variable
    mov eax, dword [rax]            ; Read the 32-bit value
    test eax, eax                   ; Is it zero?
    jz .is_dead                     ; If zero (VBA stopped), jump to fallback handler

    ; --- 2. IDE STATE CHECK (EbMode) ---
    mov rax, 0x2233445566778899     ; [OFFSET 32] Pointer to vbe7.dll!EbMode
    test rax, rax                   ; Did we fail to find EbMode? (e.g. running in compiled exe)
    jz .skip_ebmode                 ; If null, skip the IDE check and proceed normally
    
    call rax                        ; Call EbMode()
    cmp eax, 1                      ; EbMode returns 1 if running normally
    jne .is_dead                    ; If not 1 (paused, break mode, or editing), jump to fallback handler

.skip_ebmode:
    ; --- 3. VBA IS SAFE & RUNNING (Forward to WasabiAsyncWndProc) ---
    add rsp, 32                     ; Deallocate shadow space
    pop r9                          ; Restore original lParam
    pop r8                          ; Restore original wParam
    pop rdx                         ; Restore original uMsg
    pop rcx                         ; Restore original hWnd
    pop rbp
    
    mov rax, 0x33445566778899AA     ; [OFFSET 65] Pointer to WasabiAsyncWndProc
    jmp rax                         ; Jump (Tail Call) to VBA handler

.is_dead:
    ; --- 4. VBA IS DEAD/PAUSED (Forward to Default Windows Handler) ---
    add rsp, 32                     ; Deallocate shadow space
    pop r9                          ; Restore original lParam
    pop r8                          ; Restore original wParam
    pop rdx                         ; Restore original uMsg
    pop rcx                         ; Restore original hWnd
    pop rbp
    
    mov rax, 0x445566778899AABB     ; [OFFSET 88] Pointer to user32.DefWindowProcW
    jmp rax                         ; Safe jump to Windows to discard the message
