## rockskunk
# A terse, typeless (ish), no-bullshit language

Very WIP. WAY WAY down the line I want to do a ppc32 version as well so i can get weird with my Power Macs. I have no formal education I am making this up as I go along.

# Core tenants 

1. One formal type: Float64. Everything else is just raw memory (8-byte qword)
2. Compiles directly to x86_64 NASM 
3. Memory is flat, arrays are offsets. 
4. Pascal FFI for interfacing with system libraries
5. variable "r" inside function is always returned, doesnt need declared
6. Compiler auto-executes NASM so its a one shot compile
7. floats are just defined with number ending in f for easy type check. a := 52.222f
8. local variables auto declared on assignment
9. The compiler isn't the the all seeing overlord. It will halt on obvious syntax violations but does not assume it knows more than the programmer and will warn rather than halt on stupid decisions. There is nothing stopping you from using inline asm to destroy the stack. If you really mess up, the nasm pass will call you out. If you know more than the compiler and want some weird stuff, as long as NASM approves you are free to do whatever you want. 

# Conventions

- First function called is always "main"
- Many small functions over large blobs of doom
- Use common functions inside functions to keep codebase small
- Operators evaluated left to right
- Closing bracket goes on line below last unless it is a loop/conditional, those are closed inline
- Floats must look like 10.0f with the . and the f
- Never mix floats and ints.
- Functions are always declared before they are called. No forward dec statements as of now, never forward functions without decaration.

# Inspiration

- B
- Pascal
- Common Lisp
- FORTH

## What I have learned from bootstrap compiler mistakes

- Reverted after changing to record based system. Never again.
- Never again non-array state tracking in the compiler. Makes everything much more difficult to reason 
about for zero benefit.
- Never a Formal IR
- Never an AST in general


## Not Implemented Yet

- Vectors (this will take FOREVER)
- Pascal FFI
- Records
- Static declarations
- Register Allocation (this will take FOREVER)
- Malloc/Free
- Directives
- Compound operators

## Syntax

```
;  comment

; file inclusion 
; not implemented yet
ADD("file.rsk")'
ADD("dir/ofile.rsk")'


; global variables (before first function)
|V
    a := 500
    b := 42342.0f
    string := 'bigfootisreal'
    array[1] |


; Static assignments (before first function)
; not implemented yet
|S
    password := 'slothhockey' |


; records
; not implemented yet
|R somethingUseful
    data 0:2    ; offset:range     
    flag 2:4
    val  6:8 |

somethingUseful.data = 10
somethingUseful.flag = 'LOAD'


; assignments
    a := b
    array[1] := 555     ; qword (int, string, your wildest dreams)
    array![1] := 3      ; byte array
    array{1} := 23.4f   ; float

; Misc
    BREAK ; you know what this is
    [[label]] ; bypass the symbol table and use a nasm label directly, used for argv/c

; Intrinsics
    ; ASM
    printc() ;char
    printf() ;float
    printw() ;qword (ints, the usual)
    ; STANDARD LIBRARY
    writeln()
    tons of syscalls


; Functions
; Undeclared args are raw qword (so int or whatever you want), declare with (var: f) for float 
; No chained args for single type declaration. 
;fn(a, b: f, c, d, e: s, f: f)
; word, float, word, word, string, float

F functionName(a1, a2: f) { ; FUNCTION, NEED TO RETURN
    c := 5
    r := a1 * a2
}

P functionName(a1, a2: f, a3) { ; PROCEDURE, NO RETURN
    c := a1 * a2
}

; all loops must initialize var beforehand

; For Loop
LF (i := 1 until x) {
    array[i] := otherarray[i]
}

; Do Loop
; Highest performance loop
; Use with only lits or static definitions, speed and efficieny increase over LF
; If you use a ton of iterations you WILL bloat your code
; Unrolled
DO (i := 1 until 10) {
    writeLn("ANNOYING MESSAGE")
}


; While loop
LW (i <= 500) {
    a := b + 1
}

; LOCATE - specialized array search. Do loop under 10 iterations, for loop for more.
; c is local var and is returned -1 for no match and otherwise returns the index of the match
LOCATE (c, variable, checking[100])
        IF (c >= 0) { index := c }
        E { writeln('NOT FOUND) }


; When (singluar if)
W (i = 5) {
    consumeBeers()
}


; If (continues until else is seen, requires else)
; think of it as bootleg else if
IF ([i = 5] or [f = 69]) {
    p("MATCH FOUND")
}


; Else
E {
    drinkWine()
}


; Mathermaticcs

a := g + h
a := g * h
a := g / h
a := g % h ; not implemented yet

; Vector operations
; AVX2 / SSSE3 / FMA3 auto-detect width based on cpu flags or compile flag
; not implemented yet

a := c ++ b
a := c ** b
a := c // b
a := c %% b
a := (a, c) *+ b ; FMA

vabs
vsqrt
vsin
vcos
vmin
vmax
vfloor
vceil


; Syscall

result := sys(num,a,b,c) ; etc
result := write(1, 'DIVORCE LAWYER', 14)


; Conditionals

=
<
>
<= ; not implemented yet
>= ; not implemented yet
or ;logical ; not implemented yet
and ;logical ; not implemented yet
| ;bitwise or
$ ;bitwise and
nor ;bitwise
xor ;bitwise


; Memory ops

p := cm(size) ; malloc ; not implemented yet
fm(p) ; free ; not implemented yet

; Addressing / Pointers

p := &a ; load specific address
v := p^        ; v now holds whatever qword lives at that address
p^ := b        ; write through

; strings are length-prefixed pointers, null terminated for C compat
len := s^         ; length of string s
data := s + 8     ; address of s's character data


; Misc

|D' align(32)| ; COMPILER DIRECTIVES, align 32. TOP OF FILE ; not implemented yet
|A mov rax, 1~ mov xmm0, 3~ | ;inline asm

; not implemented yet
array := makeVector(array) ;vectorize (auto width based on cpuflags)
                           ; pad with zeros if trying to shove 4 wide into AVX-512 for example
                           ; make this data/data structure able to be used with ** ++ etc

```
# Example
- rockskunk
```
|V buf[8192] |

P copy() {
    bytes := 1
    filename := argv(1)
    destname := argv(2)
    fd := open(filename, 0, 0) ; raw linux syscall, no libc -1 isnt catchall for error
        W (fd < 0 ) { writeln('NO SOURCE FILE') exit(1)}
    fd2 := open(destname, 65, 420)
        W (fd2 < 0 ) { writeln('NO DESTINATION FILE') exit(1)}

    LW (bytes > 0) {
        bytes := read(fd, buf, 8192)
        W (bytes > 0) { write(fd2, buf, bytes) } }
    close(fd)
    close(fd2)
}

P main() { copy() exit(0)}
```
- C
```
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

char buf[8192];

void
copy(char *argv[])
{
	char	*destname, *filename;
	ssize_t	 bytes;
	int	 fd, fd2;

	filename = argv[1];
	destname = argv[2];
	fd = open(filename, O_RDONLY, 0);
	if (fd < 0) {
		puts("NO SOURCE FILE");
		exit(1);
	}
	fd2 = open(destname, O_WRONLY | O_CREAT, 0644);
	if (fd2 < 0) {
		puts("NO DESTINATION FILE");
		exit(1);
	}
	do {
		bytes = read(fd, buf, 8192);
		if (bytes > 0)
			write(fd2, buf, bytes);
	} while (bytes > 0);
	close(fd);
	close(fd2);
}

int
main(int argc, char *argv[])
{
	copy(argv);
	exit(0);
}
```

