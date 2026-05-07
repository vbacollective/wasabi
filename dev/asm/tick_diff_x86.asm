bits 32
global tick_diff

; CallWindowProcW signature (stdcall):
; [esp+4]  = startTick (P1)
; [esp+8]  = endTick   (P2)
; [esp+12] = unused    (P3)
; [esp+16] = unused    (P4)
; Returns tick difference in EAX

tick_diff:
    ; No stack frame (ebp) for maximum performance.
    ; We read the arguments directly from the stack (esp).
    
    mov eax, [esp+8]   ; EAX = endTick (P2)
    sub eax, [esp+4]   ; EAX = EAX - startTick (P1)
    
    ret 16             ; Clean up the 4 stdcall arguments (4 * 4 = 16 bytes)
