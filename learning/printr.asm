section .bss
digitbuf: resb 32

section .text
global _start

_start:
mov rax, 888888       ; Irrelevant
call print_r
mov rdi, 0
mov rax, 60
syscall


; the goal is to make a register dump so inline asm can be done with ease
; not the biggest priority because A. Im stil llearning and this will be hard and B. You can just
; look at intermediate.asm

; need to make a static

print_r:

; Threaten the linux kernel
mov rax, 1
mov rdi, 1
mov rsi, digitbuf
mov rdx, rcx ; put saved counter amount into rdx for the syscall
syscall
ret


