bits 32
global mem_set

; CallWindowProcW signature (stdcall):
; [ebp+8]  = Destination pointer (P1)
; [ebp+12] = Byte value to fill (P2)
; [ebp+16] = Length in bytes (P3)
; [ebp+20] = ignored

mem_set:
    push ebp
    mov ebp, esp
    push edi           ; Save EDI

    mov edi, [ebp+8]   ; EDI = Destination ptr
    mov eax, [ebp+12]  ; AL  = Byte value
    mov ecx, [ebp+16]  ; ECX = Length

    rep stosb          ; Fill ECX bytes at [EDI] with AL

    mov eax, [ebp+8]   ; Return original destination pointer

    pop edi            ; Restore EDI
    pop ebp
    ret 16             ; Clean up 16 bytes
