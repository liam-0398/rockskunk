section .bss
digitbuf: resb 32

section .text
global _start

_start:
mov xmm0, 3.14        ; FAKE INPUT
call print_float
mov rdi, 0
mov rax, 60
syscall

; REFERENCE https://faculty.cs.niu.edu/~hutchins/csci640/float.htm

print_float:































.collect:
cqo             ; prep registers
idiv rbx        ; divide rax rbx
add rdx, 48     ; add ascii '0' to remainder, completing conversion to charachter
push rdx        ; hide rdx in the stack so it doesnt get clobbered and stack is like forth so its in right order
inc rcx         ; increment counter
test rax, rax   ; check if rax = 0
jnz .collect    ; if its not 0, continue loop

.emit:
pop rdx         ; pull the charachters back out of the stack, LIFO like forth
mov [digitbuf + r11], dl ; mov the low bytes of rdx into the buffer at the offset of the counter
inc r11
cmp rcx, r11   ; check match
jne .emit       ; continue loop if no match

xor rdx, rdx    ; reinit rdx
add rdx, 32     ; add ascii space code
;add [digitbuf + r10 + 1], dl ; add the space at the end of the line, actually corrupt the output lol
;add rcx, 1 ; account for space? I dont think this is working
; Threaten the linux kernel
mov rax, 1
mov rdi, 1
mov rsi, digitbuf
mov rdx, rcx ; put saved counter amount into rdx for the syscall
syscall
ret


