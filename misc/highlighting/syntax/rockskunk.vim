" Vim syntax file for rockskunk (.rsk)
" Ported from the VS Code TextMate grammar. Matches the compiler's actual
" tokenization, including real quirks noted inline below (OR/AND are
" uppercase-only, NOT is lowercase-only, V/S/D/R are only keywords when
" glued to a preceding "|", etc).
"
" Ordering note: unlike TextMate (first match in the pattern list wins),
" Vim gives priority to whichever :syntax command was defined LAST when
" two rules match the same starting position (match length is NOT a
" factor -- see :help :syn-priority). So specific/overriding rules are
" placed AFTER the generic ones they need to win over -- opposite order
" from the .tmLanguage.json this was ported from. The block-header rules
" near the bottom are a direct consequence of this: they have to come
" after the bitwise-or rule, or a bare "|" inside "|V" would win instead.
" (:syntax keyword items are the one exception -- they always beat an
" overlapping :syntax match regardless of definition order, which is why
" F/P/W/IF/E/etc below don't need to worry about this.)

if exists("b:current_syntax")
  finish
endif

syntax case match

" ---- comments ----
syntax match rockskunkComment /;.*$/

" ---- strings ----
" ' is always a string delimiter to the real lexer -- never a statement
" terminator, and there is no recovery for an unterminated one, so this
" is kept `oneline` to fail visibly instead of swallowing the rest of
" the file the way the real compiler currently does on the same mistake.
syntax region rockskunkString start=/'/ end=/'/ oneline contains=rockskunkInvalidEscape,rockskunkEscape
syntax match rockskunkInvalidEscape /\\./ contained
syntax match rockskunkEscape /\\[ntr0\']/ contained

" ---- generic identifiers (lowest priority; keywords/builtins below win) ----
syntax match rockskunkVariable /[A-Za-z_][A-Za-z0-9_]*/
syntax match rockskunkFuncCall /[A-Za-z_][A-Za-z0-9_]*\ze\s*(/

" ---- member access: record.field (not yet implemented, spec-only) ----
syntax match rockskunkAccessorDot /\./
syntax match rockskunkMember /\%(\.\)\@<=[A-Za-z_][A-Za-z0-9_]*/

" ---- numbers ----
syntax match rockskunkInteger /\%([A-Za-z0-9_.]\)\@<!\d\+\%([A-Za-z0-9_.]\)\@!/
syntax match rockskunkInvalidFloat /\%([A-Za-z0-9_.]\)\@<!\d\+\.\d\+\%([A-Za-z0-9_f]\)\@!/
syntax match rockskunkFloat /\%([A-Za-z0-9_.]\)\@<!\d\+f\%([A-Za-z0-9_]\)\@!/
syntax match rockskunkFloat /\%([A-Za-z0-9_.]\)\@<!\d\+\.\d\+f\%([A-Za-z0-9_]\)\@!/

" ---- index syntax ----
" array{1} float element -- only when { is glued to the identifier
syntax region rockskunkIndexFloat matchgroup=rockskunkIndexDelim start=/\%(\w\)\@<={/ end=/}/ oneline contains=rockskunkInteger,rockskunkFloat,rockskunkInvalidFloat,rockskunkVariable,rockskunkArith,rockskunkComment
" array<1> string element -- only when < is glued to the identifier (spec-only, not implemented yet)
syntax region rockskunkIndexString matchgroup=rockskunkIndexDelim start=/\%(\w\)\@<=</ end=/>/ oneline contains=rockskunkInteger,rockskunkVariable,rockskunkArith
" array![1] byte element
syntax match rockskunkIndexByte /\%(\w\)\@<=!\ze\[/

" ---- keywords ----
" F P W IF E BREAK LOCATE CALL ADD DO LF LW are matched case-sensitively,
" uppercase-exact, by the real lexer's keyword table -- true standalone
" reserved words regardless of context (yes, this means a variable
" genuinely named e.g. "F" or "DO" would confuse the real compiler too;
" that's the actual language, not a highlighting quirk).
syntax keyword rockskunkFuncKeyword F P
syntax keyword rockskunkRepeat LF LW DO LOCATE
syntax keyword rockskunkConditional W IF E
syntax keyword rockskunkStatement BREAK
" 'until' is not actually a checked keyword -- loopFor() blindly consumes
" whatever token sits there without validating it says "until". Kept as
" a highlight purely for readability/convention, not real enforcement.
syntax keyword rockskunkRepeat until
" reserved: tokenize as keywords but have no working dispatch handler yet
syntax keyword rockskunkReserved CALL
syntax match rockskunkInclude /\<ADD\>\ze\s*(/

" logical/bitwise word operators -- real case-sensitivity per the lexer:
" OR/AND only work uppercase (no lowercase lexer path exists for them,
" despite the language README showing lowercase usage in examples).
" NOR/XOR work in either uppercase (keyword table) or lowercase (a
" dedicated triple-char lexer shortcut) -- but not mixed case.
" NOT only works lowercase (the triple-char shortcut is its only path;
" there is no uppercase NOT in the keyword table).
syntax keyword rockskunkLogical OR AND
syntax keyword rockskunkBitwiseWord NOR nor XOR xor not

" ---- return variable ----
syntax match rockskunkReturnVar /\<r\>\ze\s*:/

" ---- function definition name (F/P name() ) ----
syntax match rockskunkFuncName /\%(\<F\>\|\<P\>\)\s\+\zs[A-Za-z_][A-Za-z0-9_]*\ze\s*(/

" ---- type annotation: (a, b: f) / (a: s) ----
syntax match rockskunkTypeSep /:\ze\s*[fs]\%([A-Za-z0-9_]\)\@!/
syntax match rockskunkTypeTag /\%(:\s*\)\@<=[fs]\%([A-Za-z0-9_]\)\@!/

" ---- builtins ----
" real compiler intrinsics (special-cased codegen, not ordinary calls)
syntax match rockskunkBuiltin /\<\%(sys\|printf\|printw\|intToFloat\|floatToInt\)\>\ze\s*(/
" vector ops -- not yet implemented, spec-only
syntax match rockskunkVectorBuiltin /\<\%(v\|vabs\|vsqrt\|vsin\|vcos\|vmin\|vmax\|vfloor\|vceil\)\>\ze\s*(/
" documented streamlining/memory helpers -- not yet implemented, spec-only
syntax match rockskunkBuiltin /\<\%(lint\|brot\|cm\|fm\|align\)\>\ze\s*(/

" ---- assignment operators ----
" plain := is the only form the compiler actually emits today; the rest
" are documented but not yet implemented.
syntax match rockskunkAssign /:=/
syntax match rockskunkAssignStatic /::=/
syntax match rockskunkAssignCompound /:+=\|:\*=\|:-=\|:\/=\|:%=/
syntax match rockskunkAssignVector /:++=\|:\*\*=\|:\/\/=\|:%%=/

" ---- vector / increment operators (spec-only; VADD/VMUL tokens exist but
" have no dispatch case in the compiler yet) ----
syntax match rockskunkVectorOp /++\|--\|\*\*\|\/\/\|%%/
syntax match rockskunkVectorFma /\*+/
syntax match rockskunkIncrement /\%(\w\)\@<=++\ze\s*\%(['});]\|$\)/

" ---- pointers ----
syntax match rockskunkAddressOf /&\ze[A-Za-z_]/

" ---- bitwise / comparison / arithmetic ----
" real symbols per the lexer: $ is bitwise-and, | is bitwise-or,
" << >> are SHL/SHR. & is address-of only, never bitwise.
syntax match rockskunkBitwise /<<\|>>\|\$\||/
syntax match rockskunkCompare /<=\|>=\|<\|>\|=/
syntax match rockskunkArith /[+*/%-]/

" ---- punctuation ----
syntax match rockskunkBlockPunct /[{}]/
syntax match rockskunkBracketPunct /[][]/
syntax match rockskunkParenPunct /[()]/
syntax match rockskunkSeparator /,/

" ---- block / record headers ----
" Defined LAST (after bitwise-or above) so they win priority over a bare
" "|" for their specific cases -- see the ordering note at the top.
"
" V/S/D/R are NOT real standalone keywords -- they only appear in
" acceptedKeywords as part of the two-char |V/|S/|D lexer tokens (and R
" isn't a real lexer token at all yet, records are spec-only). A
" variable legitimately named v, V, s, S, d, D, r, or R elsewhere in the
" file -- very plausible in DSP code (voltage, sample, delay, radius,
" resistance...) -- is just a variable and must NOT be highlighted as a
" keyword. Each letter is matched with a lookbehind requiring it to be
" directly glued to a preceding "|", never as a free-floating keyword.
"
" |V |S |D also require zero whitespace between the pipe and the letter
" -- that matches the real lexer exactly: the double-char check tests
" the literally-adjacent next byte, so "| V" (with a space) genuinely
" tokenizes as bitwise-or then a plain identifier "V", not a block
" header.
"
" No trailing apostrophe is expected after V/S/D/R -- that character is
" always a string quote to the lexer, never a block-header terminator.
syntax match rockskunkBlockBegin /|\ze[VSD]\>/
syntax match rockskunkBlockKeyword /\%(|\)\@<=[VSD]\>/
syntax match rockskunkRecordBegin /|\ze\s*R\>/
syntax match rockskunkRecordKeyword /\%(|\s*\)\@<=R\>/
syntax match rockskunkRecordName /\%(|\s*R\s*\)\@<=[A-Za-z_][A-Za-z0-9_]*/
" a bare | ending a line closes a V/S/D/R block; elsewhere | is bitwise or
syntax match rockskunkBlockEnd /|\s*\%(;.*\)\=$/

" ==== highlighting ====
" Linked to standard groups so this follows whatever colorscheme is
" already active. See rockskunk-hex.vim (bundled alongside this file,
" not auto-loaded) for an exact hex-matched override instead, if you'd
" rather it look identical regardless of colorscheme.

hi def link rockskunkComment          Comment

hi def link rockskunkString           String
hi def link rockskunkEscape           SpecialChar
hi def link rockskunkInvalidEscape    Error

hi def link rockskunkInteger          Number
hi def link rockskunkFloat            Number
hi def link rockskunkInvalidFloat     Error

hi def link rockskunkFuncKeyword      StorageClass
hi def link rockskunkBlockKeyword     StorageClass
hi def link rockskunkRecordKeyword    StorageClass
hi def link rockskunkRecordName       Type
hi def link rockskunkRepeat           Repeat
hi def link rockskunkConditional      Conditional
hi def link rockskunkStatement        Statement
hi def link rockskunkReserved         Keyword
hi def link rockskunkInclude          Include

hi def link rockskunkLogical          Operator
hi def link rockskunkBitwiseWord      Operator

hi def link rockskunkReturnVar        Special

hi def link rockskunkFuncName         Function
hi def link rockskunkFuncCall         Function
hi def link rockskunkBuiltin          Function
hi def link rockskunkVectorBuiltin    Type

hi def link rockskunkVariable         Identifier
hi def link rockskunkMember           Identifier
hi def link rockskunkAccessorDot      Delimiter

hi def link rockskunkTypeSep          Delimiter
hi def link rockskunkTypeTag          StorageClass

hi def link rockskunkAssign           Operator
hi def link rockskunkAssignStatic     Operator
hi def link rockskunkAssignCompound   Operator
hi def link rockskunkAssignVector     Operator

hi def link rockskunkVectorOp         Operator
hi def link rockskunkVectorFma        Operator
hi def link rockskunkIncrement        Operator

hi def link rockskunkAddressOf        Operator
hi def link rockskunkIndexByte        Operator
hi def link rockskunkBitwise          Operator
hi def link rockskunkCompare          Operator
hi def link rockskunkArith            Operator

hi def link rockskunkBlockBegin       Delimiter
hi def link rockskunkBlockEnd         Delimiter
hi def link rockskunkRecordBegin      Delimiter
hi def link rockskunkIndexDelim       Delimiter
hi def link rockskunkBlockPunct       Delimiter
hi def link rockskunkBracketPunct     Delimiter
hi def link rockskunkParenPunct       Delimiter
hi def link rockskunkSeparator        Delimiter

let b:current_syntax = "rockskunk"
