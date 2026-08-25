section .bss
   digitbuf: resb 32
g_argc: resq 1
g_argv: resq 1
binbuf: resb 65
charbuf: resb 8
readbuf: resb 256
writebuf: resb 256
buf: resq 8192

section .data
   str_0: dq 1
db 10, 0
   str_3: dq 0
db 0
   str_10: dq 14
db 'NO SOURCE FILE', 0
   str_12: dq 19
db 'NO DESTINATION FILE', 0

section .text
read:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 0
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

write:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 1
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

open:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 2
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

lseek:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 8
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

unlink:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 87
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

fstat:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 5
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

mkdir:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 83
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

close:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 3
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

stat:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 4
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

lstat:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 6
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

getdents64:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 217
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

chdir:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 80
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

getcwd:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 79
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

readlink:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 89
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

mount:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 165
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

umount2:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 166
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

fcntl:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 72
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

truncate:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 76
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

ftruncate:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 77
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

rename:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 82
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

rmdir:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 84
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

link:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 86
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

symlink:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 88
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

chmod:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 90
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

access:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 21
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

pipe:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 22
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

dup:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 32
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

dup2:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 33
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

pread:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 17
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

pwrite:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 18
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

execve:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 59
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

execveat:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 322
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

fork:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 57
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

vfork:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 58
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

clone:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 56
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

wait4:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 61
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

pipe2:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 293
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

kill:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 62
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

writeln:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000064
    mov [rbp-8], rdi
    mov rax, [rbp-8]
    mov rax, [rax]
    mov [rbp-16], rax
    mov rax, [rbp-8]
    add rax, 8
    mov [rbp-24], rax
    mov rax, 1
    mov rdi, 1
    mov rsi, [rbp-24]
    mov rdx, [rbp-16]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
    mov [rbp-32], rax
    mov rax, str_0
mov [rbp-40], rax
    mov rax, [rax]
    mov [rbp-48], rax
    mov rax, [rbp-40]
    add rax, 8
    mov [rbp-56], rax
    mov rax, 1
    mov rdi, 1
    mov rsi, [rbp-56]
    mov rdx, [rbp-48]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
    mov [rbp-64], rax
    add rsp, 0000000064
    pop rbp
    ret

writet:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov rax, [rbp-8]
    mov rax, [rax]
    mov [rbp-16], rax
    mov rax, [rbp-8]
    add rax, 8
    mov [rbp-24], rax
    mov rax, 1
    mov rdi, 1
    mov rsi, [rbp-24]
    mov rdx, [rbp-16]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
    mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

ccmp:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, [rbp-24]
    add rsp, 0000000016
    pop rbp
    ret

printc:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, [rbp-8]
    mov byte    [charbuf + 0], al
    mov rax, 1
    mov rdi, 1
    mov rsi, charbuf
    mov rdx, 1
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
    add rsp, 0000000016
    pop rbp
    ret

printb:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov rax, 0
    mov [rbp-16], rax
    mov rax, 0
    mov [rbp-24], rax
    mov rax, 0
    mov [rbp-32], rax
    mov rax, 0
    mov [rbp-32], rax
LF1:
    mov rax, [rbp-32]
    cmp rax, 64
    jge LF2
    mov rax, 63
    sub rax, [rbp-32]
    mov [rbp-16], rax
    mov rax, [rbp-8]
        mov rcx, [rbp-16]
    shr rax, cl
mov [rbp-24], rax
        and rax, 1
mov [rbp-24], rax
    add rax, 48
    mov [rbp-24], rax
    mov r10, [rbp-32]
    mov rax, [rbp-24]
    mov byte    [binbuf + r10*1], al
    inc qword [rbp-32]
    jmp LF1
LF2:
    mov rax, 32
    mov byte    [binbuf + 64], al
    mov rax, 1
    mov rdi, 1
    mov rsi, binbuf
    mov rdx, 65
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
    add rsp, 0000000032
    pop rbp
    ret

readln:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov rax, str_3
    mov [rbp-8], rax
    mov rax, 0
    mov [rbp-16], rax
    mov rax, 0
    mov [rbp-24], rax
    mov rax, 0
    mov [rbp-24], rax
