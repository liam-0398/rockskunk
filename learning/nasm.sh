#!/bin/bash

nasm -f elf64 -g print_qword.asm -o scratch.o && ld scratch.o -o test
