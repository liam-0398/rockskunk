program rockskunk_x64;
uses
    BaseUnix, SysUtils, Unix;

const
    intRegs: array[0..5] of String = ('rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9');
    acceptedKeywords: array[0..14] of String = // MAKE SURE TO UPDATE KEYWORD CHECK WHEN ADDING
    ('ADD', 'V', 'S',
     'F', 'LF', 'LW', 'W', 'IF', 'E', 'P',
     'OR', 'AND', 'NOR', 'XOR', 'CALL');

type

    TKind = (kNone, kReg, kMem, kData, kLit, kArray);
    TValType = (vtNumber, vtFloat, vtString, vtByte);
    TFrameKind = (fkLoopW, fkLoopF, fkCond, fkCondIf, fkCondElse);

    TLocal = record
        name:    String;
        varType: String;
        offset:  Integer;
    end;

    TGlobal = record
        name:     String;
        varType:  String;
        asmLabel: String;
    end;

    TFunction = record
        name:        String;
        returnType:  String;
        isProcedure: Boolean;
        paramType:   array[0..7] of String;
        paramCount:  Integer;
    end;

    TFrame = record
        kind: TFrameKind;
        topLabel: String;   // only loops use this, cond leaves it blank
        endLabel: String;
        loopvaro: String;
    end;

    TArray = record
        name:      String;
        elementCount: Integer;   // max size, from array[100] declaration
        elementType:  TValType;  // vtNumber, vtFloat — reuse existing enum, byte is a separate access-width concern, not a separate elemType
        asmLabel:  String;
    end;

    // new to records and enums so this will probably be a shitshow
    TValue = record
        vKind:     TKind; // What type of info is passed to NASM, register, memory, literals?
        vType:     TValType; // vtNumber, vtFloat, vtString
        vWordPayload:  Int64; // the word
        vFltPayload:  Double; // the float
        vStringPayload:  String; // register names and data labels eg float_69
        vOffset:    Integer; // the actual offset
        vIndexReg: String; // which reegister holds eeval array index
        vAScale:   Integer; // array scale in bytes
    end;

var
    // yes yes i know static arrays yeah yeah, in test enviorment its fine
    stateLocalCount, stateGlobalCount, stateFunctionCount: Integer;
    stateLocal: array[0..255] of TLocal;
    stateGlobal: array[0..255] of TGlobal;
    stateFunction:   array[0..255] of TFunction;
    stateArray: array[0..255] of TArray;
    stateArrayCount: Integer;

    buf, databuf, textbuf, bssbuf: Array[0..65535] of Char;

    t_type, t_val: Array[0..4096] of String;
    t_line: Array[0..4096] of Integer;

    frames: array[0..63] of TFrame;
    frameDepth: Integer;
    bodyPending: Boolean;
    chainEndLabel: String;
    inChain: Boolean;

    loop_TLabel: array [0..64] of String;
    loop_ELabel: array [0..64] of String;
    loopDepth: Integer;
    loopBodyNext: Boolean;

    conditional_ELabel: array [0..64] of String;
    conditionalDepth: Integer;
    conditionalBodyNext: Boolean;

    filename, output_filename, stdlib_filename, returnAddr, currentFN: String;
    frameOffset, labelCounter, position, argCount, t_count: Integer;
    fd, fd2, fd3, fd4, fd5, bbytes, bytes: CInt;
    paramPending: Boolean; 
    

{
   DO NOT FORGET LIST ====
   REMEMBER REDO ASM OUTPUT PRIMITIVES AND FIX LOOPS
}

{ ASM notes 

    rax - int / syscall (scratch)
    rbx - pool
    rcx - arg 4 calls (must be freeable)
    rdx - arg 3, 2nd return SASSY can clobber input, do research
    rsi 0 arg 2 - pool
    rdi - arg 1 - pool
    rbp - frame pointer
    rsp - stack pointer
    r8 - arg 5 pool
    r9 - arg 6 pool
    r10 - arg 4 - pool 
    r11 - clobbered by syscall (scratch)
    r12-15 - pool, clean

    // float reginsters are always destroyed by function calls, spill to stack
    xmm0 - arg1 (float scratch, return)
    xmm1 - arg 2 (2nd return) - pool
    xmm2-7 - args - pool
    xmm8-15 -pool, clean
}

// Forward Declarations -----------------------------------------------------------

function WhoGoesThere(intruder: String): String; forward;
procedure arguementParser(functionIndex: Integer); forward;
function evaluateExpression(isFloat: Boolean): TValue; forward;
function currentLine(): String; forward;

// RECORD MX ============================================================================

function findLocalIndex(name: String): Integer;
var
    i: Integer;
begin
    findLocalIndex := -1;
    for i := 0 to stateLocalCount - 1 do
        if stateLocal[i].name = name then
            begin
                findLocalIndex := i;
                break;
            end;
end;

function addLocalEntry(name: String; vtype: String): Integer;
begin
    if findLocalIndex(name) <> -1 then
        begin
            WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - ADD_LOCAL - DUPLICATE >> ' + name);
            Halt(1);
        end;

    frameOffset := frameOffset + 8;

    stateLocal[stateLocalCount].name    := name;
    stateLocal[stateLocalCount].varType := vtype;
    stateLocal[stateLocalCount].offset  := frameOffset;

    addLocalEntry := stateLocalCount;
    Inc(stateLocalCount);
end;

function findGlobalIndex(name: String): Integer;
var
    i: Integer;
begin
    findGlobalIndex := -1;
    for i := 0 to stateGlobalCount - 1 do
        if stateGlobal[i].name = name then
            begin
                findGlobalIndex := i;
                break;
            end;
end;

function addGlobalEntry(name: String; vtype: String): Integer;
begin
    if findGlobalIndex(name) <> -1 then
        begin
            WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - ADD_GLOBAL - DUPLICATE >> ' + name);
            Halt(1);
        end;

    stateGlobal[stateGlobalCount].name    := name;
    stateGlobal[stateGlobalCount].varType := vtype;
    stateGlobal[stateGlobalCount].asmLabel := 'g_' + name;

    addGlobalEntry := stateGlobalCount;
    Inc(stateGlobalCount);
