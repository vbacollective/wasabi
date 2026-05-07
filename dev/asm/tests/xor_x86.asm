bits 32
global xor_buffer

; CallWindowProcW signature (stdcall):
; [ebp+8]  = Buffer pointer (P1)
; [ebp+12] = Length in bytes (P2)
; [ebp+16] = XOR Key (P3)
; [ebp+20] = ignored

xor_buffer:
    push ebp
    mov ebp, esp
    push ebx           ; Save EBX

    mov edx, [ebp+8]   ; EDX = Buffer ptr
    mov ecx, [ebp+12]  ; ECX = Length
    mov ebx, [ebp+16]  ; EBX = XOR Key

    test ecx, ecx      ; Check if length is 0
    jz .done

.loop:
    mov al, byte [edx] ; Read byte
    xor al, bl         ; XOR with key (lowest byte of EBX)
    mov byte [edx], al ; Write byte back
    
    inc edx            ; Next byte
    dec ecx            ; Decrease counter
    jnz .loop          ; Jump if not zero

.done:
    mov eax, [ebp+8]   ; Return the original buffer pointer

    pop ebx            ; Restore EBX
    pop ebp
    ret 16             ; Clean up stack
