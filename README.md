## rockskunk
# A terse, typeless (ish), no-bullshit language

Compiles VERY simple test programs to NASM thus far. Using old C transpiler I had written for
another language attempt and reworking it to output NASM x86_64 assembly. WAY down the line I want to do a ppc32 version as well.

# Core tenants 

1. Two types: Float64 (IEEE-754). String (pointer, legnth prepended). Everything else is just raw memory (8-byte qword)
2. Compiles directly to x86_64 NASM 
3. Contains vector intrinsics that use SIMD registers based on what CPUFLAGS are availble. Can be set with command line argument to target older/newer CPUs. Detection is done in-compiler in Pascal with branching for every variation.
4. Memory is flat, arrays are offsets. 
5. Pascal FFI for interfacing with system libraries
6. variable "r" inside function is always return, doesnt need declared
7. Compiler auto-executes NASM so its a one shot compile
8. floats are just defined with number ending in f for easy type check. a := 52.222f
9. raw memory is just treated as 8 byte word.
10. local variables auto declared on assignment

# Conventions

- First function called is always "main"
- Many small functions over large blobs of doom
- Use common functions inside functions to keep codebase small
- Left to right associative for vector ops a ** b ** c
- Normal operators evaluated left to right
- Closing bracket goes on last below last unless it is a loop/conditional, those are closed inline
- floats must look like 10.0f with the . and the f
- never mix floats and ints. use intfloat() or floatint()
- Functions are always declared before they are called

# Status

The Gameplan is to get this pascal bootstrap compiler good enough to write my own compiler in rockskunk. Then is when im going to pay more attention to spilling registers into memory and inline optimization as I learn more and become more comfortable. 

# Syntax

```
;  comment

; file inclusion
ADD("file.rsk")'
ADD("dir/ofile.rsk")'


; global variables (before first function)
|V
    a := 500'
    b := 42342'
    string ::= "bigfootisreal"'
    array[1] := 333' |


; Static assignments (before first function)
|S'
    password := "mustardstains"' |


; records
|R' delayLine'
    buf := 0'      ; offset 0, N floats
    wptr := N'      ; offset N
    len := N+1'
    fb := N+2' |

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
LF (i := 1 until 10) {
    p("ANNOYING MESSAGE")
    i := i + 1
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
I ([i = 5] or [f = 69]) {
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
& ;bitwise
or ;logical
and ;logical
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

; treat normal ops as pointers as designated by compiler if posible with current memory
; model to avoid complexity

p := &a ; load specific address


; Misc

|D' align(32)| ; COMPILER DIRECTIVES, align 32. TOP OF FILE

array := v(array) ;vectorize (auto width based on cpuflags)
                  ; pad with zeros if trying to shove 4 wide into AVX-512 for example
                  ; make this data/data structure able to be used with ** ++ etc

```
# Psuedocode
- rockskunk
```
; one-pole lowpass, N voices in parallel (SIMD lanes), auto-width via v()
|V'
    prevOut[4] := 0' |

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