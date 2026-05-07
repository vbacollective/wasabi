bits 32
global add_numbers

; CallWindowProcW signature (stdcall):
; [ebp+8]  = Number 1 (P1)
; [ebp+12] = Number 2 (P2)
; [ebp+16], [ebp+20] = ignored

add_numbers:
    push ebp           ; Save base pointer
    mov ebp, esp       ; Set stack pointer

    mov eax, [ebp+8]   ; EAX = Number 1
    add eax, [ebp+12]  ; EAX = EAX + Number 2

    pop ebp            ; Restore base pointer
    ret 16             ; Clean up 4 parameters (4 * 4 = 16 bytes) and return
