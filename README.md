## rockskunk
# A terse, typeless (ish), no-bullshit language

Very WIP. WAY down the line I want to do a ppc32 version as well so i can get weird with my Power Macs. I have no formal education I am making this up as I go along.

# Core tenants 

1. Two types: Float64 (IEEE-754). String (pointer, legnth prepended). Everything else is just raw memory (8-byte qword)
2. Compiles directly to x86_64 NASM 
3. Contains vector intrinsics that use SIMD registers based on what CPUFLAGS are availble. Can be set with command line argument to target older/newer CPUs. Detection is done in-compiler in Pascal with branching for every variation.
4. Memory is flat, arrays are offsets. 
5. Pascal FFI for interfacing with system libraries
6. variable "r" inside function is always return, doesnt need declared
7. Compiler auto-executes NASM so its a one shot compile
8. floats are just defined with number ending in f for easy type check. a := 52.222f
9. local variables auto declared on assignment
10. The compiler isn't the the all seeing overlord. It will halt on obvious syntax violations but does not assume it knows more than the programmer and will warn rather than halt on stupid decisions. There is nothing stopping you from using inline asm to destroy the stack. If you really mess up, the nasm pass will call you out. If you know more than the compiler and want some weird stuff, as long as NASM approves you are free to do whatever you want. 

# Conventions

- First function called is always "main"
- Many small functions over large blobs of doom
- Use common functions inside functions to keep codebase small
- Operators evaluated left to right
- Closing bracket goes on last below last unless it is a loop/conditional, those are closed inline
- Floats must look like 10.0f with the . and the f
- Never mix floats and ints.
- Functions are always declared before they are called


## What I have learned from bootstrap mistakes

- Reverted after changing to record based system. Never again.

# Never

- Records/Structs tracking state
- Formal IR
- Giant AST

# Always

- Arrays and strings
- Simplicity over abstraction
- Error checking

# Requirements

- Vector support
- Dead code elimination
- Optimization via string/regex op pass over intermediate.asm
- Register allocation
- Code folding in-compiler

# Inspiration

- Original FORTRAN Compiler
- Old Pascal Compilers

## Not Implemented Yet

- If/Else
- Inline ASM
- Vectors
- Pascal FFI
- Records
- Static declarations
- Global variables (arrays are fine)
- Register Allocation
- Malloc/Free
- Directives

## Syntax

```
;  comment

; file inclusion
ADD("file.rsk")'
ADD("dir/ofile.rsk")'


; global variables (before first function)
|V
    a := 500
    b := 42342/0f
    string := 'bigfootisreal'
    array[1] := 333' |


; Static assignments (before first function)
|S
    password := 'mustardstains' |


; records
|R delayLine
    buf := 0      ; offset 0, N floats
    wptr := N      ; offset N
    len := N+1
    fb := N+2 |

delayLine.buf := 5'
result := delayLine.wptr'


; assignments
    a := b
    array[1] := 555 ; raw memory
    array![1] := 3 ; byte array
    array{1} := 23.4f ; float
    array<1> := "hello world" ; string


; Functions
; Undeclared args are raw qword (so int or whatever you want), declare with (var: f) or 
; (var: s). No chained args for single type declaration. 
;fn(a, b: f, c, d, e: s, f: f)
; word, float, word, word, string, float

F functionName(a1, a2: f) { ; FUNCTION, NEED TO RETURN
    c := 5
    r := a1 * a2
}

P functionName(a1, a2: f) { ; PROCEDURE, NO RETURN
    c := a1 * a2
}

; For Loop
LF (i := 1 until x) {
    writeLn("ANNOYING MESSAGE")
}

; Do Loop
; Use with only lits or static definitions, speed and efficieny increase over LF
; Unrolled
DO (i := 1 until 10) {
    writeLn("ANNOYING MESSAGE")
}


; While loop
LW (i <= 500) {
    i++
}


; When (singluar if)
W (i = 5) {
    consumeBeers
}


; If (continues until else is seen)
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
a := g % h
a :+= b
a :*= b


; Vector operations
; AVX2 / SSSE3 / FMA3 auto-detect based on cpu flags

a := c ++ b
a := c ** b
a := c // b
a := c %% b
a := c *+ b ; FMA

a :++= b
a :**= b

lf0 := vsin(phase_vector)

vabs
vsqrt
vsin
vcos
vmin
vmax
vfloor
vceil


; Syscall

result := sys(num,a,b,c)


; Conditionals

=
<
>
<=
>=
| ;bitwise
$ ;bitwise
or ;logical
and ;bitwise
nor ;bitwise
xor ;bitwise


; Dedicated streamlining functions

; Linear interpolation eg result := a + t * (b - a);
result := lint(a, b, t)

; bitwise ROT eg unsigned int rotated = (x << n) | (x >> (32 - n));
rotated := brot(x, n)


; Memory ops

p := cm(size) ; malloc
fm(p) ; free

; Addressing / Pointers

p := &a ; load specific address
v := p^        ; v now holds whatever qword lives at that address
p^ := b        ; write through

; strings are length-prefixed pointers, null terminated for C compat
len := s^         ; length of string s
data := s + 8     ; address of s's character data


; Misc

|D' align(32)| ; COMPILER DIRECTIVES, align 32. TOP OF FILE
|A mov rax, 1~ mov xmm0, 3~ | ;inline asm

array := v(array) ;vectorize (auto width based on cpuflags)
                  ; pad with zeros if trying to shove 4 wide into AVX-512 for example
                  ; make this data/data structure able to be used with ** ++ etc

```
# Psuedocode
- rockskunk
```
; one-pole lowpass, N voices in parallel (SIMD lanes), auto-width via v()
|V'
    prevOut[4] := 0 |

F lowpass4(sampleVec, cutoffVec) {
    delta := v(sampleVec) -- v(prevOut)
    prevOut := v(prevOut) ++ (v(cutoffVec) ** delta)
    r := prevOut
    }
```
- C
```
// one-pole lowpass, 4 voices in parallel (SIMD lanes), AVX intrinsics
#include <immintrin.h>

typedef struct {
    __m256d prevOut; // 4x float64 lanes, one per voice
} LowpassState;

__m256d lowpass4(LowpassState *state, __m256d sampleVec, __m256d cutoffVec) {
    __m256d delta = _mm256_sub_pd(sampleVec, state->prevOut);
    state->prevOut = _mm256_add_pd(state->prevOut, _mm256_mul_pd(cutoffVec, delta));
    return state->prevOut;
}
```
- rockskunk
```
F normalize(buf) {
    peak := 0f
    LF (i := 0 until blockLen) {
        peak := vmax(peak, vabs(v(buf)))
        i := i + 1
    }
    LF (i := 0 until blockLen) {
        buf[i] := v(buf) // v(peak)
        i := i + 1 }
        }
```
- Pascal
```
function normalize(var buf: array of Double; blockLen: Integer): Boolean;
var
    i: Integer;
    peak, absVal: Double;
begin
    peak := 0.0;
    for i := 0 to blockLen - 1 do
    begin
        absVal := Abs(buf[i]);
        if absVal > peak then
            peak := absVal;
    end;
    if peak > 0.0 then
        for i := 0 to blockLen - 1 do
            buf[i] := buf[i] / peak;
    normalize := True;
end;
```