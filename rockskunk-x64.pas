program rockskunk_x64;
uses
    BaseUnix, SysUtils, Unix, Optimizer;

const
    intRegs: array[0..5] of String = ('rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9'); // SYSV ABI
    acceptedKeywords: array[0..13] of String = // MAKE SURE TO UPDATE KEYWORD CHECK WHEN ADDING
    ('ADD', 'F', 'LF', 'LW', 'W', 'IF', 'E', 'P', 'OR', 'AND', 'NOR', 'XOR', 'CALL', 'DO');
var
    buf, databuf, textbuf, bbuf: Array[0..1048575] of Char;

    symName, symType: array[0..1023] of String;
    symOffset: array[0..1023] of Integer;
    aName, aType, aSize: array[0..1023] of String;

    tokenKind, tokenValue: Array[0..65535] of String;
    t_line: Array[0..65535] of Integer;

    cfKind, cfTLabel, cfELabel, cfLVar: Array[0..64] of String;
    cfDepth: Integer;

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
    paramPending, awaitingFunctionOpen: Boolean; 

    currentFN: String;
    bytes, bbytes, fd, fd2, fd3, fd4, fd5: CInt;
    filename, output_filename, stdlib_filename, returnAddr: String;

    frameOffset, labelCounter, position, symCount, aCount, argCount, tokenCount, fstackPosition: Integer;

{
   DO NOT FORGET LIST ====
   REMEMBER REDO ASM OUTPUT PRIMITIVES AND LOOPS
   PASCAL FFI
   VECTORS
   IF/ELSE
   REGISTER ALLOC
}

// Forward Declarations

function WhoGoesThere(intruder: String): String; forward;
function evaluateExpression(isFloat: Boolean): String; forward;
procedure dispatch(); forward;

// HELPERS =================================================
// ========================================================

procedure writeOut(s: String); begin fpWrite(fd2, s[1], Length(s)); end;
procedure writeText(s: String); begin fpWrite(fd3, s[1], Length(s)); end;
procedure writeData(s: String); begin fpWrite(fd4, s[1], Length(s)); end;
procedure writeBSS(s: String); begin fpWrite(fd5, s[1], Length(s)); end;

function keywordCheck(word: String): Boolean; // Flag keywords
var
    i: Integer;
begin
    keywordCheck := False;
    for i := 0 to 13 do
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
    WriteLn('LOADING STANDARD LIBRARY');
    FillChar(buf, SizeOf(buf), 0);
    fd := fpOpen(stdlib_filename, O_RdOnly);
    libBytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);

    WriteLn(IntToStr(t_line[position]) + ' - ' + 'LOADING SOURCEFILE LIBRARY');
    fd := fpOpen(filename, O_RdOnly);
    bytes := FpRead(fd, buf[libBytes], SizeOf(buf) - libBytes);
    fpClose(fd);

    bytes := bytes + libBytes;
end;

procedure openIntermediateFile; // open temp sourcefile
begin
    fd3 := fpOpen('text.tmp',O_WRONLY OR O_CREAT OR O_TRUNC, 438);
    fd4 := fpOpen('data.tmp',O_WRONLY OR O_CREAT OR O_TRUNC, 438);
    fd5 := fpOpen('bss.tmp',O_WRONLY OR O_CREAT OR O_TRUNC, 438);
    FillChar(databuf, SizeOf(databuf), 0);
    FillChar(textbuf, SizeOf(textbuf), 0);
end;

procedure writeASM; // Write to real intermediate.asm that is compiled by NASM
var
    dbytes, tbytes: cint;
