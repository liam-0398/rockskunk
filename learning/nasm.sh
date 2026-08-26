#!/bin/bash

nasm -f elf64 -g scratch.asm -o scratch.o && ld scratch.o -o test
