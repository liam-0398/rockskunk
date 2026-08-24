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

- Original FORTRAN Compiler
- Old Pascal Compilers

## What I have learned from bootstrap compiler mistakes

- Reverted after changing to record based system. Never again.

# Never

- Records/Structs tracking state in the compiler
- Formal IR
- Giant AST

# Always

- Arrays and strings
- Simplicity over abstraction

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
# Psuedocode
- Note: These examples are generated and therefore probably bullshit but I want to demonstrate the terse syntax.
- rockskunk (whenever vectors get atted in 2035)
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
#include <immintrin.h>

typedef struct {
	__m256d	prevOut;	/* 4 x float64, one lane per voice */
} LowpassState;

void
lowpass4_init(LowpassState *state)
{
	state->prevOut = _mm256_setzero_pd();
}

static inline __m256d
lowpass4(LowpassState *state, __m256d sampleVec, __m256d cutoffVec)
{
	__m256d	delta;

	delta = _mm256_sub_pd(sampleVec, state->prevOut);
	state->prevOut = _mm256_add_pd(state->prevOut,
	    _mm256_mul_pd(cutoffVec, delta));
	return state->prevOut;
}
```
- rockskunk
```
; onepole.rsk - one-pole lowpass, f64 samples, stdin to stdout
|V
    buf{4096}
    prev := 0.0f
    coeff := 0.15f
    got := 0
    i := 0 |

F onepole(x: f) {
    d := x - prev
    prev := d * coeff + prev
    r := prev
}

P filterBlock(n) {
    LF (i := 0 until n) {
        buf{i} := onepole(buf{i})
    }
}

got := read(0, &buf, 32768)
LW (got > 0) {
    filterBlock(got / 8)
    write(1, &buf, got)
    got := read(0, &buf, 32768)
}
```
- Rust
```
use std::io::{self, Read, Write};
use std::mem::size_of;

const SAMPLE: usize = size_of::<f64>();
const BLOCK: usize = 4096 * SAMPLE;

struct OnePole {
    coeff: f64,
    prev: f64,
}

impl OnePole {
    fn new(coeff: f64) -> Self {
        Self { coeff, prev: 0.0 }
    }

    fn process(&mut self, x: f64) -> f64 {
        self.prev += self.coeff * (x - self.prev);
        self.prev
    }
}

fn main() -> io::Result<()> {
    let mut filter = OnePole::new(0.15);
    let mut buf = [0u8; BLOCK];
    let mut filled = 0;

    let mut stdin = io::stdin().lock();
    let mut stdout = io::stdout().lock();

    loop {
        let got = match stdin.read(&mut buf[filled..]) {
            Ok(0) => break,
            Ok(n) => n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(e),
        };
        filled += got;

        let whole = filled - filled % SAMPLE;
        for frame in buf[..whole].chunks_exact_mut(SAMPLE) {
            let mut bytes = [0u8; SAMPLE];
            bytes.copy_from_slice(frame);
            let y = filter.process(f64::from_le_bytes(bytes));
            frame.copy_from_slice(&y.to_le_bytes());
        }
        stdout.write_all(&buf[..whole])?;

        buf.copy_within(whole..filled, 0);
        filled -= whole;
    }

    if filled != 0 {
        return Err(io::Error::new(
            io::ErrorKind::UnexpectedEof,
            "trailing partial sample",
        ));
    }
    stdout.flush()
}
```
