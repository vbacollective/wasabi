bits 32
global safe_thunk_x86

; stdcall: args on stack, callee cleans (ret 0x10).
; WndProc args live above our saved regs and are untouched throughout.

safe_thunk_x86:
    ; --- SAVE VOLATILE REGISTERS ---
    push eax
    push ecx
    push edx

    ; --- 1. HEARTBEAT FLAG CHECK (m_AppIsAlive) ---
    mov eax, 0x11223344             ; [OFFSET 4] Pointer to m_AppIsAlive
    mov eax, dword [eax]
    test eax, eax
    jz .is_dead

    ; --- 2. IDE STATE CHECK (EbMode) ---
    mov eax, 0x22334455             ; [OFFSET 15] Pointer to vba6.dll!EbMode
    test eax, eax
    jz .skip_ebmode

    call eax                        ; EbMode() — returns 1 if running normally
    cmp eax, 1
    jne .is_dead                    ; Break/edit mode → fallback

.skip_ebmode:
    ; --- 3. DISPATCH CELL CHECK (m_ptrDispatch) ---
    mov eax, 0x33445566             ; [OFFSET 31] Pointer to m_ptrDispatch cell
    mov eax, dword [eax]            ; Dereference: read actual fn ptr from cell
    test eax, eax
    jz .is_dead                     ; Cell zeroed (recompile in progress) → fallback

    ; --- 4. TAIL-CALL WasabiAsyncWndProc ---
    ; Restore volatile regs, then jump through the cell (indirect).
    ; Using jmp [imm32] avoids needing a free register after the pops.
    pop edx
    pop ecx
    pop eax
    jmp dword [0x44556677]          ; [OFFSET 46] jmp [&m_ptrDispatch] — indirect tail-call

.is_dead:
    ; --- 5. FALLBACK → DefWindowProcW ---
    pop edx
    pop ecx
    pop eax
    mov eax, 0x55667788             ; [OFFSET 54] Pointer to user32.DefWindowProcW
    jmp eax