LF4:
    mov rax, [rbp-24]
    cmp rax, 256
    jge LF5
    mov rdi, 0
    mov r10, [rbp-24]
    mov rsi,    [readbuf + r10*1]
    mov rdx, 1
    call read
    mov [rbp-16], rax
    mov r10, [rbp-24]
    mov rax,    [readbuf + r10*1]
    push rax
    mov rbx, 10
    pop rax
    cmp rax, rbx
    jne W6
    mov rax, [rbp-24]
    mov [rbp-32], rax
    jmp LF5
W6:
    inc qword [rbp-24]
    jmp LF4
LF5:
    mov rax, [rbp-32]
    sub rax, 1
    mov rax, 0
    mov [rbp-24], rax
LF7:
    mov rax, [rbp-24]
    cmp rax, rax
    jge LF8
    mov r10, [rbp-24]
    mov rax,    [readbuf + r10*1]
    mov [rbp-8], rax
    mov rdi, [rbp-8]
    call printc
    inc qword [rbp-24]
    jmp LF7
LF8:
    mov rax, [rbp-8]
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

length:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, [rbp-8]
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

socket:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 41
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

bind:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 49
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

listen:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 50
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

accept:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 43
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

connect:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 42
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

sendto:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000064
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov [rbp-48], r9
    mov rax, 44
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, [rbp-48]
    syscall 
mov [rbp-56], rax
    add rsp, 0000000064
    pop rbp
    ret

recvfrom:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000064
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov [rbp-48], r9
    mov rax, 45
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, [rbp-48]
    syscall 
mov [rbp-56], rax
    add rsp, 0000000064
    pop rbp
    ret

setsockopt:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 54
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

poll:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 7
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

epoll_create1:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 291
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

epoll_ctl:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 233
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

epoll_wait:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 232
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

ioctl:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 16
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

rt_sigaction:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 13
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

rt_sigprocmask:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 14
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

alarm:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 37
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

clock_gettime:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 228
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

nanosleep:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 35
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

gettimeofday:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 96
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

setpgid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 109
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

getpgid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 121
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

setsid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 112
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

getsid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 124
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

ioctl_tcsetpgrp:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 16
    mov rdi, [rbp-8]
    mov rsi, 21518
    mov rdx, [rbp-16]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

ioctl_tcgetpgrp:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 16
    mov rdi, [rbp-8]
    mov rsi, 21519
    mov rdx, [rbp-16]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

mmap:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000064
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov [rbp-48], r9
    mov rax, 9
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, [rbp-48]
    syscall 
mov [rbp-56], rax
    add rsp, 0000000064
    pop rbp
    ret

munmap:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 11
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

mprotect:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 10
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

madvise:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 28
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

waitid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 247
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

getrlimit:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 97
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

setrlimit:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 160
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

prlimit64:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 302
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

prctl:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 157
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

reboot:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 169
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

syslog:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 103
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

sethostname:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 170
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

pselect6:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000064
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov [rbp-48], r9
    mov rax, 270
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, [rbp-48]
    syscall 
mov [rbp-56], rax
    add rsp, 0000000064
    pop rbp
    ret

getpid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 39
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

brk:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 12
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

exit:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 60
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

exitgroup:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 231
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

uname:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 63
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

sched_yield:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 24
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

getuid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 102
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

umask:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov [rbp-8], rdi
    mov rax, 95
    mov rdi, [rbp-8]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-16], rax
    add rsp, 0000000016
    pop rbp
    ret

geteuid:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, 107
    mov rdi, 0
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

argc:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000016
    mov rax, [g_argc]
mov [rbp-8], rax
    add rsp, 0000000016
    pop rbp
    ret

argv:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov rax, [rbp-8]
    imul rax, 8
    mov [rbp-16], rax
    mov rax, [g_argv]
    add rax, [rbp-16]
mov [rbp-24], rax
    mov rax, [rax]
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

send:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 44
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

recv:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 45
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

shutdown:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov rax, 48
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-24], rax
    add rsp, 0000000032
    pop rbp
    ret

getsockopt:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 55
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

getsockname:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 51
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

getpeername:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 52
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

socketpair:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 53
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

accept4:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 288
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

sendmsg:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 46
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

recvmsg:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000032
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov rax, 47
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-32], rax
    add rsp, 0000000032
    pop rbp
    ret

sendmmsg:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 307
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

recvmmsg:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov rax, 299
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, 0
    syscall 
mov [rbp-48], rax
    add rsp, 0000000048
    pop rbp
    ret

