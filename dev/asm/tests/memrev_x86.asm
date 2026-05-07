bits 32
global mem_reverse

; CallWindowProcW signature (stdcall):
; [ebp+8]  = Buffer pointer (P1)
; [ebp+12] = Length in bytes (P2)
; [ebp+16], [ebp+20] = ignored

mem_reverse:
    push ebp
    mov ebp, esp
    push esi
    push edi

    mov esi, [ebp+8]   ; ESI = Start pointer (Left)
    mov edi, [ebp+8]   ; EDI = End pointer (Right)
    mov ecx, [ebp+12]  ; ECX = Length

    cmp ecx, 1         ; If length <= 1, exit
    jle .done

    add edi, ecx       ; Move EDI to end
    dec edi            ; EDI points to the last valid byte

.loop:
    cmp esi, edi       ; Compare Left and Right pointers
    jge .done          ; If crossed/met, exit

    ; Swap bytes
    mov al, byte [esi]
    mov cl, byte [edi]
    mov byte [esi], cl
    mov byte [edi], al

    inc esi            ; Left++
    dec edi            ; Right--
    jmp .loop

.done:
    mov eax, [ebp+8]   ; Return the original buffer pointer

    pop edi
    pop esi
    pop ebp
    ret 16
