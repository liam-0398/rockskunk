program rockskunk_x64;
uses
    BaseUnix, SysUtils, Unix;

const
    intRegs: array[0..5] of String = ('rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9');
    acceptedKeywords: array[0..14] of String = // MAKE SURE TO UPDATE KEYWORD CHECK WHEN ADDING
    ('ADD', 'V', 'S',
     'F', 'LF', 'LW', 'W', 'IF', 'E', 'P',
     'OR', 'AND', 'NOR', 'XOR', 'CALL');
var
    buf, databuf, textbuf: Array[0..65535] of Char;

    symName, symType: array[0..255] of String;
    symOffset: array[0..255] of Integer;

    tokenKind, tokenValue: Array[0..4096] of String;
    t_line: Array[0..4096] of Integer;

    loop_TLabel: array [0..64] of String;
    loop_ELabel: array [0..64] of String;
    loopDepth: Integer;
    loopBodyNext: Boolean;

    conditional_ELabel: array [0..64] of String;
    conditionalDepth: Integer;
    conditionalBodyNext: Boolean;

    // for capturing return types so assingment to function return knows whats up
    return_FName: array[0..255] of String; 
    return_FType: array[0..255] of String;
    return_FCount: Integer;

    // tracks types and persists with new functions so can fianlly just call func(a, b, c) typeless
    param_FName:  array[0..255] of String;   // which function this param belongs to
    param_FIndex: array[0..255] of Integer;  // which position (0, 1, 2...) within that function
    param_FType:  array[0..255] of String;   
    paramOffset: Array [0..128] of Integer;
    param_FCount: Integer;
    paramPending: Boolean; 

    currentFN: String;
    bytes, fd, fd2, fd3, fd4: CInt;
    filename, output_filename, stdlib_filename, returnAddr: String;

    frameOffset, labelCounter, position, symCount, argCount, tokenCount: Integer;

{
   DO NOT FORGET LIST ====
   REMEMBER REDO ASM OUTPUT PRIMITIVES AND LOOPS
   REMEMBER IMPLMENT CALL WITHOUT TYPES
   ADDR OF AND DEREFERENCE
   LEGNTH PREFIXED QWORD STRINGS WITH NULL TERMINATOR
   W/IF/ELSE
   LOOPS
   ARRAYS
}

// Forward Declarations

function WhoGoesThere(intruder: String): String; forward;
function evaluateExpression(isFloat: Boolean): String; forward;

// HELPERS =================================================
// ========================================================

procedure writeOut(s: String); begin fpWrite(fd2, s[1], Length(s)); end;
procedure writeText(s: String); begin fpWrite(fd3, s[1], Length(s)); end;
procedure writeData(s: String); begin fpWrite(fd4, s[1], Length(s)); end;

function keywordCheck(word: String): Boolean; // Flag keywords
var
    i: Integer;
begin
    keywordCheck := False;
    for i := 0 to 14 do
        begin
            if word = acceptedKeywords[i] then 
                begin
                    keywordCheck := True;
                    break;
                end;
        end;
end;

function isNumber(token: String): Boolean;
var
    i, last: Integer;
begin
    isNumber := False;
    last := Length(token);
    if token[last] = 'f' then    // Not counting the f was pissing off the loop for multiple expressions
        Dec(last);

    isNumber := True;
    for i := 1 to last do
        if not (token[i] in ['0'..'9', '.']) then
            isNumber := False;
end;

function isFloatLiteral(token: String): Boolean;
begin
    if isNumber(token) then
        isFloatLiteral := (Pos('.', token) > 0) or (Pos('f', token) > 0)
    else
        isFloatLiteral := False;
end;

function labelMaker(prefix: String): String;
begin
    labelMaker := prefix + IntToStr(labelCounter);
    Inc(labelCounter)
end;

procedure openFile;
var
    libBytes: CInt;
begin
    {WriteLn('LOADING STANDARD LIBRARY');
    FillChar(buf, SizeOf(buf), 0);
    fd := fpOpen(stdlib_filename, O_RdOnly);
    libBytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);}

    WriteLn('LOADING SOURCEFILE LIBRARY');
    fd := fpOpen(filename, O_RdOnly);
    bytes := FpRead(fd, buf[libBytes], SizeOf(buf) - libBytes);
    fpClose(fd);

    bytes := bytes + libBytes;
end;

procedure openIntermediateFile; // open temp sourcefile
begin
    fd3 := fpOpen('text.tmp',O_WRONLY OR O_CREAT OR O_TRUNC, 438);
    fd4 := fpOpen('data.tmp',O_WRONLY OR O_CREAT OR O_TRUNC, 438);
    FillChar(databuf, SizeOf(databuf), 0);
    FillChar(textbuf, SizeOf(textbuf), 0);
end;

procedure writeASM; // Write to real intermediate.asm that is compiled by NASM
var
    dbytes, tbytes: cint;