end;

function findFunctionIndex(name: String): Integer;
var
    i: Integer;
begin
    findFunctionIndex := -1;
    for i := 0 to stateFunctionCount - 1 do
        if stateFunction[i].name = name then
            begin
                findFunctionIndex := i;
                break;
            end;
end;

function addFunctionEntry(name: String; IsProcedure: Boolean): Integer;
begin
    if findFunctionIndex(name) <> -1 then
        begin
            WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - ADD_FUNC - DUPLICATE >> ' + name);
            Halt(1);
        end;

    stateFunction[stateFunctionCount].name        := name;
    stateFunction[stateFunctionCount].returnType  := '';   // filled in later if 'r' assignment seen
    stateFunction[stateFunctionCount].isProcedure := IsProcedure;
    stateFunction[stateFunctionCount].paramCount  := 0;

    addFunctionEntry := stateFunctionCount;
    Inc(stateFunctionCount);
end;

function findArrayIndex(name: String): Integer;
var
    i: Integer;
begin
    findArrayIndex := -1;
    for i := 0 to stateArrayCount - 1 do
        if stateArray[i].name = name then
            begin
                findArrayIndex := i;
                break;
            end;
end;

function addArrayEntry(name: String; count: Integer; etype: TValType): Integer;
begin
    if findArrayIndex(name) <> -1 then
        begin
            WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - ADD_ARRAY - DUPLICATE >> ' + name);
            Halt(1);
        end;

    stateArray[stateArrayCount].name      := name;
    stateArray[stateArrayCount].elementCount := count;
    stateArray[stateArrayCount].elementType  := etype;
    stateArray[stateArrayCount].asmLabel  := 'arr_' + name;

    addArrayEntry := stateArrayCount;
    Inc(stateArrayCount);
end;

function arrayElemWidth(etype: TValType): Integer;
begin
    if etype = vtByte then
        arrayElemWidth := 1
    else
        arrayElemWidth := 8;  // vtNumber, vtFloat both 8 bytes
