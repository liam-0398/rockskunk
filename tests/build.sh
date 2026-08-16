#!/bin/bash
nasm -f elf64 intermediate.asm -o test.o && ld test.o -o test && ./test; echo $?