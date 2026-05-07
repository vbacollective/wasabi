bits 64
global str_len

; CallWindowProcW signature (x64):
; RCX = String pointer (P1)
; RDX, R8, R9 = ignored

str_len:
    push rdi           ; Save RDI
    mov rdi, rcx       ; RDI = string pointer (scasb requirement)
    xor al, al         ; AL = 0 (we are looking for the null terminator)
    mov rcx, -1        ; RCX = -1 (max count for scanning)
    
    repne scasb        ; Scan string for AL (0), decrementing RCX

    mov rax, -2
    sub rax, rcx       ; Calculate length: -2 - (-1 - length) = length

    pop rdi            ; Restore RDI
    ret                ; Return length in RAX
