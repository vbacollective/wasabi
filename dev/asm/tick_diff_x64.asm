bits 64
global tick_diff

; CallWindowProcW signature (x64):
; RCX = startTick (P1)
; RDX = endTick   (P2)
; R8  = unused    (P3)
; R9  = unused    (P4)
; Returns tick difference in RAX (zero-extended from EAX)

tick_diff:
    ; No need to save registers (push/pop) here
    ; because we don't alter any non-volatile registers.
    
    mov eax, edx       ; EAX = endTick (P2)
    sub eax, ecx       ; EAX = EAX - startTick (P1)
    
    ret                ; Return EAX. CPU handles the unsigned 32-bit wraparound naturally.