begin
    fd2 := fpOpen('intermediate.asm',O_WRONLY OR O_CREAT OR O_TRUNC, 438);

    fd4 := fpOpen('data.tmp', O_RdOnly, 438);
    WriteOut('section .bss' + #10);
    WriteOut('   digitbuf: resb 32' + #10);
    WriteOut(#10 + 'section .data' + #10);
    dbytes := fpRead(fd4, databuf, SizeOf(databuf));
    fpWrite(fd2, databuf, dbytes);
    fpClose(fd4);

    WriteOut(#10 + 'section .text' + #10);
    fd3 := fpOpen('text.tmp', O_RdOnly, 438);
    tbytes := fpRead(fd3, textbuf, SizeOf(textbuf));
    fpWrite(fd2, textbuf, tbytes);
    fpClose(fd3);

    fpClose(fd2);
end;

procedure closeIntermediateFile; begin fpClose(fd3); fpClose(fd4); end;

// CODE GENERATION ===========================================
// ========================================================

// HELPERS ----------------------------------------------------------

procedure loadRAX(addr: String); begin WriteText('    mov rax, ' + addr + #10); end;
procedure loadRBX(addr: String); begin WriteText('    mov rbx, ' + addr + #10); end;
procedure loadXMM0(addr: String); begin WriteText('    movsd xmm0, ' + addr + #10); end;

// FUNCTIONS -----------------------------------------------------------
procedure emitFN(fname : String);
begin 
    WriteText(fname + ':' + #10);
end;

procedure emitFunctionSetup();
begin 
    WriteText('    push rbp' + #10);
    WriteText('    mov rbp, rsp' + #10);
    WriteText('    sub rsp, 128' + #10);
end;

procedure emitFunctionTeardown(result: String; isProcedure: Boolean);
var
    rcheck: String;
    isFloat: Boolean;
begin
    if not isProcedure then // just ignore all this and do not return anything if its a procedure
        begin
            isFloat := False;
            rcheck := WhoGoesThere(currentFN);
            if rcheck = 'FLOAT' then
                isFloat := True;

            if not isFloat then
                WriteText('    mov rax, ' + result + #10)
            else
                WriteText('    movsd xmm0, ' + result + #10);
        end;

    WriteText('    add rsp, 128' + #10);
    WriteText('    pop rbp' + #10);
    WriteText('    ret' + #10 + #10);
end;

// CONTROL FLOW -----------------------------------------------------------

procedure emitLabel(labelname: String); begin WriteText(labelname + ':' + #10) end;

// ASSIGNMENT -----------------------------------------------------------
procedure emitAssign(variable : String; value : String);
begin
    if value <> 'rax' then
        WriteText('    mov rax, ' + value + #10); // if i didnt do this i get mov rax, rax
    WriteText('    mov ' + variable + ', rax' + #10);
end;

procedure emitAssignFloat(variable : String; value : String);
begin
    if value <> 'xmm0' then
        WriteText('    movsd xmm0, ' + value + #10); // if i didnt do this i get mov rax, rax
    WriteText('    movsd ' + variable + ', xmm0' + #10);
end;

function emitFloatConstant(float: String): String;
begin
        WriteData('   float_' + IntToStr(labelCounter) + ': dq ' + float + #10);
        emitFloatConstant := 'float_' + IntToStr(labelCounter);
        Inc(labelCounter);
end;

// ARRAYS / MEMORY -----------------------------------------------------------

function emitAddressOf(variable: String): String; // &a
begin 
        WriteText('    lea rax, ' + variable + #10);
        emitAddressOf := 'rax';
end;         

procedure emitMalloc(); begin end;            // cm(size)
procedure emitFree(); begin end;              // fm(p)

// MATH -----------------------------------------------------------
procedure emitAdd(dst, src: String); begin WriteText('    add ' + dst + ', ' + src + #10); end;
procedure emitSub(dst, src: String); begin WriteText('    sub ' + dst + ', ' + src + #10); end;
procedure emitMul(dst, src: String); begin WriteText('    imul ' + dst + ', ' + src + #10); end;

procedure emitDiv(dividend, divisor: String);
begin
        // Divide by zero and see what happens lol
        WriteText('    mov rax, ' + dividend + #10);
        WriteText('    cqo' + #10);
        WriteText('    idiv qword ' + divisor + #10);
end;

procedure emitMod(); begin end;

procedure emitAddFloat(dst, src: String); begin WriteText('    addsd ' + dst + ', ' + src + #10); end;
procedure emitSubFloat(dst, src: String); begin WriteText('    subsd ' + dst + ', ' + src + #10); end;
procedure emitMulFloat(dst, src: String); begin WriteText('    mulsd ' + dst + ', ' + src + #10); end;

procedure emitDivFloat(dividend, divisor: String);
begin
    begin
        WriteText('    movsd xmm0, ' + dividend + #10);
        WriteText('    divsd xmm0,' + divisor + #10);
    end;
end;

procedure emitModFloat(); begin end;

// SYSTEM ----------------------------------

function emitSyscall(num: String; a: String; b: String; c: String): String;
begin 
    WriteText('    mov rax, ' + num + #10);
    WriteText('    mov rdi, ' + a + #10);
    WriteText('    mov rsi, ' + b + #10);
    WriteText('    mov rdx, ' + c + #10);
    WriteText('    syscall ' + #10);
    emitSyscall := 'rax';
end; 

procedure functionPrintW(source: String);
begin
    WriteText('    mov rax, ' + source + #10);
    WriteText('    call print_qword' + #10);

end;

procedure functionPrintF(source: String);
begin
    WriteText('    movsd xmm0, ' + source + #10);
    WriteText('    call print_float' + #10);
end;

procedure asmFoundations();
begin
    // placed at bottom for file
    WriteText(#10 + 'global _start' + #10);  // entry point so linker can do linker things
    WriteText('_start:'+ #10);
    WriteText('  call main'+ #10);
    WriteText('  mov rdi, rax'+ #10);
    WriteText('  mov rax, 60'+ #10);
    WriteText('  syscall'+ #10);

    // print_qword function NASM no space for float use
    // word is in rax
    // NOT MY WORK NEED TO REWRITE WHEN I KNOW MORE ASM> FOR DEBUGGING ONLY ===========
    WriteText(#10 + 'print_qword_nosp:' + #10);        // print integer, no trailing space
    WriteText('    mov rsi, digitbuf + 20' + #10);      // point past the end of the buffer
    WriteText('    mov rcx, 0' + #10);                   // digit counter
    WriteText('    cmp rax, 0' + #10);
    WriteText('    jne .pqn_loop' + #10);
    WriteText('    dec rsi' + #10);
    WriteText('    mov byte [rsi], 48' + #10);           // just write '0'
    WriteText('    inc rcx' + #10);
    WriteText('    jmp .pqn_done' + #10);
    WriteText('.pqn_loop:' + #10);
    WriteText('    cmp rax, 0' + #10);
    WriteText('    je .pqn_done' + #10);
    WriteText('    cqo' + #10);
    WriteText('    mov rbx, 10' + #10);
    WriteText('    idiv rbx' + #10);
    WriteText('    add rdx, 48' + #10);                  // remainder -> ASCII digit
    WriteText('    dec rsi' + #10);
    WriteText('    mov [rsi], dl' + #10);
    WriteText('    inc rcx' + #10);
    WriteText('    jmp .pqn_loop' + #10);
    WriteText('.pqn_done:' + #10);
    WriteText('    mov rax, 1' + #10);                   // syscall: write
    WriteText('    mov rdi, 1' + #10);                   // fd: stdout
    WriteText('    mov rdx, rcx' + #10);                 // length = digit count
    WriteText('    syscall' + #10);
    WriteText('    ret' + #10 + #10);
    // print_qword function NASM
    // word is in rax
    // NOT MY WORK NEED TO REWRITE WHEN I KNOW MORE ASM> FOR DEBUGGING ONLY ===========
    WriteText(#10 + 'print_qword:' + #10);
    WriteText('    mov rsi, digitbuf + 20' + #10);      // point past the end of the buffer
    WriteText('    mov rcx, 0' + #10);                   // digit counter
    WriteText('    cmp rax, 0' + #10);
    WriteText('    jne .pq_loop' + #10);
    WriteText('    dec rsi' + #10);
    WriteText('    mov byte [rsi], 48' + #10);           // just write '0'
    WriteText('    inc rcx' + #10);
    WriteText('    jmp .pq_done' + #10);
    WriteText('.pq_loop:' + #10);
    WriteText('    cmp rax, 0' + #10);
    WriteText('    je .pq_done' + #10);
    WriteText('    cqo' + #10);
    WriteText('    mov rbx, 10' + #10);
    WriteText('    idiv rbx' + #10);
    WriteText('    add rdx, 48' + #10);                  // remainder -> ASCII digit
    WriteText('    dec rsi' + #10);
    WriteText('    mov [rsi], dl' + #10);
    WriteText('    inc rcx' + #10);
    WriteText('    jmp .pq_loop' + #10);
    WriteText('.pq_done:' + #10);
    WriteText('    mov rax, 1' + #10);                   // syscall: write
    WriteText('    mov rdi, 1' + #10);                   // fd: stdout
    WriteText('    mov rdx, rcx' + #10);                 // length = digit count
    WriteText('    syscall' + #10);
    WriteText('    mov rax, 32' + #10);                  // ASCII space
    WriteText('    mov [digitbuf], al' + #10);
    WriteText('    mov rax, 1' + #10);                   // syscall: write
    WriteText('    mov rdi, 1' + #10);                   // fd: stdout
    WriteText('    mov rsi, digitbuf' + #10);
    WriteText('    mov rdx, 1' + #10);                   // length = 1
    WriteText('    syscall' + #10);                      // print separator space
    WriteText('    ret' + #10 + #10);
    // NOT MY WORK NEED TO REWRITE WHEN I KNOW MORE ASM> FOR DEBUGGING ONLY ===========

        // print_float - value in xmm0
    // NOT MY WORK NEED TO REWRITE WHEN I KNOW MORE ASM. FOR DEBUGGING ONLY ===========
    WriteText(#10 + 'print_float:' + #10);
    WriteText('    cvttsd2si rax, xmm0' + #10);        // integer part -> rax
    WriteText('    push rax' + #10);                    // save it
    WriteText('    cvtsi2sd xmm1, rax' + #10);          // int part back to float
    WriteText('    subsd xmm0, xmm1' + #10);            // xmm0 = fractional part
    WriteText('    mov rax, 1000' + #10);
    WriteText('    cvtsi2sd xmm1, rax' + #10);
    WriteText('    mulsd xmm0, xmm1' + #10);            // frac * 1000
    WriteText('    cvtsd2si rbx, xmm0' + #10);          // frac digits -> rbx, ROUNDED not truncated
    WriteText('    pop rax' + #10);                     // restore integer part
    WriteText('    push rbx' + #10);                    // stash frac again
    WriteText('    call print_qword_nosp' + #10);            // print integer part
    WriteText('    mov rax, 46' + #10);                 // ASCII '.'
    WriteText('    mov [digitbuf], al' + #10);
    WriteText('    mov rax, 1' + #10);
    WriteText('    mov rdi, 1' + #10);
    WriteText('    mov rsi, digitbuf' + #10);
    WriteText('    mov rdx, 1' + #10);
    WriteText('    syscall' + #10);                     // print '.'
    WriteText('    pop rax' + #10);                     // frac digits
    WriteText('    call print_frac3' + #10);            // print them, zero padded to 3
    WriteText('    mov rax, 32' + #10);                 // ASCII space
    WriteText('    mov [digitbuf], al' + #10);
    WriteText('    mov rax, 1' + #10);
    WriteText('    mov rdi, 1' + #10);
    WriteText('    mov rsi, digitbuf' + #10);
    WriteText('    mov rdx, 1' + #10);
    WriteText('    syscall' + #10);                     // print separator space
    WriteText('    ret' + #10 + #10);

    // print_frac3 - value 0..999 in rax, always prints exactly 3 digits
    // needed because print_qword drops leading zeros, so 0.05 printed as ".5"
    WriteText(#10 + 'print_frac3:' + #10);
    WriteText('    mov rsi, digitbuf + 3' + #10);       // one past the 3 digit field
    WriteText('    mov rcx, 3' + #10);                  // always write 3, no early exit
    WriteText('.pf_loop:' + #10);
    WriteText('    cqo' + #10);
    WriteText('    mov rbx, 10' + #10);
    WriteText('    idiv rbx' + #10);                    // rax = quotient, rdx = remainder
    WriteText('    add rdx, 48' + #10);                 // remainder -> ASCII digit
    WriteText('    dec rsi' + #10);
    WriteText('    mov [rsi], dl' + #10);
    WriteText('    dec rcx' + #10);
    WriteText('    jnz .pf_loop' + #10);                // loop exactly 3 times, zeros included
    WriteText('    mov rax, 1' + #10);                  // syscall: write
    WriteText('    mov rdi, 1' + #10);                  // fd: stdout
    WriteText('    mov rsi, digitbuf' + #10);
    WriteText('    mov rdx, 3' + #10);                  // fixed length 3
    WriteText('    syscall' + #10);
    WriteText('    ret' + #10 + #10);

end;

// PARSER =================================================
// ========================================================
// Helpers ------------------------------------

// Used to check type (identifier) and value of words for decision making
function peekV(): String; begin peekV := tokenValue[position]; end;
function peekV2(): String; begin peekV2 := tokenValue[position+1]; end;
function peekV3(): String; begin peekV3 := tokenValue[position+2]; end;
function peek(): String; begin peek := tokenKind[position]; end;
function peek2(): String; begin peek2 := tokenKind[position+1]; end;
function peek3(): String; begin peek3 := tokenKind[position+2]; end;
function currentLine(): String; begin currentLine := intToStr(t_line[position]); end;
function computeOffset(offset: Integer): String; begin computeOffset := '[rbp-' + IntToStr(offset) + ']'; end;

function consume(): String; // Eat the next token and then remove it
begin
    consume := tokenValue[position]; // pull value (actual content of token)
    Inc(position);  // Increment counter to drop the token
end;

function arrayToMem(varname: String; size: String; vartype: String): String;
begin
end;

function varToMem(variable: String): String;
var
    i: Integer;
begin
    varToMem := ''; 
    for i := 0 to symCount - 1 do
        begin
            if symName[i] = variable then
                VarToMem := '[rbp-' + IntToStr(symOffset[i]) + ']';
        end;
    if varToMem = '' then
        begin    
            WriteLn('I CANT BELIEVE YOUVE DONE THIS - VAR_TO_MEM - UNK SYMBOL>> ' + variable);
            Halt(1); // Loop for multiple opererators was getting pissed becuase '+' was making its way into here
        end;
end;

function call(fname: String; first: String; returnsFloat: Boolean): String;
begin
          if returnsFloat then
            begin
                WriteText('    call ' + fname + #10);
                first := 'xmm0';
                call := 'xmm0';
            end
        else
            begin
                WriteText('    call ' + fname + #10);
                first := 'rax';
                call := 'rax';
            end;
end;

function emitMath(op: String; second: String; isFloat: Boolean): String;
begin
    if isFloat then emitMath := 'xmm0' else emitMath := 'rax';

    if isFloat then
        begin
            if      op = 'PLUS'  then emitAddFloat('xmm0', second)
            else if op = 'MINUS' then emitSubFloat('xmm0', second)
            else if op = 'STAR'  then emitMulFloat('xmm0', second)
            else if op = 'SLASH' then emitDivFloat('xmm0', second)
            else
                begin
                    WriteLn('I CANT BELIEVE YOUVE DONE THIS - EMIT_MATH - UNK OP >> ' + op);
                    Halt(1);
                end;
        end
    else
        begin
            if      op = 'PLUS'  then emitAdd('rax', second)
            else if op = 'MINUS' then emitSub('rax', second)
            else if op = 'STAR'  then emitMul('rax', second)
            else if op = 'SLASH' then emitDiv('rax', second)
            else
                begin
                    WriteLn('I CANT BELIEVE YOUVE DONE THIS - EMIT_MATH - UNK OP >> ' + op);
                    Halt(1);
                end;
        end;
end;

procedure asmFunctionCalls(variable: String; argname: String);
begin
    if (variable = 'printw') or (variable = 'printf') then
        begin
            consume; // (
            argname := consume(); // the value to print
            if not isNumber(argname) then
                argname := varToMem(argname);
            consume; // )
                if variable = 'printf' then
                    functionPrintF(argname);
                if variable = 'printw' then
                    functionPrintW(argname)
                else
                    begin
                        WriteLn('I CANT BELIEVE YOUVE DONE THIS - ASMFUNC- INVALID CALL >> ' + variable);
                        Halt(1);
                    end;
        end
    else
        WriteText('call ' + variable + #10);
end;

function foldCode(first: String; isFloat: boolean): String;
var
    result1: Double;
    result2: Integer;
    second, op: String;
begin
            op := peek(); // Operator
            consume;
            second := consume; // Operand
            WriteLn('OPTIMIZATION');

            if isFloat then
                begin
                if op = 'PLUS' then result1 := StrToFloat(first) + StrToFloat(second)
                else if op = 'MINUS' then result1 := StrToFloat(first) - StrToFloat(second)
                else if op = 'STAR' then result1 := StrToFloat(first) * StrToFloat(second)
                else if op = 'SLASH' then result1 := StrToFloat(first) / StrToFloat(second);      
                foldCode := (FloatToStr(result1));
                end 
            else
                begin
                if op = 'PLUS' then result2 := StrToInt(first) + StrToInt(second)
                else if op = 'MINUS' then result2 := StrToInt(first) - StrToInt(second)
                else if op = 'STAR' then result2 := StrToInt(first) * StrToInt(second)
                else if op = 'SLASH' then result2 := StrToInt(first) div StrToInt(second);
                foldCode := (IntToStr(result2));
            end;
end;

function opResolver(misformattedBastard: String): String;
var
    isFloat: Boolean;
begin
    isFloat := False;  // THROW IN ISFLOTLIT CHECK LATER

    if (Length(misformattedBastard) > 0) and (misformattedBastard[1] = '[') then
        begin
            opResolver := misformattedBastard; 
            Exit;
        end;

    if (Pos('.', misformattedBastard) > 0) or (Pos('f', misformattedBastard) > 0) then
                        isFloat := True;

    if not isFloat then
            Exit(misformattedBastard)
    else
        begin
            if misformattedBastard[Length(misformattedBastard)] = 'f' then misformattedBastard := copy(misformattedBastard, 1, Length(misformattedBastard) - 1); // strip f from float
            opResolver := '[' + emitFloatConstant(misformattedBastard) + ']';
        end;
end;

function ifFloatIfVar(second: String): String;
begin
        if isFloatLiteral(second) then
            ifFloatIfVar := opResolver(second)
        else if not isNumber(second) then    
            ifFloatIfVar := varToMem(second)
        else
            ifFloatIfVar := second; // if its just a lowly number
end;

function WhoGoesThere(intruder: String): String;
var
    isFloat: Boolean;
    i: Integer;
begin
    i := 0;
    isFloat := False;

    if isNumber(intruder) then // RAW NUM
        begin
        if Pos('.', intruder) > 0 then
            isFloat := True;
        end
    else
        begin // VAR
            for i := 0 to symCount - 1 do
                begin
                    if intruder = symName[i] then
                        if symType[i] = 'FLOAT' then
                            isFloat := True;
                end;
    end;
  
    for i := 0 to return_FCount - 1 do // Function
        begin
            if intruder = return_FName[i] then
                if return_FType[i] = 'FLOAT' then
                    isFloat := True;
        end;

    if isFloat then WhoGoesTHere := 'FLOAT' else WhoGoesTHere := 'QWORD';

end;

function resolveSyscall(): String;
var
    argument: String;
begin
    if peek() = 'AMP' then
        begin
            consume;
            resolveSyscall:= emitAddressOf(varToMem(consume));
        end
    else
        begin
            argument := consume;
            if isNumber(argument) then
                resolveSyscall:= argument
            else
                resolveSyscall:= varToMem(argument);
        end;
end;

// MAIN PARSER MACHINERY ====================================================

function argumentParser(argname, fname, first: String; returnsFloat: Boolean; argfindex: Integer): String;
var
    seenFloats, seenInts, argCounter: Integer;
    isFloatArg: Boolean;
begin
        WriteLn('ARGUMENT PARSER'); // DEBUG
        argcounter := 0;
        seenFloats := 0;
        seenInts := 0;
        repeat  // VERIFY LOOP
            isFloatArg := False;
            argname := consume(); // single arg

            if param_FType[argfindex + argcounter] = 'FLOAT' then
                isFloatArg := True;

            if not isNumber(argname) then
                argname := varToMem(argname);

            if isFloatArg then
                begin
                    WriteText('    movsd xmm' + IntToStr(seenFloats) + ', ' + argname + #10);
                    Inc(seenFloats);
                end
            else
                begin
                    WriteText('    mov ' + intRegs[seenInts] + ', ' + argname + #10);
                    Inc(seenInts);
                end;

            if peek() = 'COMMA' then
                consume;

            Inc(argcounter);
        until peek() = 'RPAR';
        consume(); // )
        argumentParser := call(fname, first, returnsFloat);
end;

function evaluateExpression(isFloat: Boolean): String;
var
    first, second, op, argname, fname, return, math_ret, call_ret, ampaddr: String;
    num, a, b, c: String;
    returnsFloat: Boolean;
    i, argfindex: Integer;
begin
    i := 0;
    first := '';
    argname := '';
    returnsFloat := False;

    if peek() = 'AMP' then
        begin
            consume;
            ampaddr := VarToMem(consume);
            Exit(emitAddressOf(ampaddr));
        end;

    if (peekV() = 'sys') and (peek2() = 'LPAR') then
        begin
            consume; consume; 
            num := resolveSyscall(); consume;
            a := resolveSyscall(); consume;
            b := resolveSyscall(); consume;
            c := resolveSyscall(); consume;
            Exit(emitSyscall(num, a, b, c));
        end;

    if (peek() = 'IDENTIFIER') and (peek2() = 'LPAR') then 
    begin
        fname := consume(); 

        if WhoGoesThere(fname) = 'FLOAT' then
            returnsFloat := True;

        for i := 0 to param_FCount - 1 do
            if fname = param_FName[i] then
                begin
                    argfindex := param_FIndex[i];
                    break;
                end;

        consume(); // (
        if peek() <> 'RPAR' then
            begin
                call_ret := argumentParser(argname, fname, first, returnsFloat, argfindex);
            end;

        Exit(call_ret);
        end
    else
        begin
            WriteLn('EXPRESSION EVAL - NOT OPERATOR BRANCH'); // DEBUG
            first := consume; // first operand (the a in a + b)

            if isFloatLiteral(first) then
                first := opResolver(first)
            else if not isNumber(first) then // look up addr if identifier
                        first := varToMem(first);

            if isNumber(first) and (peek2() = 'NUMBER') then // fold the code if 5 + 5, 5 * 5
                begin
                    return := foldCode(first, isFloat);
                    Exit(return);
                end;
                
            first := opResolver(first);

            // if next token isnt operator return the first operand eg if var := 5 not var := 5 + b
            if not ((peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH')) then
                evaluateExpression := first
            else
                begin
                    WriteLn('EXPRESSION EVAL - OPERATOR BRANCH');

                    if isFloat then
                        loadXMM0(first) // floats need Xtra Math Man
                    else
                        loadRAX(first); 

                    // BEHOLD THE CHAINER OR OPERATORS, SOLVER OF EXPRESSIONS
                    while ((peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH')) do 
                        begin
                            op := peek(); 
                            consume;
                            second := consume(); 
                            second := ifFloatIfVar(second); // resolve assignment of var
                            
                            math_ret := emitMath(op, second, isFloat);
                        end;
                    Exit(math_ret)
                end;
        end;   
end;

procedure discriminateIdentifier();
var
    variable, rightside, twoname, argname: String;
    isDeclared, isReturn, isFloat: boolean;
    i, ii, symIndex: Integer;
begin
    i := 0;
    ii := 0;
    symIndex := 0;
    isDeclared := False;
    isReturn := False;
    isFloat := False;

    variable := consume(); // consume the a in a := 5

    if variable = 'r' then isReturn := True;

    //WriteLn('discrim start: variable=' + variable + ' position=' + IntToStr(position)); // DEBUG

    for i := 0 to 255 do  // scan to see if var is delclred already
        begin
            if symName[i] = variable then
                begin
                    isDeclared := True;
                    symIndex := i;
                    if symType[i] = 'FLOAT' then // if its a float take the float path
                        isFloat := True;
                end;
        end;

    if peek() = 'ASSIGN' then // if its a := x etc etc
        begin
            if isDeclared = True then
                begin // turn into something nasm understands instead of just "variable"
                    variable := computeOffset(symOffset[symIndex]);
                    consume(); // :=
                        if symType[symIndex] = 'FLOAT' then
                                begin
                                rightside := evaluateExpression(isFloat);
                                emitAssignFloat(variable, rightside); // emit asm
                                end
                            else
                                begin
                                rightside := evaluateExpression(isFloat);
                                emitAssign(variable, rightside);
                                end;
                        WriteLn('ASSIGN BRANCH - DECLARED'); // DEBUG
                end
            else
                begin
                    frameOffset := frameOffset + 8; // vars need to occupy different memory, increment

                    if peek2() = 'FLOAT' then // determine what it is and make it so
                        symType[symCount] := 'FLOAT';
                    if peek2() = 'NUMBER' then
                        symType[symCount] := 'NUMBER';
                    if peek2() = 'IDENTIFIER' then
                        begin
                            twoname := peekV2();
                            for ii := 0 to symCount-1 do 
                                begin
                                    if symName[ii] = twoname then
                                        symType[symCount] := symType[ii];
                                end;
                        end;

                    if (peek2() = 'IDENTIFIER') and (peek3() = 'LPAR') then
                        begin
                            twoname := peekV2();
                            for ii := 0 to symCount-1 do 
                                begin
                                    if return_FName[ii] = twoname then
                                        symType[symCount] := return_FType[ii];
                                end;
                        end;
                    
                    isFloat := (symType[symCount] = 'FLOAT');
                        symOffset[symCount] := frameOffset;
                        symName[symCount] := variable;
                        variable := computeOffset(symOffset[symCount]);

                    if isReturn then
                        begin
                        return_FName[return_FCount] := currentFN;
                        return_FType[return_FCount] := symType[symCount];
                        variable := computeOffset(symOffset[symCount]);
                        returnAddr := computeOffset(symOffset[symCount]);
                        inc(return_FCount);
                        end;

                        inc(symCount);
                        consume(); // :=
                        

                    if isFloat then // send to expression evaulator to find out what to do to right side
                        begin
                          rightside := evaluateExpression(isFloat);
                          emitAssignFloat(variable, rightside);
                        end
                    else
                        begin
                            rightside := evaluateExpression(isFloat);
                            emitAssign(variable,rightside);
                         end;
                        WriteLn('ASSIGN BRANCH - UNDECLARED'); // DEBUG
                    end;
        end
        else
            begin //REPLACE THEESE
               asmFunctionCalls(variable, argname);
            end;
end;

// ONE-OFFS ------------
// all of these are completely broken
procedure conditionalIntrinsic(); begin end;

function loopWhile(): Boolean;
var
    loopvar, loopcond, looplimit, toplabel, endlabel: String;
begin
    consume; //consume LW 
    consume; // consume LPAR
    loopvar := varToMem(consume);
    loopcond := peek; // grab TYPE not the damn value
    consume; // now eat it
    looplimit := consume;
    consume; // RPAR
    toplabel := labelMaker('LW');
    endlabel := labelMaker('LW');
    emitLabel(toplabel); // it is I, the start of the loop
    //loop_TLabelW[loop_IndexW] := toplabel;
    //loop_ELabelW[loop_IndexW] := endlabel;

    WriteText('    mov rax, ' + loopvar + #10);    
    WriteText('    cmp rax, ' + looplimit + #10);    
    
    if loopcond = 'LESSEQUAL' then  // all the shit is backwards here
        WriteText('    jg ' + endlabel + #10)       // jump if greater (i > limit)
    else if loopcond = 'LESS' then
        WriteText('    jge ' + endlabel + #10)      // jump if greater or equal
    else if loopcond = 'GREQUAL' then
        WriteText('    jl ' + endlabel + #10)       // jump if less
    else if loopcond = 'GREATER' then
        WriteText('    jle ' + endlabel + #10)      // jump if less or equal
    else if loopcond = 'EQUAL' then
        WriteText('    jne ' + endlabel + #10);     // jump if not equa  

    //inc(loop_IndexW);
    loop_TLabel[loopDepth] := toplabel;
    loop_ELabel[loopDepth] := endlabel;
    Inc(loopDepth);
    loopBodyNext := True;
end;

function loopFor(): Boolean;
var
    loopvar, loopstart, looplimit, toplabel, endlabel: String;
begin
    consume; //consume LF
    consume; // consume LPAR
    loopvar := varToMem(consume);
    consume; // :=
    loopstart := consume; // 0
    consume; // until
    looplimit := consume; 
    consume; // RPAR
    WriteText('    mov rax, ' + loopstart + #10);
    WriteText('    mov ' + loopvar + ', rax' + #10);

    toplabel := labelMaker('LF');
    endlabel := labelMaker('LF');
    emitLabel(toplabel);

    WriteText('    mov rax, ' + loopvar + #10);
    WriteText('    cmp rax, ' + looplimit + #10);
    WriteText('    jge ' + endlabel + #10);

    loop_TLabel[loopDepth] := toplabel;
    loop_ELabel[loopDepth] := endlabel;
    Inc(loopDepth);
    loopBodyNext := True;
end;

function condWhen(): Boolean;
var
    condvar, condition, condlimit, endlabel: String;
begin
    consume; //consume W
    consume; // consume LPAR
    condvar := varToMem(consume);
    condition := peek; // grab TYPE not the damn value
    consume; // now eat it
    condlimit := consume; // 0
    consume; // RPAR

    endlabel := labelMaker('W');

    WriteText('    mov rax, ' + condvar + #10);
    WriteText('    cmp rax, ' + condlimit + #10);

    if condition = 'LESSEQUAL' then  // all the shit is backwards here
        WriteText('    jg ' + endlabel + #10)       // jump if greater (skip when i > limit)
    else if condition = 'LESS' then
        WriteText('    jge ' + endlabel + #10)      // jump if greater or equal
    else if condition = 'GREQUAL' then
        WriteText('    jl ' + endlabel + #10)       // jump if less
    else if condition = 'MORE' then
        WriteText('    jle ' + endlabel + #10)      // jump if less or equal
    else if condition = 'EQUAL' then
        WriteText('    jne ' + endlabel + #10);     // jump if not equal

    conditional_ELabel[conditionalDepth] := endlabel;
    Inc(conditionalDepth);
    conditionalBodyNext := True;
    condWhen := True;
end;

function constructFunction(): Boolean;
var
    i: Integer;
begin
                constructFunction := (peek() = 'P');
                consume;
                currentFN := consume;
                emitFN(currentFN);
                frameOffset := 0;
                argCount := 0;
                symCount := 0;
                    for i := 0 to 255 do
                        begin
                            symName[i] := '';
                            symOffset[i] := 0;
                            symType[i] := '';
                        end;
                paramPending := False;
                if peek() = 'LPAR' then // arg detection
                    begin
                        consume; // (
                        if peek() <> 'RPAR' then 
                        begin
                        repeat 
                                frameOffset := frameOffset + 8;
                                symOffset[symCount] := frameOffset;
                                param_FName[param_FCount] := currentFN;
                                symName[symCount] := consume(); // grab param name
                                symType[symCount] := 'NUMBER'; // int param for now
                                param_FType[param_FCount] := 'NUMBER';
                                param_FIndex[param_FCount] := param_FCount;
                                inc(symCount);
                                    if peek() = 'COLON' then
                                        begin        
                                            consume; // consume colon
                                            if peekV() = 'f' then
                                                begin
                                                    symType[symCount - 1] := 'FLOAT'; // int param for now
                                                    param_FType[param_FCount - 1] := 'FLOAT';
                                                    consume; // consume f
                                                end
                                            else
                                                begin
                                                    // STRING EVENTUALLY
                                                end;
                                        end;
                                paramPending := True;
                                paramOffset[argCount] := frameOffset;
                                inc(argCount);
                                inc(param_FCount);
                                if peek() = 'COMMA' then
                                        consume;
                            until peek() = 'RPAR';
                    end;
                        consume; // )     
         end;
end;

// PARSER -----------

procedure parser();
var
    isProcedure: Boolean;
    i, seenFloats, seenInts: Integer;
begin
    i := 0;
    position := 0;
    repeat
        case peek() of
            'F', 'P': begin 
                isProcedure := constructFunction();
            end;
            'LPAR': begin
                consume; // PLACEHOLDER
            end;
            'RPAR': begin 
                consume; // PLACEHOLDER
            end;
           'LBRACE': begin 
                consume;
                if loopBodyNext or conditionalBodyNext then
                    begin
                        loopBodyNext := False;
                        conditionalBodyNext := False;
                    end
                    else
                        begin
                            emitFunctionSetup();
                            if paramPending then
                                begin
                                    seenFloats := 0;
                                    seenInts := 0;
                                    for i := 0 to argCount - 1 do
                                        begin
                                            if symType[i] = 'FLOAT' then
                                                begin
                                                    WriteText('   movsd [rbp-' + intToStr(paramOffset[i]) + '], xmm' + IntToStr(seenFloats) + #10);
                                                    Inc(seenFloats);
                                                end
                                            else
                                                begin
                                                    WriteText('    mov [rbp-' + IntToStr(paramOffset[i]) + '], ' + intregs[seenInts] + #10);
                                                    Inc(seenInts);
                                                end;
                                        end;
                                    paramPending := False;
                                end;
                        end;
                end;
            'RBRACE': begin 
                consume;
                    if loopDepth > 0 then
                        begin
                            Dec(loopDepth);
                            WriteText('    jmp ' + loop_TLabel[loopDepth] + #10);
                            emitLabel(loop_ELabel[loopDepth]);
                        end
                    else if conditionalDepth > 0 then
                        begin
                            Dec(conditionalDepth);
                            emitLabel(conditional_ELabel[conditionalDepth]);
                        end
                    else
                        emitFunctionTeardown(returnAddr, isProcedure);
            end;
            'IDENTIFIER': begin 
                discriminateIdentifier();
            end;
            'ASSIGN': begin 
                consume;
            end;
            'TERMINATOR': begin 
                consume;
            end;
            'V': begin 
                consume;
            end;
            'S': begin 
                consume;
            end;
            'W': begin 
                condWhen();
            end;
            'IF': begin 
                consume;
            end;
            'E': begin 
                consume;
            end;
            'LF': begin 
                loopFor();
            end;
            'LW': begin 
                loopWhile();
            end;
            'VARBLOCK': begin 
                consume; // consume '
            end;
            'STATICBLOCK': begin 
                consume; // consume '
            end;
            'RECORDBLOCK': begin 
                consume; // consume '
            end
            else
            begin
                WriteLn('I CANT BELIEVE YOUVE DONE THIS - PARSER - YOU HAVE FED ME GARBAGE>> ' + peek() + ' ' + peekV());
                Halt(1);
            end;
        
        end;
    until position >= tokenCount;

    asmFoundations();

    end;

// LEXER ==================================================
// ========================================================

procedure lexer();
var
    i, linecount: Integer;
    word: String;
    isKeyword, isFloat: Boolean;
    isMultiple: Boolean;

    // 
    procedure assignSingleChar(Tvalue: String; Ttype: String);
    begin
        tokenKind[tokenCount] := Ttype;
        tokenValue[tokenCount] := Tvalue;
        t_line[tokenCount] := linecount;
        Inc(tokenCount);
    end;

    procedure assignDoubleChar(Tvalue: String; Ttype: String);
    begin
        tokenKind[tokenCount] := Ttype;
        tokenValue[tokenCount] := Tvalue;
        t_line[tokenCount] := linecount;
        isMultiple := True;
        Inc(tokenCount);
        Inc(i);
    end;

begin
    linecount := 1;
    isKeyword := False;
    isFloat :=  False;
    word := '';
    tokenCount := 0;

    for i := 0 to 1023 do
        begin
            tokenKind[i] := '';
            tokenValue[i] := '';
        end;
    
    i := 0; // POSITION TRACKER  
    repeat
        isMultiple := False; 

        if buf[i] = #10 then // NEWLINE
            Inc(linecount);

        // MULTI CHARACHTER TOKENS
        case buf[i] + buf[i+1] of
            ':=': assignDoubleChar(':=', 'ASSIGN');
            '|V': assignDoubleChar('|V', 'VARBLOCK');
            '|S': assignDoubleChar('|S', 'STATICBLOCK');
            '|D': assignDoubleChar('|D', 'DIRECTIVE');
            '|R': assignDoubleChar('|R', 'RECORDBLOCK');
            '>=': assignDoubleChar('>=', 'GREQUAL');
            '<=': assignDoubleChar('<=', 'LESSEQUAL');
            '++': assignDoubleChar('++', 'VADD');
            '**': assignDoubleChar('**', 'VMUL');
        end;

        // SINGLE CHARACHTER TOKENS 
        if not isMultiple then 
            begin       
                case buf[i] of 
                    '=': assignSingleChar('=', 'EQUAL');
                    '+': assignSingleChar('+', 'PLUS');
                    '-': assignSingleChar('-', 'MINUS');
                    '*': assignSingleChar('*', 'STAR');
                    '/': assignSingleChar('/', 'SLASH');
                    '{': assignSingleChar('{', 'LBRACE');
                    '}': assignSingleChar('}', 'RBRACE');
                    '(': assignSingleChar('(', 'LPAR');
                    ')': assignSingleChar(')', 'RPAR');
                    '>': assignSingleChar('>', 'MORE');
                    '<': assignSingleChar('<', 'LESS');
                    '[': assignSingleChar('[', 'LBRAC');
                    ']': assignSingleChar(']', 'RBRAC');
                    #39: assignSingleChar(#39, 'TERMINATOR');
                    #96: assignSingleChar(#96, 'QUOTE');
                    ',': assignSingleChar(',', 'COMMA');
                    '|': assignSingleChar('|', 'PIPE');
                    ':': assignSingleChar(':', 'COLON');
                    '&': assignSingleChar('&', 'AMP');

                    ';': begin   // comment — skip to end of line, emits no token
                        while (i < bytes) and (buf[i] <> #10) do
                            Inc(i);
            end          
        else
                if buf[i] in ['a'..'z', 'A'..'Z', '_'] then // Handle letters
                    begin
                    word := '';
                    while buf[i] in ['a'..'z', 'A'..'Z', '_', '0'..'9'] do
                        begin
                            word := word + buf[i];  // Collect words, add charachters to word
                            Inc(i); // Increment position in file, +1 charachter
                        end;
              
                        isKeyword := keywordCheck(UpperCase(word)); 
                        if isKeyword then  
                            begin
                                tokenKind[tokenCount] := UpperCase(word);
                                WriteLn(UpperCase(word)); // DEBUG PRINT
                            end
                            else
                                begin
                                tokenKind[tokenCount] := 'IDENTIFIER';
                                end;

                        tokenValue[tokenCount] := word;
                        Inc(tokenCount);
                        Dec(i);  
                    end

                else if buf[i] in ['0'..'9'] then
                begin
                    word := '';
                    isFloat := False;
                    while buf[i] in ['0'..'9', '.', 'f'] do
                        begin
                            word := word + buf[i];
                            Inc(i);
                        end;
                    
                   if (Pos('.', word) > 0) or (Pos('f', word) > 0) then
                        isFloat := True;

                    if isFloat then
                            assignSingleChar(word,'FLOAT')
                    else
                            assignSingleChar(word,'NUMBER');

                    Dec(i);
              
                end

                else if buf[i] = #96 then // Handle double quote strings
                begin
                    word := '';
                    Inc(i); // skip opening quote
                    while buf[i] <> #96 do
                    begin
                        word := word + buf[i];
                        Inc(i);
                    end;
                    // buf[i] is now closing quote
                    assignSingleChar(word,'STRING');
                    // no Dec(i) needed, already on closing quote, main Inc(i) moves past it
                end; 
                
            end; 
        end; 
        Inc(i); // Increment position in buffer
    until i >= bytes; // Runs until EOF

    i := 0;
    for i := 0 to tokenCount - 1 do
        WriteLn(IntToStr(i) + ': ' + tokenKind[i] + '  ' + tokenValue[i]);
end;

// INIT ============================================

procedure arrayInit();
var
    i: Integer;
begin
    i := 0;
    frameOffset := 0;

    for i := 0 to 255 do
        begin
        symOffset[i] := 0;
        param_FIndex[i] := 0;
        symName[i] := '';
        t_line[i] := 0;
        end;

    FillChar(loop_TLabel, SizeOf(loop_TLabel), 0);
    FillChar(loop_ELabel, SizeOf(loop_ELabel), 0);
    FillChar(conditional_ELabel, SizeOf(conditional_ELabel), 0);
    FillChar(return_FName, SizeOf(return_FName), 0);
    FillChar(return_FType, SizeOf(return_FType), 0);
    FillChar(param_FName, SizeOf(param_FName), 0);
    FillChar(param_FType, SizeOf(param_FType), 0);
    deleteFile('intermediate.asm');
    deleteFile('text.tmp');
    deleteFile('data.tmp'); 
    conditionalBodyNext := False;
    loopBodyNext := False;
    conditionalDepth := 0;
    param_FCount := 0;
    loopDepth := 0;
    return_FCount := 0;
    symCount := 0;
end;

procedure sendToNASM(outputName: String);
var
    cmd: String;
    result: Integer;
begin
    cmd := 'nasm -f elf64 intermediate.asm -o ' + outputName + '.o';
    result := fpSystem(cmd);
    if result <> 0 then
        begin
            WriteLn('I CANT BELIEVE YOUVE DONE THIS - NASM FAILED');
            Halt(1);
        end;

    cmd := 'ld ' + outputName + '.o -o ' + outputName;
    result := fpSystem(cmd);
    if result <> 0 then
        begin
            WriteLn('I CANT BELIEVE YOUVE DONE THIS - LINK FAILED');
            Halt(1);
        end;
end;

begin
if ParamCount = 1 then
    begin
        filename := ParamStr(1);
        stdlib_filename := 'lib/standard.rsk';
        output_filename := ChangeFileExt(ExtractFileName(filename), '');
        arrayInit;
        openFile;
        lexer;
        openIntermediateFile;
        parser;
        closeIntermediateFile;
        writeASM;
        sendToNASM(output_filename);
        deleteFile(output_filename + '.o');
    end
else
    begin
    WriteLn('No File Loaded');
    end;
end.

