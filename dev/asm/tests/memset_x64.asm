bits 64
global mem_set

; CallWindowProcW signature (x64):
; RCX = Destination pointer (P1)
; RDX = Byte value to fill (P2)
; R8  = Length in bytes (P3)
; R9  = ignored

mem_set:
    push rdi           ; Save RDI register

    mov r9, rcx        ; Save original destination pointer to return later
    mov rdi, rcx       ; RDI = Destination ptr (required by stosb)
    mov rax, rdx       ; AL  = Byte value (lowest byte of RAX)
    mov rcx, r8        ; RCX = Byte counter (Length)

    rep stosb          ; Fill RCX bytes at [RDI] with AL

    mov rax, r9        ; Return the original destination pointer
    
    pop rdi            ; Restore RDI
    ret