begin
    //WriteLn(IntToStr(t_line[position]) + ' - ' + 'WRITEASM - START'); // DEBUG
    fd2 := fpOpen('intermediate.asm',O_WRONLY OR O_CREAT OR O_TRUNC, 438);

    fd5 := fpOpen('bss.tmp', O_RdOnly, 438);
    WriteOut('section .bss' + #10);
    WriteOut('   digitbuf: resb 32' + #10);
    bbytes := fpRead(fd5, bbuf, SizeOf(bbuf));
    fpWrite(fd2, bbuf, bbytes);
    fpClose(fd5);

    fd4 := fpOpen('data.tmp', O_RdOnly, 438);
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
    //WriteLn(IntToStr(t_line[position]) + ' - ' + 'WRITEASM - END'); // DEBUG
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
    WriteText('    sub rsp, ');
    fstackPosition := FpLSeek(fd3, 0, Seek_Cur);   // fd3 — matches WriteText's target
    WriteText('0000000128' + #10);
end;

procedure emitFunctionTeardown(result: String; isProcedure: Boolean);
var
    rcheck: String;
    isFloat: Boolean;
    savedPos: Int64;
    alignedSize: Integer;
    paddedSize: String;
begin
    if not isProcedure then
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

    alignedSize := (frameOffset + 15) and not 15;
    paddedSize := Format('%.10d', [alignedSize]);
    savedPos := FpLSeek(fd3, 0, Seek_Cur);

    FpLSeek(fd3, fstackPosition, Seek_Set);
    WriteText(paddedSize);
    FpLSeek(fd3, savedPos, Seek_Set);

    WriteText('    add rsp, ' + paddedSize + #10);
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

procedure emitAssignArray(variable : String; value : String; atype: String);
begin
    if aType = 'BYTE' then 
        begin
            if value <> 'rax' then
                    WriteText('    mov rax, ' + value + #10); // if i didnt do this i get mov rax, rax
                    WriteText('    mov byte ' + variable + ', al' + #10);
        end
    else
        begin
    if value <> 'rax' then
            WriteText('    mov rax, ' + value + #10); // if i didnt do this i get mov rax, rax
            WriteText('    mov ' + variable + ', rax' + #10);
        end;
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

function emitStringConstant(content: String): String;
var
    slength, i: Integer;
    dbLine: String;
    inQuote: Boolean;
begin
        slength := length(content);
        WriteData('   str_' + IntToStr(labelCounter) + '_len: dq ' + IntToStr(slength) + #10);

        dbLine := '';
        inQuote := False;
        for i := 1 to length(content) do
            begin
                if (content[i] >= #32) and (content[i] <> #39) then // printable, not a quote char
                    begin
                        if not inQuote then
                            begin
                                if dbLine <> '' then dbLine := dbLine + ', ';
                                dbLine := dbLine + #39;
                                inQuote := True;
                            end;
                        dbLine := dbLine + content[i];
                    end
                else // control byte - break out of the quoted run, emit as a number
                    begin
                        if inQuote then
                            begin
                                dbLine := dbLine + #39;
                                inQuote := False;
                            end;
                        if dbLine <> '' then dbLine := dbLine + ', ';
                        dbLine := dbLine + IntToStr(Ord(content[i]));
                    end;
            end;
        if inQuote then
            dbLine := dbLine + #39;

        if dbLine <> '' then dbLine := dbLine + ', ';
        dbLine := dbLine + '0';

        WriteData('   str_' + IntToStr(labelCounter) + ': db ' + dbLine + #10);

        emitStringConstant := 'str_' + IntToStr(labelCounter) + '_len';
        Inc(labelCounter);
end;

// ARRAYS / MEMORY -----------------------------------------------------------

function emitAddressOf(variable: String): String; // &a
begin 
        WriteText('    lea rax, ' + variable + #10);
        emitAddressOf := 'rax';
end;         

function emitDereference(variable: String): String; // ^
begin
        WriteText('    mov rax, ' + variable + #10); // load pointers value (addr)
        WriteText('    mov rax, [rax]' + #10); // use that register as memory and read through it
        emitDereference := 'rax';
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

// BITWISE --------------------------------------------------

procedure emitAnd(dst, src: String); 
begin 
    WriteText('    mov rax, ' + dst + #10);
    WriteText('    and rax, ' + src + #10);
end;

procedure emitOr(dst, src: String); 
begin 
    WriteText('    mov rax, ' + dst + #10);
    WriteText('    or rax, ' + src + #10);
end;

procedure emitXor(dst, src: String); 
begin 
    WriteText('    mov rax, ' + dst + #10);
    WriteText('    xor rax, ' + src + #10);
end;

procedure emitNot(dst: String);         //no src 
begin 
    WriteText('    mov rax, ' + dst + #10);
    WriteText('    not rax' + #10);
end;

// NEED VAR DETECTION
procedure emitNor(dst, src: String); begin WriteText('    nor ' + dst + ', ' + src + #10); end;

procedure emitShl(dst, src: String); 
begin 
    WriteText('    mov rax, ' + dst + #10);
    if isNumber(src) then
        WriteText('    shl rax, ' + src + #10)
    else
    begin
        WriteText('    mov rcx, ' + src + #10);
        WriteText('    shl rax, cl' + #10);
    end;
end;

procedure emitShr(dst, src: String); 
begin 
    WriteText('    mov rax, ' + dst + #10);
    if isNumber(src) then
        WriteText('    shr rax, ' + src + #10)
    else
    begin
        WriteText('    mov rcx, ' + src + #10);
        WriteText('    shr rax, cl' + #10);
    end;
end;



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
    //WriteLn( 'CNSM - K ' + tokenKind[position] + ' V ' + tokenValue[position]);
    Inc(position);  // Increment counter to drop the token
end;

function varToMem(variable: String): String;
var
    i: Integer;
begin
    for i := 0 to aCount - 1 do       
        if aName[i] = variable then
            Exit(variable);

    varToMem := ''; 
    for i := 0 to symCount - 1 do
        begin
            if symName[i] = variable then
                VarToMem := '[rbp-' + IntToStr(symOffset[i]) + ']';
        end;
    if varToMem = '' then
        begin    
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - VAR_TO_MEM - UNK SYMBOL>> ' + variable);
            Halt(1); // Loop for multiple opererators was getting pissed becuase '+' was making its way into here
        end;
end;

function arrayToMem(arrayName, aindex: String): String;
var
    i, intindex ,elementSize: Integer;
    arType: String;
begin
    arrayToMem := ''; 
    i := 0;

    for i := 0 to aCount - 1 do
            if aName[i] = arrayName then
                    arType := aType[i];

    if arType = 'WORD' then elementSize := 8
    else if arType = 'FLOAT' then elementSize := 8
    else if arType = 'BYTE' then elementSize := 1;

    if isNumber(aindex) then // if the index is a number then NASM will do the index math automatically
        begin
            intindex := StrToInt(aindex);
            for i := 0 to aCount - 1 do
                begin
                    if aName[i] = arrayName then
                        begin
                            if aIndex > aSize[i] then
                                WriteLn(IntToStr(t_line[position]) + ' - ' + 'YOU HAVE FRUSTRATED THE COMPILER - ARRAY_TO_MEM - OOB>> ' + arrayName)
                            else
                                ArrayToMem := '   [' + arrayname + ' + ' + IntToStr(intindex * elementSize) + ']';
                        end;
                end;
        end
    else 
        begin
            WriteText('    mov r10, ' + varToMem(aindex) + #10);
            ArrayToMem := '   [' + arrayname + ' + r10*' + IntToStr(elementSize) + ']';
        end;

    if arrayToMem = '' then
        begin    
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - ARRAY_TO_MEM - UNK SYMBOL>> ' + arrayName);
            Halt(1); // Loop for multiple opererators was getting pissed becuase '+' was making its way into here
        end;
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
                    WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - EMIT_MATH - UNK OP >> ' + op);
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
                    WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - EMIT_MATH - UNK OP >> ' + op);
                    Halt(1);
                end;
        end;
end;

procedure asmFunctionCalls(variable: String; argname: String);
var
    a, b, c, num: String;
begin
    if variable = 'printf' then
        begin
            consume; // (
            argname := consume();
            if not isNumber(argname) then argname := varToMem(argname);
            consume; // )
            functionPrintF(argname);
        end
    else if variable = 'printw' then
        begin
            consume; // (
            argname := consume();
            if not isNumber(argname) then argname := varToMem(argname);
            consume; // )
            functionPrintW(argname);
        end
    else if variable = 'sys' then
        begin
            consume;// sys, (
            num := resolveSyscall(); consume;
            a := resolveSyscall(); consume;
            b := resolveSyscall(); consume;
            c := resolveSyscall(); consume; // )
            emitSyscall(num, a, b, c);
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
     WriteLn(IntToStr(t_line[position]) + ' - ' + 'OPRESOLVER'); // DEBUG

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

// MAIN PARSER MACHINERY ====================================================

function argumentParser(argname, fname, first: String; returnsFloat: Boolean; argfindex: Integer): String;
var
    strlabel: String;
    seenFloats, seenInts, argCounter: Integer;
    isFloatArg: Boolean;
begin
            WriteLn('ARGUMENT PARSER - I' + IntToStr(argfindex) + '- N' + argname); // DEBUG
            argcounter := 0;
            seenFloats := 0;
            seenInts := 0;

        repeat  // VERIFY LOOP
            isFloatArg := False;

            if peek() = 'STRING' then
                begin
                    argname := consume();
                    strlabel := emitStringConstant(argname);
                    argname := strlabel;
                end
            else
                begin
                    argname := consume();

                    if param_FType[argfindex + argcounter] = 'FLOAT' then
                                    isFloatArg := True;

                    if not isNumber(argname) then
                                    argname := varToMem(argname);
            end;

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

function eeArrays(): String;
var
    arrayname, arrayIndex, arrayType, str: String;
begin
     WriteLn(IntToStr(t_line[position]) + ' - ' + 'EXPRESSION EVAL - ARRAYS'); // DEBUG
        // Word Arrays
    if (peek()='IDENTIFIER') and (peek2()='LBRAC') then
        begin
            arrayname := consume;
            consume; // [
            arrayIndex := consume;
            consume; // ]
            arrayType := 'WORD';
            Exit(arrayToMem(arrayname, arrayIndex));
        end;

    // Float Arrays
    if (peek()='IDENTIFIER') and (peek2()='LBRACE') then
        begin
            arrayname := consume;
            consume; // [
            arrayIndex := consume;
            consume; // ]
            arrayType := 'FLOAT';
            Exit(arrayToMem(arrayname, arrayIndex));
        end;

    // Byte Arrays
    if (peek2() = 'BANG') and (peek()='LBRAC') then
        begin
            arrayname := consume;
            consume;
            consume; // [
            arrayIndex := consume;
            consume; // ]
            arrayType := 'BYTE';
            Exit(arrayToMem(arrayname, arrayIndex));
        end;
end;

function eeIncidentals(): String;
var
    arrayname, arrayIndex, arrayType, str, ampaddr, ident: String;
    num, a, b, c: String;
begin
    if peek() = 'AMP' then
        begin
            consume;
            ampaddr := VarToMem(consume);
            Exit(emitAddressOf(ampaddr));
        end;

    if peek() = 'STRING' then
        begin
            str := consume;
            Exit(emitStringConstant(str));
        end;

    if (peek()='IDENTIFIER') and (peek2()='CARET') then
        begin
            ident := consume;
            consume;
            Exit(emitDereference(VarToMem(ident)))
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

end;

function bitwiseEvaluator(first: String; isFloat: Boolean): String;
var
    second, op: String;
begin
    WriteLn(IntToStr(t_line[position]) + ' - ' + 'EXPRESSION EVAL - BITWISE BRANCH');
    loadRAX(first); 

    while ((peek() = 'DOLLAR') or (peek() = 'PIPE') or (peek() = 'NOR') or (peek() = 'NOY') or (peek() = 'SHL') or (peek() = 'SHR')) do
    begin
        op := peek(); 
        consume;
        second := consume(); 
        second := ifFloatIfVar(second);

        if      op = 'DOLLAR' then emitAnd('rax', second)
        else if op = 'PIPE'   then emitOr('rax', second)
        else if op = 'XOR'    then emitXor('rax', second)
        else if op = 'NOT'    then emitNot('rax')
        else if op = 'SHL'    then emitShl('rax', second)
        else if op = 'SHR'    then emitShr('rax', second)
        else
        begin
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - EMIT_BITWISE - UNK OP >> ' + op);
            Halt(1);
        end;
    end;

    bitwiseEvaluator := 'rax';
end;

function evaluateExpression(isFloat: Boolean): String;
var
    first, second, op, argname, fname, return, math_ret, call_ret, ampaddr, r, ident: String;
    arrayname, arrayIndex, arrayType, str: String;
    num, a, b, c: String;
    returnsFloat: Boolean;
    i, argfindex: Integer;
begin
    i := 0;
    first := '';
    argname := '';
    arrayType := '';
    arrayIndex := '';
    arrayname := '';
    str := '';
    returnsFloat := False;

    if (peek() = 'AMP') or (peek() = 'STRING') or ((peek() = 'IDENTIFIER') and (peek2() = 'CARET')) or ((peekV() = 'sys') and (peek2() = 'LPAR')) then
        begin
            r := eeIncidentals();
            Exit(r);
        end;

    if ((peek() = 'IDENTIFIER') and (peek2() = 'LBRAC')) or ((peek() = 'IDENTIFIER') and (peek2() = 'LBRACE')) or ((peek() = 'LBRAC') and (peek2() = 'BANG')) then
        begin
            r := eeArrays();
            Exit(r);
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
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'EXPRESSION EVAL - NOT OPERATOR BRANCH'); // DEBUG
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


            if ((peek() = 'DOLLAR') or (peek() = 'PIPE') or (peek() = 'NOR') or (peek() = 'NOY') or (peek() = 'SHL') or (peek() = 'SHR')) then
                Exit(bitwiseEvaluator(first, isFloat));

            // if next token isnt operator return the first operand eg if var := 5 not var := 5 + b
            if not ((peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH')) then
                evaluateExpression := first
            else
                begin
                    WriteLn(IntToStr(t_line[position]) + ' - ' + 'EXPRESSION EVAL - OPERATOR BRANCH');

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

function discriminateArrays(variable: String): Boolean;
var
    rightside, arrayName, arrayIndex, arrayType: String;
begin

    discriminateArrays := False;
        // Word Arrays
    if peek() = 'LBRAC' then
        begin
            arrayname := variable;
            consume; // [
            arrayIndex := consume;
            consume; // ]
            arrayType := 'WORD';
            consume;
            variable := arrayToMem(arrayname, arrayIndex);
            rightside := evaluateExpression(False); 
            emitAssignArray(variable, rightside, arrayType);
            discriminateArrays := True;
            Exit;
        end;

      // Float Arrays
    if peek() = 'LBRACE' then
        begin
            arrayname := variable;
            consume; // [
            arrayIndex := consume;
            consume; // ]
            arrayType := 'FLOAT';
            consume;
            variable := arrayToMem(arrayname, arrayIndex);
            rightside := evaluateExpression(True); 
            emitAssignArray(variable, rightside, arrayType);
            discriminateArrays := True;
            Exit;
        end;

      // Byte Arrays
    if peek() = 'BANG' then
        begin
            arrayname := variable;
            consume;
            consume; // [
            arrayIndex := consume;
            consume; // ]
            arrayType := 'BYTE';
            consume;
            variable := arrayToMem(arrayname, arrayIndex);
            rightside := evaluateExpression(False); 
            emitAssignArray(variable, rightside, arrayType);
            discriminateArrays := True;
            Exit;
        end;
end;


procedure discriminateIdentifier();
var
    variable, rightside, twoname, argname: String;
    isDeclared, isReturn, isFloat, didArrays: boolean;
    arrayname, arrayIndex, arrayType: String;
    i, ii, symIndex, argfindex: Integer;
    returnsFloat: Boolean;
begin
    i := 0;
    ii := 0;
    symIndex := 0;
    argName := '';
    isDeclared := False;
    isReturn := False;
    isFloat := False;

    variable := consume(); // consume the a in a := 5

    if variable = 'r' then isReturn := True;

    didArrays := discriminateArrays(variable);
    if didArrays then Exit;

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

    if peek() = 'CARET' then // dereference on left side of assign
        begin

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
                        WriteLn(IntToStr(t_line[position]) + ' - ' + 'ASSIGN BRANCH - DECLARED'); // DEBUG
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
                        WriteLn(IntToStr(t_line[position]) + ' - ' + 'ASSIGN BRANCH - UNDECLARED'); // DEBUG
                    end;
        end
        else
            begin 
                if peek() = 'LPAR' then 
                    begin
                        
                        if ((variable = 'printw') or (variable = 'printf') or (variable = 'sys')) then
                            begin
                                WriteLn(IntToStr(t_line[position]) + ' - ' + 'DI BRANCH - ASM'); // DEBUG
                                asmFunctionCalls(variable, argname);
                            end
                        else
                            begin
                                WriteLn(IntToStr(t_line[position]) + ' - ' + 'DI BRANCH - F CALL'); // DEBUG
                                consume(); // (
                                if peek() <> 'RPAR' then
                                    begin

                                        if WhoGoesThere(variable) = 'FLOAT' then
                                            returnsFloat := True;

                                        for i := 0 to param_FCount - 1 do
                                            if variable = param_FName[i] then
                                                begin
                                                    argfindex := param_FIndex[i];
                                                    break;
                                                end;

                                        argumentParser(argname, variable, '', returnsFloat, argfindex);
                                    end
                                else
                                    begin
                                        consume; //)
                                        call(variable, argname, returnsFloat);
                                    end;  
                            end; 
                
                end
                    else
                        begin
                            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - DI CALLBRANCH - YOU HAVE FED ME GARBAGE>> ' + peek() + ' ' + peekV());
                            Halt(1);
                        end;
         end;
end;


// ONE-OFFS ------------
// only do, if, else are broken
procedure conditionalIntrinsic(); begin end;

   {cfKind, cfTLabel, cfELabel, cfLVar: Array[0..64] of String;
    cfDepth: Integer;}

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

   
    cfKind[cfDepth] := 'WHILE';
    cfTLabel[cfDepth] := toplabel;
    cfELabel[cfDepth] := endlabel;
    Inc(cfDepth);
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

    cfKind[cfDepth] := 'FOR';
    cfTLabel[cfDepth] := toplabel;
    cfELabel[cfDepth] := endlabel;
    cfLVar[cfDepth] := loopvar;
    Inc(cfDepth);
end;

function loopDo(): Boolean;
var
    loopvar, loopstart, looplimit, toplabel, endlabel: String;
    loopCounter, doDepth, ls, ll, n, bodyStart, bodyEnd: Integer;
begin
    
    consume; //consume LF
    consume; // consume LPAR
    loopvar := consume;
    consume; // :=
    loopstart := consume; // 0
    consume; // until
    looplimit := consume; 
    consume; // RPAR
  
    loopCounter := position; // starting on {
    doDepth := 0;
    
    repeat
            if tokenKind[loopCounter] = 'LBRACE' then
                begin
                    Inc(doDepth);
                end;
            if tokenKind[loopCounter] = 'RBRACE' then
                    Dec(doDepth);

            Inc(loopCounter);
        until doDepth = 0;

    frameOffset := frameOffset + 8;
    symOffset[symCount] := frameOffset;
    symName[symCount] := loopvar;
    Inc(symCount);
    loopvar := varToMem(loopvar);

    bodyStart := position + 1;
    bodyEnd := loopCounter - 1;

    ll := StrToInt(looplimit);
    ls := StrToInt(loopstart);

    if ll > 100 then
        writeLn('YOU HAVE FRUSTRATED THE COMPILER - YOU DARE EXCEED 100 ITERATIONS OF A DO LOOP?');

    for n := ls to ll - 1 do
        begin
            WriteText('    mov qword ' + computeOffset(symOffset[symCount-1]) + ', ' + IntToStr(n) + #10);
            position := bodyStart;
            while position < bodyEnd do
                dispatch;
        end;

    position := bodyEnd + 1;
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

    cfKind[cfDepth] := 'WHEN';
    cfELabel[cfDepth] := endlabel;
    Inc(cfDepth);
    condWhen := True;
end;

procedure condIf(); begin consume; end;
procedure condElse(); begin consume; end;

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
                awaitingFunctionOpen := True;
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
                                                    param_FType[param_FCount] := 'FLOAT';
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

procedure varBlock();
var
    arrayName, arrayType, arraySize: String;
begin
    arrayName := '';
    arrayType := '';
    arraySize := '';
    consume; // consume |V
        while peek() <> 'PIPE' do 
            begin
                        if peek2() = 'ASSIGN' then // globals
                            begin
                            end 
                        else if peek2() = 'BANG' then // byte arrays
                            begin
                                arrayName := consume;
                                consume;
                                consume;
                                arraySize := consume;
                                consume;
                                aName[aCount] := arrayName;
                                aSize[aCount] := arraySize;
                                aType[aCount] := 'BYTE';
                                WriteBSS(arrayName + ': resb ' + arraySize + #10);
                                Inc(aCount);
                            end 
                        else if peek2() = 'LBRAC' then // word arrays
                            begin
                                arrayName := consume;
                                consume;
                                arraySize := consume;
                                consume;
                                aName[aCount] := arrayName;
                                aSize[aCount] := arraySize;
                                aType[aCount] := 'WORD';
                                WriteBSS(arrayName + ': resq ' + arraySize + #10);
                                Inc(aCount);
                            end 
                        else if peek2() = 'LBRACE' then // float arrays
                            begin
                                arrayName := consume;
                                consume;
                                arraySize := consume;
                                consume;
                                aName[aCount] := arrayName;
                                aSize[aCount] := arraySize;
                                aType[aCount] := 'FLOAT';
                                WriteBSS(arrayName + ': resq ' + arraySize + #10);
                                Inc(aCount);
                            end 
                        else
                            begin
                                WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - VARBLOCK - YOU HAVE FED ME GARBAGE>> ' + peek() + ' ' + peekV());
                                Halt(1);
                            end;
            end;
    consume;
end;

// PARSER -----------
procedure dispatch();
var
    isProcedure: Boolean;
    i, seenFloats, seenInts: Integer;
begin
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
                if awaitingFunctionOpen then
                    begin
                        awaitingFunctionOpen := False;
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
                    if cfDepth > 0 then
                    begin
                        Dec(cfDepth);
                        case cfKind[cfDepth] of
                            'FOR': begin
                                WriteText('    inc qword ' + cfLVar[cfDepth] + #10); // or whatever your increment emit looks like
                                WriteText('    jmp ' + cfTLabel[cfDepth] + #10);
                                emitLabel(cfELabel[cfDepth]);
                            end;
                            'WHILE': begin
                                WriteText('    jmp ' + cfTLabel[cfDepth] + #10);
                                emitLabel(cfELabel[cfDepth]);
                            end;
                            'WHEN': emitLabel(cfELabel[cfDepth]);
                        end;
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
            {'AMP': begin 
                consume;
            end;
            'CARET': begin 
                consume;
            end;}
            'W': begin 
                condWhen();
            end;
            'IF': begin 
                condIf();
            end;
            'E': begin 
                condElse();
            end;
            'LF': begin 
                loopFor();
            end;
            'LW': begin 
                loopWhile();
            end;
            'DO': begin 
                loopDo();
            end;
            'VARBLOCK': begin varBlock(); end;
            'STATICBLOCK': begin 
                consume; // consume '
            end;
            'ASMBLOCK': begin 
                consume; // consume '
            end;
            //'STRING': begin 
            //    consume; // consume '
            //end
            else
            begin
                WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - PARSER - YOU HAVE FED ME GARBAGE>> ' + peek() + ' ' + peekV());
                Halt(1);
            end;
        
        end;
end;

procedure parser();
var
    isProcedure: Boolean;
    i, seenFloats, seenInts: Integer;
begin
    i := 0;
    position := 0;
    repeat
       dispatch();
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

    procedure assignTripleChar(Tvalue: String; Ttype: String);
    begin
        tokenKind[tokenCount] := Ttype;
        tokenValue[tokenCount] := Tvalue;
        t_line[tokenCount] := linecount;
        isMultiple := True;
        Inc(tokenCount);
        Inc(i);
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

        // TRIPLE CHARACHTER TOKENS
        case buf[i] + buf[i+1] + buf[i+2] of
            'nor': assignDoubleChar('nor', 'NOR');
            'xor': assignDoubleChar('xor', 'XOR');
            'not': assignDoubleChar('not', 'NOT');
        end;
        // DOUBLE CHARACHTER TOKENS
        case buf[i] + buf[i+1] of
            ':=': assignDoubleChar(':=', 'ASSIGN');
            '|V': assignDoubleChar('|V', 'VARBLOCK');
            '|S': assignDoubleChar('|S', 'STATICBLOCK');
            '|D': assignDoubleChar('|D', 'DIRECTIVE');
            '|A': assignDoubleChar('|A', 'ASMBLOCK');
            '>=': assignDoubleChar('>=', 'GREQUAL');
            '<=': assignDoubleChar('<=', 'LESSEQUAL');
            '++': assignDoubleChar('++', 'VADD');
            '**': assignDoubleChar('**', 'VMUL');
            '>>': assignDoubleChar('>>', 'SHR');
            '<<': assignDoubleChar('<<', 'SHL');
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
                    #96: assignSingleChar(#96, 'QUOTE');
                    ',': assignSingleChar(',', 'COMMA');
                    '|': assignSingleChar('|', 'PIPE');
                    ':': assignSingleChar(':', 'COLON');
                    '&': assignSingleChar('&', 'AMP');
                    '^': assignSingleChar('^', 'CARET');
                    '$': assignSingleChar('^', 'DOLLAR');
                    '!': assignSingleChar('!', 'BANG');

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
              
                        isKeyword := keywordCheck(word); 
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
                        t_line[tokenCount] := linecount;
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

                else if buf[i] = #39 then // Handle single quote strings
                    begin
                        word := '';
                        Inc(i); // skip opening quote
                        while buf[i] <> #39 do
                        begin
                            if buf[i] = '\' then
                            begin
                                Inc(i); // move onto the escape character itself
                                case buf[i] of
                                    'n': word := word + #10;
                                    't': word := word + #9;
                                    'r': word := word + #13;
                                    '0': word := word + #0;
                                    '\': word := word + '\';
                                    #39: word := word + #39;
                                    else
                                        word := word + buf[i]; // unrecognized escape, take it literally
                                end;
                            end
                            else
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
        aName[i] := '';
        aType[i] := '';
        end;

    FillChar(cfKind, SizeOf(cfKind), 0);
    FillChar(cfELabel, SizeOf(cfELabel), 0);
    FillChar(cfTLabel, SizeOf(cfTLabel), 0);
    FillChar(cfLVar, SizeOf(cfLVar), 0);
    FillChar(return_FType, SizeOf(return_FType), 0);
    FillChar(param_FName, SizeOf(param_FName), 0);
    FillChar(param_FType, SizeOf(param_FType), 0);
    deleteFile('intermediate.asm');
    deleteFile('text.tmp');
    deleteFile('data.tmp'); 
    param_FCount := 0;
    awaitingFunctionOpen := False;
    return_FCount := 0;
    symCount := 0;
    cfDepth := 0;
    aCount := 0;

end;

procedure sendToNASM(outputName: String);
var
    cmd: String;
    result: Integer;
begin
    //WriteLn(IntToStr(t_line[position]) + ' - ' + 'NASM - START'); // DEBUG
    cmd := 'nasm -f elf64 intermediate.asm -o ' + outputName + '.o';
    result := fpSystem(cmd);
    if result <> 0 then
        begin
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - NASM FAILED');
            Halt(1);
        end;

    cmd := 'ld ' + outputName + '.o -o ' + outputName;
    result := fpSystem(cmd);
    if result <> 0 then
        begin
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - LINK FAILED');
            Halt(1);
        end;
    //WriteLn(IntToStr(t_line[position]) + ' - ' + 'NASM - END'); // DEBUG
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
        Optimize;
        sendToNASM(output_filename);
        deleteFile(output_filename + '.o');
    end
else
    begin
    WriteLn('No File Loaded');
    end;
end.

