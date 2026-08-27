section .bss
charbuf: resb 255

section .text
global _start

_start:
mov rax, 888888       ; FAKE INPUT
call print_qword
mov rdi, 0
mov rax, 60
syscall

print_t:
mov rbx, rax
mov [charuf]. rbx ; but in buffer so can seek in memory
mov rax, [charbuf + 8] ; skip length and move to data
call print_qword ; send to be printed to stdout
ret