sendfile:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 40
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

splice:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000064
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov [rbp-40], r8
    mov [rbp-48], r9
    mov rax, 275
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, [rbp-40]
    mov r9, [rbp-48]
    syscall 
mov [rbp-56], rax
    add rsp, 0000000064
    pop rbp
    ret

vmsplice:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 278
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

tee:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov [rbp-8], rdi
    mov [rbp-16], rsi
    mov [rbp-24], rdx
    mov [rbp-32], rcx
    mov rax, 276
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov r10, [rbp-32]
    mov r8, 0
    mov r9, 0
    syscall 
mov [rbp-40], rax
    add rsp, 0000000048
    pop rbp
    ret

copy:
    push rbp
    mov rbp, rsp
    sub rsp, 0000000048
    mov rax, 1
    mov [rbp-8], rax
    mov rdi, 1
    call argv
    mov [rbp-16], rax
    mov rdi, 2
    call argv
    mov [rbp-24], rax
    mov rdi, [rbp-16]
    mov rsi, 0
    mov rdx, 0
    call open
mov [rbp-32], rax
    push rax
    mov rbx, 0
    pop rax
    cmp rax, rbx
    jge W9
    mov rdi, str_10
    call writeln
    mov rdi, 1
    call exit
W9:
    mov rdi, [rbp-24]
    mov rsi, 65
    mov rdx, 420
    call open
mov [rbp-40], rax
    push rax
    mov rbx, 0
    pop rax
    cmp rax, rbx
    jge W11
    mov rdi, str_12
    call writeln
    mov rdi, 1
    call exit
W11:
LW13:
    mov rax, [rbp-8]
    cmp rax, 0
    jle LW14
    mov rdi, [rbp-32]
    mov rsi, buf
    mov rdx, 8192
    call read
mov [rbp-8], rax
    push rax
    mov rbx, 0
    pop rax
    cmp rax, rbx
    jle W15
    mov rdi, [rbp-40]
    mov rsi, buf
    mov rdx, [rbp-8]
    call write
W15:
    jmp LW13
LW14:
    mov rdi, [rbp-32]
    call close
    mov rdi, [rbp-40]
    call close
    add rsp, 0000000048
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    call copy
    mov rdi, 0
    call exit
    pop rbp
    ret


global _start
_start:
  mov rax, [rsp]
  mov [g_argc], rax
  lea rax, [rsp + 8]
  mov [g_argv], rax
  call main
  mov rdi, rax
  mov rax, 60
  syscall

print_char:
    mov [digitbuf], al
    mov rax, 1
    mov rdi, 1
    mov rsi, digitbuf
    mov rdx, 1
    syscall
    ret


print_qword_nosp:
    mov rsi, digitbuf + 20
    mov rcx, 0
    cmp rax, 0
    jne .pqn_loop
    dec rsi
    mov byte [rsi], 48
    inc rcx
    jmp .pqn_done
.pqn_loop:
    cmp rax, 0
    je .pqn_done
    cqo
    mov rbx, 10
    idiv rbx
    add rdx, 48
    dec rsi
    mov [rsi], dl
    inc rcx
    jmp .pqn_loop
.pqn_done:
    mov rax, 1
    mov rdi, 1
    mov rdx, rcx
    syscall
    ret


print_qword:
    call print_qword_nosp
    mov al, 32
    call print_char
    ret


print_float:
    cvttsd2si rax, xmm0
    push rax
    cvtsi2sd xmm1, rax
    subsd xmm0, xmm1
    mov rax, 1000
    cvtsi2sd xmm1, rax
    mulsd xmm0, xmm1
    cvtsd2si rbx, xmm0
    pop rax
    push rbx
    call print_qword_nosp
    mov al, 46
    call print_char
    pop rax
    call print_frac3
    mov al, 32
    call print_char
    ret


print_frac3:
    mov rsi, digitbuf + 3
    mov rcx, 3
.pf_loop:
    cqo
    mov rbx, 10
    idiv rbx
    add rdx, 48
    dec rsi
    mov [rsi], dl
    dec rcx
    jnz .pf_loop
    mov rax, 1
    mov rdi, 1
    mov rsi, digitbuf
    mov rdx, 3
    syscall
    ret


intToFloat:
    cvtsi2sd xmm0, rax
    ret


floatToInt:
    cvttsd2si rax, xmm0
    ret