end;

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
    libBytes := 0;
    WriteLn('LOADING STANDARD LIBRARY');
    FillChar(buf, SizeOf(buf), 0);
    fd := fpOpen(stdlib_filename, O_RdOnly);
    libBytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);

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
    fd5 := fpOpen('bss.tmp', O_WRONLY OR O_CREAT OR O_TRUNC, 438);
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
    WriteOut('__argc: resq 1' + #10);
    WriteOut('__argv: resq 1' + #10);
    fd5 := fpOpen('bss.tmp', O_RdOnly, 438);
    bbytes := fpRead(fd5, bssbuf, SizeOf(bssbuf));
    fpWrite(fd2, bssbuf, bbytes);
    fpClose(fd5);
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

procedure closeIntermediateFile; begin fpClose(fd3); fpClose(fd4); fpClose(fd5); end;

// CODE GENERATION ===========================================
// ========================================================

// Local records set data that is then passed to the emit procs using this function
// goes through v (TValue) .vKind and uses
// that to decided what to put into the emit procedure
function makeParserSpeakASM(v: TValue): String;
begin   
    case v.vKind of
        kNone: begin WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - R2T - YOU PROMISED ME DATA AND GAVE ME NOTHING'); Halt(1); end;
        kReg: begin 
            if v.vType = vtFloat then
                makeParserSpeakASM := 'xmm0'
            else
                makeParserSpeakASM := 'rax';
        end;
        kLit: begin makeParserSpeakASM := IntToStr(v.vWordPayload); end;
        kMem: begin makeParserSpeakASM := '[rbp-' + IntToStr(v.vOffset) + ']'; end;
        kData: begin makeParserSpeakASM := '[' + v.vStringPayload + ']'; end;
        kArray: begin makeParserSpeakASM := '[' + v.vStringPayload + ' + ' + v.vIndexReg + '*' + IntToStr(v.vAScale) + ']'; end;
    end;
end;

// HELPERS ----------------------------------------------------------
procedure loadRAX(addr: String); begin WriteText('    mov rax, ' + addr + #10); end;
procedure loadRBX(addr: String); begin WriteText('    mov rbx, ' + addr + #10); end;
procedure loadXMM0(addr: String); begin WriteText('    movsd xmm0, ' + addr + #10); end;

// BLOCKS -----------------------------------------------------------
procedure emitGlobalBlock(); begin end;   // {V ...}
procedure emitStaticBlock(); begin end;   // {S ...}
procedure emitRecordBlock(); begin end;   // {R name ...}
procedure emitDirectiveBlock(); begin end; // {D ...}
procedure emitFileInclude(); begin end;   // ADD("file.rsk")

// FUNCTIONS -----------------------------------------------------------
procedure emitFN(fname : String); begin WriteText(fname + ':' + #10); end;

procedure emitFunctionSetup();
begin 
    WriteText('    push rbp' + #10);
    WriteText('    mov rbp, rsp' + #10);
    WriteText('    sub rsp, 128' + #10); // HARDCODED STACK, THE HORROR
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

function emitFloatConstant(float: String): TValue;
var
    v: TValue;
begin
    WriteData('   float_' + IntToStr(labelCounter) + ': dq ' + float + #10);
    v.vStringPayload := 'float_' + IntToStr(labelCounter);
    // flagging entires in the record 
    v.vKind := kData; // set type of output to data
    v.vType := vtFloat; // set actual type to float
    emitFloatConstant := v;
    Inc(labelCounter);
end;

function emitStringConstant(s: String): TValue;
var
    v: TValue;
    lbl: String;
    i: Integer;
    dataLine: String;
begin
    lbl := 'str_' + IntToStr(labelCounter);
    WriteData('   ' + lbl + ': dq ' + IntToStr(Length(s)) + #10);

    dataLine := '   db ';
    for i := 1 to Length(s) do
        begin
            if (Ord(s[i]) < 32) or (Ord(s[i]) > 126) then
                dataLine := dataLine + IntToStr(Ord(s[i])) + ', '
            else
                dataLine := dataLine + '`' + s[i] + '`, ';
        end;
    dataLine := dataLine + '0' + #10; // trailing NUL

    WriteData(dataLine);

    v.vKind          := kData;
    v.vType          := vtString;
    v.vStringPayload := lbl;

    emitStringConstant := v;
    Inc(labelCounter);
end;

// ARRAYS / MEMORY -----------------------------------------------------------

function emitAddressOf(variable: String): TValue;
var
    v: TValue;
begin
    WriteText('    lea rax, ' + variable + #10);
    v.vKind := kReg;
    v.vType := vtNumber;
    emitAddressOf := v;
end;      

procedure emitAssignString(variable, alabel: String);
begin
    WriteText('    lea rax, [' + alabel + ']' + #10);
    WriteText('    mov ' + variable + ', rax' + #10);
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

// VECTOR OPS -----------------------------------------------------------
procedure emitVecAdd(); begin end;   // ++
procedure emitVecMul(); begin end;   // **
procedure emitVecDiv(); begin end;   // //
procedure emitVecMod(); begin end;   // %%
procedure emitVecFMA(); begin end;   // *+
procedure emitVecCompoundAssign(); begin end; // :++=  :**=

// SYSTEM ----------------------------------

function emitSyscall(num: String; a: String; b: String; c: String): TValue;
var
    v: TValue;
begin 
    WriteText('    mov rax, ' + num + #10);
    WriteText('    mov rdi, ' + a + #10);
    WriteText('    mov rsi, ' + b + #10);
    WriteText('    mov rdx, ' + c + #10);
    WriteText('    syscall ' + #10);
    v.vKind := kReg;
    emitSyscall := v;
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
    WriteText(#10 + 'global _start' + #10);
    WriteText('_start:'+ #10);
    WriteText('  mov rax, [rsp]'+ #10);      // argc
    WriteText('  lea rbx, [rsp+8]'+ #10);    // argv
    WriteText('  mov [__argc], rax'+ #10);
    WriteText('  mov [__argv], rbx'+ #10);
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
function peekV(): String; begin peekV := t_val[position]; end;
function peekV2(): String; begin peekV2 := t_val[position+1]; end;
function peekV3(): String; begin peekV3 := t_val[position+2]; end;
function peek(): String; begin peek := t_type[position]; end;
function peek2(): String; begin peek2 := t_type[position+1]; end;
function peek3(): String; begin peek3 := t_type[position+2]; end;
function currentLine(): String; begin currentLine := intToStr(t_line[position]); end;
function computeOffset(offset: Integer): String; begin computeOffset := '[rbp-' + IntToStr(offset) + ']'; end;

function consume(): String; // Eat the next token and then remove it
begin
    consume := t_val[position]; // pull value (actual content of token)
    Inc(position);  // Increment counter to drop the token
end;

function varToMem(variable: String): TValue;
var
    i: Integer;
    v: TValue;
begin
    i := findLocalIndex(variable);
    if i = -1 then
        begin
            WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - VAR_TO_MEM - UNK SYMBOL>> ' + variable);
            Halt(1);
        end;
    v.vOffset := stateLocal[i].offset;
    if stateLocal[i].varType = 'FLOAT' then
            v.vType := vtFloat
        else
            v.vType := vtNumber;
    v.vKind := kMem;
    varToMem := v;
end;

function call(fname: String; returnsFloat: Boolean): TValue;
var
    v: TValue;
begin
    v.vKind := kReg;
    if returnsFloat then
        v.vType := vtFloat
    else
        v.vType := vtNumber;

    WriteText('    call ' + fname + #10);

    call := v;
end;

function emitMath(op: String; second: TValue; isFloat: Boolean): TValue;
var
    v: TValue;
    operand: String;
begin
    v.vKind := kReg;

    if isFloat then
        v.vType := vtFloat
    else
        v.vType := vtNumber;

    operand := makeParserSpeakASM(second);

    if isFloat then
        begin
            if      op = 'PLUS'  then emitAddFloat('xmm0', operand)
            else if op = 'MINUS' then emitSubFloat('xmm0', operand)
            else if op = 'STAR'  then emitMulFloat('xmm0', operand)
            else if op = 'SLASH' then emitDivFloat('xmm0', operand)
            else
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - EMIT_MATH_F - UNK OP >> ' + op);
                    Halt(1);
                end;
        end
    else
        begin
            if      op = 'PLUS'  then emitAdd('rax', operand)
            else if op = 'MINUS' then emitSub('rax', operand)
            else if op = 'STAR'  then emitMul('rax', operand)
            else if op = 'SLASH' then emitDiv('rax', operand)
            else
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - EMIT_MATH - UNK OP >> ' + op);
                    Halt(1);
                end;
        end;

    emitMath := v;
end;

procedure asmFunctionCalls(variable: String; argname: String);
var
    arrayIndex, functionIndex: Integer;
    idxVal: TValue;
begin
    if (variable = 'printw') or (variable = 'printf') then
        begin
            consume; // (
            argname := consume();

            if (peek() = 'LBRAC') or (peek() = 'LBRACE') or (peek() = 'BANG') then
                begin
                    arrayIndex := findArrayIndex(argname);
                    if arrayIndex = -1 then
                        begin
                            WriteLn(currentLine + '- UNK ARRAY >> ' + argname);
                            Halt(1);
                        end;

                    if peek() = 'BANG' then
                        begin
                            consume; // !
                            consume; // [
                        end
                    else
                        consume; // [ or {

                    idxVal := evaluateExpression(False);
                    WriteText('    mov rbx, ' + makeParserSpeakASM(idxVal) + #10);
                    consume; // ] or }

                    argname := '[' + stateArray[arrayIndex].asmLabel + ' + rbx*' +
                        IntToStr(arrayElemWidth(stateArray[arrayIndex].elementType)) + ']';
                end
            else if not isNumber(argname) then
                argname := makeParserSpeakASM(varToMem(argname));

            consume; // )

            if variable = 'printf' then
                functionPrintF(argname);
            if variable = 'printw' then
                functionPrintW(argname);
        end
    else
        begin
            functionIndex := findFunctionIndex(variable);
            if functionIndex = -1 then
                begin
                    WriteLn(currentLine + '- UNK FUNCTION >> ' + variable);
                    Halt(1);
                end;

            consume; // (
            if peek() <> 'RPAR' then
                arguementParser(functionIndex);
            consume; // )

            WriteText('    call ' + variable + #10);
        end;
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

            if isFloat then
                begin
                if op = 'PLUS' then result1 := StrToFloat(first) + StrToFloat(second)
                else if op = 'MINUS' then result1 := StrToFloat(first) - StrToFloat(second)
                else if op = 'STAR' then result1 := StrToFloat(first) * StrToFloat(second)
                else if op = 'SLASH' then result1 := StrToFloat(first) / StrToFloat(second);
                WriteLn('OPTIMIZATION - FLT');
                foldCode := (FloatToStr(result1));
                end 
            else
                begin
                if op = 'PLUS' then result2 := StrToInt(first) + StrToInt(second)
                else if op = 'MINUS' then result2 := StrToInt(first) - StrToInt(second)
                else if op = 'STAR' then result2 := StrToInt(first) * StrToInt(second)
                else if op = 'SLASH' then result2 := StrToInt(first) div StrToInt(second);
                WriteLn('OPTIMIZATION - FPT');
                foldCode := (IntToStr(result2));
            end;
end;

function WhoGoesThere(intruder: String): String;
var
    isFloat: Boolean;
    r: Integer;
begin
    r := 0;
    isFloat := False;

    if isNumber(intruder) then // RAW NUM
        begin
        if Pos('.', intruder) > 0 then
            isFloat := True;
        end
    else
        begin // VAR
            r := findLocalIndex(intruder);
            if r <> -1 then
                if stateLocal[r].varType = 'FLOAT' then
                    isFloat := True;
        end;
  
    r := findFunctionIndex(intruder);
            if r <> -1 then
                if stateFunction[r].returnType = 'FLOAT' then
                    isFloat := True;

    if isFloat then
        WhoGoesTHere := 'FLOAT'
    else
        WhoGoesTHere := 'QWORD';

end;

function resolveSyscall(): String;
var
    argument: String;
begin
    if peek() = 'AMP' then 
        begin
            consume;
            resolveSyscall := makeParserSpeakASM(emitAddressOf(makeParserSpeakASM(varToMem(consume)))); // fucking ugly
        end
    else
        begin
            argument := consume;
            if isNumber(argument) then
                resolveSyscall:= argument
            else
                resolveSyscall:= makeParserSpeakASM(varToMem(argument));
        end;
end;

// EVALUATORS AND BRANCHING -------------------------------------------------------

   { TKind = (kNone, kReg, kMem, kData, kLit);
    TValType = (vtNumber, vtFloat, vtString);

    TValue = record
        vKind:     TKind; // What type of info is passed to NASM, register, memory, literals?
        vType:     TValType; // vtNumber, vtFloat, vtString
        vWordPayload:  Int64; // the word
        vFltPayload:  Double; // the float
        vStringPayload:  String; // register names and data labels eg float_69
        vOffset:    Integer; // the actual offset
    end;}

//procedure foldCode(); begin end;

// shoves all tokens through an identification process before they are sent on their merry way
function tokenAssignment(): TValue;
var
    token: String;
    stripped: String;
    i, arrayIndex: Integer;
    v, indexVal: TValue;
begin
    if peek() = 'STRING' then
        begin
            token := consume;
            v := emitStringConstant(token);
            tokenAssignment := v;
            Exit;
        end;

    token := consume;

    if (peek() = 'LBRAC') or (peek() = 'LBRACE') or (peek() = 'BANG') then
        begin
            arrayIndex := findArrayIndex(token);
            if arrayIndex = -1 then
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - TA - UNK ARRAY >> ' + token);
                    Halt(1);
                end;

            if (peek() = 'LBRAC') and (stateArray[arrayIndex].elementType <> vtNumber) then
                begin WriteLn(currentLine + '- YOU HAVE FRUSTRATED THE COMPILER - CHECK ARRAY TYPE >> ' + token); Halt(1); end;
            if (peek() = 'LBRACE') and (stateArray[arrayIndex].elementType <> vtFloat) then
                begin WriteLn(currentLine + '- YOU HAVE FRUSTRATED THE COMPILER - CHECK ARRAY TYPE >> ' + token); Halt(1); end;
            if (peek() = 'BANG') and (stateArray[arrayIndex].elementType <> vtByte) then
                begin WriteLn(currentLine + '- YOU HAVE FRUSTRATED THE COMPILER - CHECK ARRAY TYPE >> ' + token); Halt(1); end;

            if peek() = 'BANG' then
                begin
                    consume; // !
                    consume; // [
                end
            else
                consume; // [ or {                          // eat [ { or !
            indexVal := evaluateExpression(False);
            WriteText('    mov rbx, ' + makeParserSpeakASM(indexVal) + #10);
            consume;                          // eat closing ] or }

            v.vKind          := kArray;
            v.vType          := stateArray[arrayIndex].elementType;
            v.vStringPayload := stateArray[arrayIndex].asmLabel;
            v.vIndexReg      := 'rbx';
            v.vAScale        := arrayElemWidth(stateArray[arrayIndex].elementType);

            tokenAssignment := v;
            Exit;
end;

    if isFloatLiteral(token) then // If it is a float then strip it and fill out the record
        begin
            stripped := token;
            if stripped[Length(stripped)] = 'f' then
                stripped := Copy(stripped, 1, Length(stripped) - 1);

            v := emitFloatConstant(stripped);
            v.vFltPayload := StrToFloat(stripped);
        end

    else if isNumber(token) then // same for just a number
        begin
            v.vKind         := kLit;
            v.vType         := vtNumber;
            v.vWordPayload  := StrToInt(token);
        end
    else
        begin
            i := findLocalIndex(token); // check if the token is a variable
            if i = -1 then
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - TOKEN_ASSIGNMENT - UNK SYMBOL >> ' + token);
                    Halt(1);
                end;

            v.vKind   := kMem;          // Kind: Memory
            v.vOffset := stateLocal[i].offset;  // assign offset 

            if stateLocal[i].varType = 'FLOAT' then  // if the variable that was identified is tagged as a float
                v.vType := vtFloat
            else
                v.vType := vtNumber;
        end;

    tokenAssignment := v;
end; 

// fucked, need to turn into evaluator and drop each arg result onto the stack
procedure arguementParser(functionIndex: Integer);
var
    isFloatArg: Boolean;
    argname: String;
    seenFloats, seenInts, argcounter: Integer;
begin
    isFloatArg := False;
    WriteLn('EXPRESSION EVAL - RPAR BRANCH (ARGUMENT PARSER)'); // DEBUG
    seenFloats := 0;
    seenInts := 0;
    argcounter := 0;

    repeat  // VERIFY LOOP
        isFloatArg := False;
        argname := consume(); // single arg

        if stateFunction[functionIndex].paramType[argcounter] = 'FLOAT' then
            isFloatArg := True;

        if not isNumber(argname) then
            argname := makeParserSpeakASM(varToMem(argname));

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
end;

function evaluateExpression(isFloat: Boolean): TValue;
var
    v, second: TValue;
    op: String;
    fname: String;
    functionIndex: Integer;
    returnsFloat: Boolean;
    num, a, b, c: String;
begin
    returnsFloat := False;

    // address branch
    if peek() = 'AMP' then
        begin
            consume;
            emitAddressOf(makeParserSpeakASM(varToMem(consume)));
            v.vKind := kReg;
            v.vType := vtNumber;
            Exit(v);
        end;

    // raw syscall branch
    if (peekV() = 'sys') and (peek2() = 'LPAR') then
        begin
            consume; consume;
            num := resolveSyscall();
            consume; //
            a := resolveSyscall();
            consume;
            b := resolveSyscall();
            consume;
            c := resolveSyscall();
            consume;
            emitSyscall(num, a, b, c);
            v.vKind := kReg;
            v.vType := vtNumber;
            Exit(v);
        end;

    // function call branch
    if (peek() = 'IDENTIFIER') and (peek2() = 'LPAR') then
        begin
            fname := consume();

            if WhoGoesThere(fname) = 'FLOAT' then
                returnsFloat := True;

            functionIndex := findFunctionIndex(fname);
            if functionIndex = -1 then
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - EE - GARBAGE FUNCTION CALL >> ' + fname);
                    Halt(1);
                end;

            consume(); // (
            if peek() <> 'RPAR' then
                arguementParser(functionIndex);
            consume(); // )

            v := call(fname, returnsFloat);
            Exit(v);
        end
    else
        begin
            // new fancy mechanism replacing first := consume. now it is a
            // record and is auto type checked etc
            v := tokenAssignment;

            if peek() = 'CARET' then
                begin
                    consume;
                    WriteText('    mov rax, ' + makeParserSpeakASM(v) + #10);
                    WriteText('    mov rax, [rax]' + #10);
                    v.vKind := kReg;
                    v.vType := vtNumber;
                end;

            if (peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH') then
                begin
                    if v.vType = vtFloat then
                        loadXMM0(makeParserSpeakASM(v))
                    else
                        loadRAX(makeParserSpeakASM(v));

                    while (peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH') do
                        begin
                            op := peek();
                            consume;
                            second := tokenAssignment;
                            v := emitMath(op, second, isFloat);
                        end;
                end;

            evaluateExpression := v;
        end;
end;

// PARSER ------------------------------------------------------------------------

procedure discriminateIdentifier();
var
    variable, twoname, argname, discoveredVariableType, addr: String;
    rightside: TValue;
    existingIndex, functionIndex, arrayIndex: Integer;
    isDeclared, isReturn, isFloat: boolean;
    symIndex: Integer;
    v, indexVal: TValue;

begin
    symIndex := 0;
    isDeclared := False;
    isReturn := False;
    isFloat := False;
    argname := '';

    variable := consume(); // consume the a in a := 5

    if variable = 'r' then isReturn := True;

    //WriteLn('discrim start: variable=' + variable + ' position=' + IntToStr(position)); // DEBUG

    symindex := findLocalIndex(variable);
    if symindex <> -1 then
        isDeclared := True;

    if (peek() = 'LBRAC') or (peek() = 'LBRACE') or (peek() = 'BANG') then
        begin
            arrayIndex := findArrayIndex(variable);
            if arrayIndex = -1 then
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - DI - I DONT KNOW WHAT THIS IS BUT ITS NOT AN ARRAY >>' + variable);
                    Halt(1);
                end;

            if (peek() = 'LBRAC') and (stateArray[arrayIndex].elementType <> vtNumber) then
                begin WriteLn(currentLine + '- YOU HAVE FRUSTRATED THE COMPILER - CHECK ARRAY TYPE >> ' + variable); Halt(1); end;
            if (peek() = 'LBRACE') and (stateArray[arrayIndex].elementType <> vtFloat) then
                begin WriteLn(currentLine + '- YOU HAVE FRUSTRATED THE COMPILER - CHECK ARRAY TYPE >> ' + variable); Halt(1); end;
            if (peek() = 'BANG') and (stateArray[arrayIndex].elementType <> vtByte) then
                begin WriteLn(currentLine + '- YOU HAVE FRUSTRATED THE COMPILER - CHECK ARRAY TYPE >> ' + variable); Halt(1); end;

            if peek() = 'BANG' then
                begin
                    consume; // !
                    consume; // [
                end
            else
                consume; // [ or {                        // eat [ { or !
            indexVal := evaluateExpression(False);
            WriteText('    mov rbx, ' + makeParserSpeakASM(indexVal) + #10);
            consume;                          // eat closing ] or }

            v.vKind           := kArray;
            v.vType           := stateArray[arrayIndex].elementType;
            v.vStringPayload  := stateArray[arrayIndex].asmLabel;
            v.vIndexReg       := 'rbx';
            v.vAScale         := arrayElemWidth(stateArray[arrayIndex].elementType);

            consume;                          // eat :=
            rightside := evaluateExpression(stateArray[arrayIndex].elementType = vtFloat);

            addr := makeParserSpeakASM(v);

            if stateArray[arrayIndex].elementType = vtFloat then
                emitAssignFloat(addr, makeParserSpeakASM(rightside))
            else if stateArray[arrayIndex].elementType = vtByte then
                begin
                    if makeParserSpeakASM(rightside) <> 'rax' then
                        WriteText('    mov rax, ' + makeParserSpeakASM(rightside) + #10);
                    WriteText('    mov ' + addr + ', al' + #10);
                end
            else
                emitAssign(addr, makeParserSpeakASM(rightside));
        end

    else if peek() = 'ASSIGN' then // if its a := x etc etc
        begin
            if isDeclared = True then
                begin // turn into something nasm understands instead of just "variable"
                    variable := computeOffset(stateLocal[symIndex].offset);
                     isFloat := (stateLocal[symIndex].varType = 'FLOAT'); 
                    consume(); // :=
                    rightside := evaluateExpression(isFloat);
                    isFloat := (stateLocal[symIndex].varType = 'FLOAT'); // wasnt verifiying
                        if rightside.vType = vtString then
                            emitAssignString(variable, rightside.vStringPayload)
                        else if isFloat then
                            emitAssignFloat(variable, makeParserSpeakASM(rightside))
                        else
                            emitAssign(variable, makeParserSpeakASM(rightside));
                    
                        WriteLn('ASSIGN BRANCH - DECLARED'); // DEBUG
                end
            else
                begin
                    // not checking everything in the right side for a float, need to implement fix 
                    discoveredVariableType := WhoGoesTHere(peek2);
                    if discoveredVariableType = 'QWORD' then
                        discoveredVariableType := 'NUMBER';

                    if peek2() = 'IDENTIFIER' then // if var exists grab type info and flag for right assignment
                        begin
                            twoname := peekV2();
                            existingIndex := findLocalIndex(twoname);
                            if existingIndex <> -1 then
                                discoveredVariableType := stateLocal[existingIndex].varType;
                        end;

                    if (peek2() = 'IDENTIFIER') and (peek3() = 'LPAR') then // grab function return val type and flag
                        begin
                            twoname := peekV2();
                            functionIndex := findFunctionIndex(twoname);
                            if functionIndex <> -1 then
                                discoveredVariableType := stateFunction[functionIndex].returnType;
                        end;

                    isFloat := (discoveredVariableType = 'FLOAT');
                    symIndex := addLocalEntry(variable, discoveredVariableType);
                    variable := computeOffset(stateLocal[symIndex].offset);

                    if isReturn then
                        begin
                            functionIndex := findFunctionIndex(currentFN);
                            stateFunction[functionIndex].returnType := discoveredVariableType;
                            variable := computeOffset(stateLocal[symIndex].offset);
                            returnAddr := computeOffset(stateLocal[symIndex].offset);
                        end;

                    consume(); // :=

                    rightside := evaluateExpression(isFloat);
                                     
                    if rightside.vType = vtString then
                        emitAssignString(variable, rightside.vStringPayload)
                    else if isFloat then
                        emitAssignFloat(variable, makeParserSpeakASM(rightside))
                    else
                        emitAssign(variable, makeParserSpeakASM(rightside));

                        WriteLn('ASSIGN BRANCH - UNDECLARED'); // DEBUG
                    end;
        end
        else
            begin //REPLACE THEESE
               asmFunctionCalls(variable, argname);
            end;
end;

// ONE-OFFS ------------
// CURRENT STATUS
// Loops? Fucked, Conditionals? Fucked.
procedure loopWhile();
var
    loopvar, loopcond, looplimit, toplabel, endlabel: String;
begin
    consume; //consume LW 
    consume; // consume LPAR
    loopvar := makeParserSpeakASM(varToMem(consume));
    loopcond := peek; // grab TYPE not the damn value
    consume; // now eat it
    looplimit := consume;
    if not isNumber(looplimit) then
        looplimit := makeParserSpeakASM(varToMem(looplimit)); // prevents the loop from getting sassy with var limit
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
    else if loopcond = 'MORE' then
        WriteText('    jle ' + endlabel + #10)      // jump if less or equal
    else if loopcond = 'EQUAL' then
        WriteText('    jne ' + endlabel + #10);     // jump if not equa  

    frames[frameDepth].kind := fkLoopW;
    frames[frameDepth].topLabel := toplabel;
    frames[frameDepth].endLabel := endlabel;
    Inc(frameDepth);
    bodyPending := True;
end;

// broken
procedure loopFor();
var
    loopvar, loopstart, looplimit, toplabel, endlabel: String;
begin
    consume; //consume LF
    consume; // consume LPAR
    frames[frameDepth].loopvaro := makeParserSpeakASM(varToMem(consume));
    consume; // :=
    loopstart := consume; // 0
    consume; // until
    looplimit := consume;
    if not isNumber(looplimit) then
        looplimit := makeParserSpeakASM(varToMem(looplimit));
    consume; // RPAR
    WriteText('    mov rax, ' + loopstart + #10);
    WriteText('    mov ' + loopvar + ', rax' + #10);

    toplabel := labelMaker('LF');
    endlabel := labelMaker('LF');
    emitLabel(toplabel);

    WriteText('    mov rax, ' + loopvar + #10);
    WriteText('    cmp rax, ' + looplimit + #10);
    WriteText('    jge ' + endlabel + #10);

    frames[frameDepth].kind := fkLoopF;
    frames[frameDepth].topLabel := toplabel;
    frames[frameDepth].endLabel := endlabel;
    Inc(frameDepth);
    bodyPending := True;
end;

function condWhen(): Boolean;
var
    condvar, condition, condlimit, endlabel: String;
begin
    consume; //consume W
    consume; // consume LPAR
    condvar := makeParserSpeakASM(varToMem(consume));
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

    frames[frameDepth].kind := fkCond;
    frames[frameDepth].endLabel := endlabel;
    Inc(frameDepth);
    bodyPending := True;
end;

// chains: consecutive IFs act as if/elseif, closed by a mandatory E
// if you try and nest if else within if else expect heartache
function condIf(): Boolean;
var
    condvar, condition, condlimit, endlabel: String;
begin
    consume; //consume I
    consume; // consume LPAR
    condvar := makeParserSpeakASM(varToMem(consume));
    condition := peek; // grab TYPE not the damn value
    consume; // now eat it
    condlimit := consume; // 0
    consume; // RPAR

    if not isNumber(condlimit) then
        condlimit := makeParserSpeakASM(varToMem(condlimit));

    endlabel := labelMaker('I');   // false-jump target: next IF/E in the chain

    if not inChain then
        begin
            chainEndLabel := labelMaker('IEND'); // whole chain shares one exit
            inChain := True;
        end;

    WriteText('    mov rax, ' + condvar + #10);
    WriteText('    cmp rax, ' + condlimit + #10);

    if condition = 'LESSEQUAL' then  // all the shit is backwards here
        WriteText('    jg ' + endlabel + #10)
    else if condition = 'LESS' then
        WriteText('    jge ' + endlabel + #10)
    else if condition = 'GREQUAL' then
        WriteText('    jl ' + endlabel + #10)
    else if condition = 'MORE' then
        WriteText('    jle ' + endlabel + #10)
    else if condition = 'EQUAL' then
        WriteText('    jne ' + endlabel + #10);

    frames[frameDepth].kind     := fkCondIf;
    frames[frameDepth].endLabel := endlabel;      // this branch's false-jump target
    frames[frameDepth].topLabel := chainEndLabel;  // reused field: whole chain's shared exit
    Inc(frameDepth);
    bodyPending := True;

    condIf := True;
end;

function condElse(): Boolean;
var
    condvar, condition, condlimit, endlabel: String;
begin
    consume; 

    frames[frameDepth].kind     := fkCondElse;
    frames[frameDepth].endLabel := chainEndLabel; // E's close lands the whole chain here
    Inc(frameDepth);
    bodyPending := True;
    inChain := False; 
    condElse := True;
end;

function constructFunction(): Boolean;
var
    paramName, paramType: String;
    functionIndex, paramIndex: Integer;
    isProcedure: Boolean;
begin
                constructFunction := (peek() = 'P');
                isProcedure := (peek() = 'P');
                consume;
                currentFN := consume;
                emitFN(currentFN);
                functionIndex := addFunctionEntry(currentFN, isProcedure);
                frameOffset := 0;
                argCount := 0;
                stateLocalCount := 0;
  
                paramPending := False;
                if peek() = 'LPAR' then // arg detection
                    begin
                        consume; // (
                        if peek() <> 'RPAR' then 
                        begin
                       repeat
                            paramName := consume;
                            paramType := 'NUMBER';

                            if peek() = 'COLON' then
                                begin
                                    consume; // consume colon
                                    if peekV() = 'f' then
                                        begin
                                            paramType := 'FLOAT';
                                            consume; // consume f
                                        end
                                    else
                                        begin
                                            // STRING EVENTUALLY
                                        end;
                                end;

                            paramIndex := addLocalEntry(paramName, paramType);

                            stateFunction[functionIndex].paramType[stateFunction[functionIndex].paramCount] := paramType;
                            Inc(stateFunction[functionIndex].paramCount);

                            paramPending := True;
                            Inc(argCount);

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
    i, seenFloats, seenInts, arrIndex: Integer;
    varname, countStr, valStr: String;
begin
    i := 0;
    position := 0;
    repeat
        case peek() of
            'F', 'P': begin 
                isProcedure := constructFunction();
            end;
            'LPAR': begin consume; end;
            'RPAR': begin consume; end;
            'LBRACE': begin 
                consume;
                if bodyPending then
                    begin
                        bodyPending := False;
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
                                            if stateLocal[i].varType = 'FLOAT' then
                                                begin
                                                    WriteText('   movsd [rbp-' + intToStr(stateLocal[i].offset) + '], xmm' + IntToStr(seenFloats) + #10);
                                                    Inc(seenFloats);
                                                end
                                            else
                                                begin
                                                    WriteText('    mov [rbp-' + IntToStr(stateLocal[i].offset) + '], ' + intregs[seenInts] + #10);
                                                    Inc(seenInts);
                                                end;
                                        end;
                                    paramPending := False;
                                end;
                        end;
                end;
            'RBRACE': begin 
                consume;
                if frameDepth > 0 then
                    begin
                        Dec(frameDepth);
                        if frames[frameDepth].kind = fkLoopF then
                            WriteText('    inc qword ' + frames[frameDepth].loopvaro + #10);
                        if (frames[frameDepth].kind = fkLoopW) or (frames[frameDepth].kind = fkLoopF) then
                            WriteText('    jmp ' + frames[frameDepth].topLabel + #10);
                        if frames[frameDepth].kind = fkCondIf then
                            begin
                                WriteText('    jmp ' + frames[frameDepth].topLabel + #10); 
                                emitLabel(frames[frameDepth].endLabel);                    
                            end
                        else if frames[frameDepth].kind = fkCondElse then
                            emitLabel(frames[frameDepth].endLabel); 
                        emitLabel(frames[frameDepth].endLabel);
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
            'V': begin consume; end;
            'S': begin consume; end;
            'W': begin condWhen(); end;
            'IF': begin condIF; end;
            'E': begin condElse; end;
            'LF': begin loopFor(); end;
            'LW': begin loopWhile(); end;
            'VARBLOCK': begin
                consume; // |V
                while peek() <> 'PIPE' do
                    begin
                        varname := consume;

                        if peek() = 'LBRAC' then          // qword array
                            begin
                                consume; 
                                countStr := consume;      
                                consume; 
                                arrIndex := addArrayEntry(varname, StrToInt(countStr), vtNumber);
                                WriteBSS('    ' + stateArray[arrIndex].asmLabel + ': resb ' +
                                    IntToStr(StrToInt(countStr) * arrayElemWidth(vtNumber)) + #10);
                            end
                        else if peek() = 'BANG' then       // byte array
                            begin
                                consume; 
                                if peek() <> 'LBRAC' then
                                    begin
                                        WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - VARBLOCK - YOU TRYNA GET WEIRD WITH ME BOY? >> ' + peek());
                                        Halt(1);
                                    end;
                                consume; // [
                                countStr := consume;
                                consume; // ]
                                arrIndex := addArrayEntry(varname, StrToInt(countStr), vtByte);
                                WriteBSS('    ' + stateArray[arrIndex].asmLabel + ': resb ' +
                                    IntToStr(StrToInt(countStr) * arrayElemWidth(vtByte)) + #10);
                            end
                        else if peek() = 'LBRACE' then     // float array
                            begin
                                consume; // {
                                countStr := consume;
                                consume; // }
                                arrIndex := addArrayEntry(varname, StrToInt(countStr), vtFloat);
                                WriteBSS('    ' + stateArray[arrIndex].asmLabel + ': resb ' +
                                    IntToStr(StrToInt(countStr) * arrayElemWidth(vtFloat)) + #10);
                            end
                        else if peek() = 'ASSIGN' then     // global var BROKEN BROKEN NOT DONE 
                            begin
                                consume; // :=
                                valStr := consume;
                                //addGlobalEntry(varname, 'NUMBER');
                                //WriteData('   g_' + varname + ': dq ' + valStr + #10);
                            end
                        else
                            begin
                                WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - VARBLOCK - YOU HAVE DISGRACED MY DECLARATIONS WITH YOUR FILTH>> ' + peek() + ' ' + peekV());
                                Halt(1);
                            end;
                    end;
                consume; 
            end;
            'STATICBLOCK': begin 
                consume; // placeholder
            end;
            'RECORDBLOCK': begin 
                consume; // placeholder
            end
            else
                begin
                    WriteLn(currentLine + '- I CANT BELIEVE YOUVE DONE THIS - PARSER - YOU HAVE FED ME GARBAGE>> ' + peek() + ' ' + peekV());
                    Halt(1);
                end;
        end;
    until position >= t_count;
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

    procedure assignSingleChar(Tvalue: String; Ttype: String);
    begin
        t_type[t_count] := Ttype;
        t_val[t_count] := Tvalue;
        t_line[t_count] := linecount;
        Inc(t_count);
    end;

    procedure assignDoubleChar(Tvalue: String; Ttype: String);
    begin
        t_type[t_count] := Ttype;
        t_val[t_count] := Tvalue;
        t_line[t_count] := linecount;
        isMultiple := True;
        Inc(t_count);
        Inc(i);
    end;

    function collect(word: String): String;
    begin
        collect := word + buf[i];  // Collect words, add charachters to word
        Inc(i); // Increment position in file, +1 charachter
    end;

begin
    linecount := 1;
    isKeyword := False;
    isFloat :=  False;
    word := '';
    t_count := 0;

    for i := 0 to 1023 do
        begin
            t_type[i] := '';
            t_val[i] := '';
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
                    ',': assignSingleChar(',', 'COMMA');
                    '|': assignSingleChar('|', 'PIPE');
                    ':': assignSingleChar(':', 'COLON');
                    '!': assignSingleChar('!', 'BANG');
                    '&': assignSingleChar('&', 'AMP');
                    '^': assignSingleChar('^', 'CARET');

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
                            word := collect(word);
                        end;
              
                        isKeyword := keywordCheck(UpperCase(word)); 
                        if isKeyword then  
                            begin
                                t_type[t_count] := UpperCase(word);
                                WriteLn(UpperCase(word)); // DEBUG PRINT
                            end
                            else
                                begin
                                t_type[t_count] := 'IDENTIFIER';
                                end;

                        t_val[t_count] := word;
                        Inc(t_count);
                        Dec(i);  
                    end

                else if buf[i] in ['0'..'9'] then
                begin
                    word := '';
                    isFloat := False;
                    while buf[i] in ['0'..'9', '.', 'f'] do
                        begin
                            word := collect(word);
                        end;
                    
                   if (Pos('.', word) > 0) or (Pos('f', word) > 0) then
                        isFloat := True;

                    if isFloat then
                            assignSingleChar(word,'FLOAT')
                    else
                            assignSingleChar(word,'NUMBER');

                    Dec(i);
              
                end

                else if buf[i] = #39 then
                begin
                    word := '';
                    Inc(i); // skip opening quote
                    while buf[i] <> #39 do
                    begin
                        if buf[i] = '\' then
                            begin
                                Inc(i); // move to the escape char
                                case buf[i] of
                                    'n': word := word + #10;
                                    't': word := word + #9;
                                    '\': word := word + '\';
                                    #39: word := word + #39;
                                else
                                    word := word + buf[i]; // unknown escape, pass through literally
                                end;
                                Inc(i); // move past the escape char
                            end
                        else
                            word := collect(word); // normal char, existing behavior
                    end;
                    assignSingleChar(word,'STRING');
                end;
                
            end; 
        end; 
        Inc(i); // Increment position in buffer
    until i >= bytes; 

    i := 0;
    for i := 0 to t_count - 1 do // print the lexer output 
        WriteLn(IntToStr(i) + ': ' + t_type[i] + '  ' + t_val[i]);
end;

// INIT ============================================

procedure arrayInit();
var
    i: Integer;
begin
    i := 0;
    frameOffset := 0;

    for i := 0 to 255 do
        t_line[i] := 0;

    FillChar(loop_TLabel, SizeOf(loop_TLabel), 0);
    FillChar(loop_ELabel, SizeOf(loop_ELabel), 0);
    FillChar(conditional_ELabel, SizeOf(conditional_ELabel), 0);
    FillChar(frames, SizeOf(frames), 0);
    stateLocalCount := 0;
    stateGlobalCount := 0;
    stateFunctionCount := 0;
    deleteFile('intermediate.asm');
    deleteFile('text.tmp');
    deleteFile('data.tmp'); 
    conditionalBodyNext := False;
    loopBodyNext := False;
    conditionalDepth := 0;
    loopDepth := 0;
    frameDepth := 0;
    bodyPending := False;
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

