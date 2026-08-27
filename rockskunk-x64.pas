{$H+}{$C+}{$S+}{$Q+}{$R+}
program rockskunk_x64;
uses
    BaseUnix, SysUtils, Unix, StrUtils, Optimizer, IO;

const
    intRegs: array[0..5] of String = ('rdi', 'rsi', 'rdx', 'rcx', 'r8', 'r9'); // SYSV ABI
    acceptedKeywords: array[0..15] of String = // MAKE SURE TO UPDATE KEYWORD CHECK WHEN ADDING
    ('ADD', 'F', 'LF', 'LW', 'W', 'IF', 'BREAK', 'LOCATE', 'E', 'P', 'OR', 'AND', 'NOR', 'XOR', 'CALL', 'DO');

    // LIMITS
    FILEBUF_SIZE = 67108864; // 64MB if you are a madman with the DO loops
    INITIAL_TOKEN_CAP = 4096;
    INITIAL_ARRAY_CAP = 256;
    INITIAL_RECORD_CAP = 256;
    INITIAL_FUNC_CAP = 128;
var
    Debug: Boolean = True; // TOGGLE DEBUG OUTPUT

    // Tokens
    tokenKind, tokenValue: Array of String;
    t_line: Array of Integer;

    // Control Flow
    cfKind, cfTLabel, cfELabel, cfLVar: Array[0..64] of String;
    cfDepth: Integer;
    chainContinuing: Boolean;

    // for capturing return types so assingment to function return knows whats up
    return_FName: array of String;
    return_FType: array of String;
    return_FCount: Integer;

    // tracks types and persists with new functions so can fianlly just call func(a, b, c) typeless
    param_FName:  array of String;
    param_FIndex: array of Integer; // pos within function (1, 2, 3 ,4)
    param_FType:  array of String;
    paramOffset: array of Integer;
    param_FCount: Integer;
    paramPending, awaitingFunctionOpen: Boolean;

    // Symbol Table
    symName, symType: array[0..1023] of String;
    symOffset: array[0..1023] of Integer;
    aName, aType, aSize: array of String;
    recName, recOffsets, recSize, recFields: array of String;

    currentFN: String;
    returnAddr: String;
    isProcedure: Boolean;

    frameOffset, labelCounter, position, symCount, aCount, recCount, argCount, tokenCount, fstackPosition: LongInt;

{
   DO NOT FORGET LIST ====
   REMEMBER REDO ASM OUTPUT PRIMITIVES
   PASCAL FFI
   VECTORS
   REGISTER ALLOC
   SIGNED VS UNSIGNED WORDS, CURRENTLY BEING RECKLESS, DECIDE
}

// Forward Declarations

function WhoGoesThere(intruder: String): String; forward;
function evaluateExpression(isFloat: Boolean): String; forward;
function theOracle(var isFloat: Boolean): String; forward;
function loopLocate(): Boolean; forward;

procedure dispatch(); forward;
procedure doubleTokenCapacity(); forward;
procedure doubleArrayCapacity(); forward;
procedure doubleReturnCapacity(); forward;
procedure doubleParamCapacity(); forward;
procedure doubleParamOffsetCapacity(); forward;

// DEBUG

procedure hardFault(location, input: String);
begin
   if Debug = False then Exit else begin
         WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - ' + location + ' - UNK SYMBOL>> ' + input);
            Halt(1);
    end;
end;

procedure statusMessage(input: String);
begin
    if Debug = False then Exit else
         WriteLn(IntToStr(t_line[position]) + ' - ' + input);
end;

// HELPERS =================================================
// ========================================================

function matchName(variable: String; which: String): Boolean;
var
    i: LongInt;
begin
    matchName := False;
    if which = 'ARRAY' then
    begin
        for i := 0 to aCount - 1 do
            if variable = aName[i] then
                matchName := True;
    end
    else if which = 'SYM' then
    begin
        for i := 0 to symCount - 1 do
            if variable = symName[i] then
                matchName := True;
    end
    else if which = 'PARAM' then
    begin
        for i := 0 to param_FCount - 1 do
            if variable = param_FName[i] then
                matchName := True;
    end
    else if which = 'RETURN' then
    begin
        for i := 0 to return_FCount - 1 do
            if variable = return_FName[i] then
                matchName := True;
    end
    else
        statusMessage('YOU HAVE FRUSTRATED THE COMPLIER - MATCHNAME - WRONG SEARCH TYPE');
end;

function matchType(variable, which: String): String;
var
    i: LongInt;
begin
    if which = 'ARRAY' then
    begin
        for i := 0 to aCount - 1 do
            if variable = aName[i] then
                matchType := aType[i];
    end
    else if which = 'SYM' then
    begin
        for i := 0 to symCount - 1 do
            if variable = symName[i] then
                matchType := symType[i];
    end
    else if which = 'PARAM' then
    begin
        for i := 0 to param_FCount - 1 do
            if variable = param_FName[i] then
                matchType := param_FType[i];
    end
    else if which = 'RETURN' then
    begin
        for i := 0 to return_FCount - 1 do
            if variable = return_FName[i] then
                matchType := return_FType[i];
    end
    else
        statusMessage('YOU HAVE FRUSTRATED THE COMPLIER - MATCHTYPE - WRONG SEARCH TYPE');
end;

function matchIndex(variable, which: String): Integer;
var
    i: LongInt;
begin
    matchIndex := -1; // never had a false and all hell broke loose
    if which = 'ARRAY' then
    begin
        for i := 0 to aCount - 1 do
            if variable = aName[i] then
                matchIndex := i;
    end
    else if which = 'SYM' then
    begin
        for i := 0 to symCount - 1 do
            if variable = symName[i] then
                matchIndex := i;
    end
    else if which = 'PARAM' then
    begin
        for i := 0 to param_FCount - 1 do
            if variable = param_FName[i] then
                matchIndex := i;
    end
    else if which = 'RETURN' then
    begin
        for i := 0 to return_FCount - 1 do
            if variable = return_FName[i] then
                matchIndex := i;
    end
    else
        statusMessage('YOU HAVE FRUSTRATED THE COMPLIER - MATCHINDEX - WRONG SEARCH TYPE');
end;

// more complicated than other lookups, still working out details
function recordIdent(variable: String; which: String): Integer;
var
    i: LongInt;
begin
    recordIdent := -1;
    if which = 'NAME' then
    begin
        for i := 0 to recCount - 1 do
            if variable = recName[i] then
                recordIdent := i; //INDEX
    end
    else if which = 'OFFSETS' then // // need to adjust so one size is picked up in field string
    begin
        for i := 0 to recCount - 1 do
            if variable = recOffsets[i] then
                recordIdent := i; // INDEX
    end
    else if which = 'SIZE' then
    begin
        for i := 0 to recCount - 1 do
            if variable = recSize[i] then
                recordIdent := i; //SIZE
    end
    else if which = 'FIELDS' then
    begin
        for i := 0 to recCount - 1 do
            if variable = recFields[i] then // need to adjust so one field is picked up in field string
                recordIdent := i; // INDEX
    end
    else
        statusMessage('YOU HAVE FRUSTRATED THE COMPLIER - RECORDIDENT - WRONG SEARCH TYPE');
end;

function keywordCheck(word: String): Boolean; // Flag keywords
var
    i: Integer;
begin
    keywordCheck := False;
    for i := 0 to 15 do
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
    i, last, start: Integer;
begin
    isNumber := False;
    if Length(token) = 0 then Exit;
    last := Length(token);
    if token[last] = 'f' then
        Dec(last);

    start := 1;
    if token[1] = '-' then
        start := 2;

    if start > last then Exit;

    isNumber := True;
    for i := start to last do
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

// EMMITERS ===================================================================================================
// HELPERS ----------------------------------------------------------

procedure loadRAX(addr: String); begin WriteText('    mov rax, ' + addr + #10); end;
procedure loadRBX(addr: String); begin WriteText('    mov rbx, ' + addr + #10); end;
procedure loadXMM0(addr: String); begin WriteText('    movsd xmm0, ' + addr + #10); end;

// FUNCTIONS -----------------------------------------------------------

procedure emitFN(fname : String); begin WriteText(fname + ':' + #10); end;

procedure emitFunctionSetup();
begin
    statusMessage('HELLO FUNCTION');
    WriteText('    push rbp' + #10);
    WriteText('    mov rbp, rsp' + #10);
    WriteText('    sub rsp, ');
    fstackPosition := FpLSeek(fd3, 0, Seek_Cur);
    WriteText('0000000128' + #10);
end;

procedure emitFunctionTeardown(result: String; isProcedure: Boolean);
var
    rcheck, paddedSize: String;
    isFloat: Boolean;
    savedPos: Int64;
    alignedSize: Integer;
begin
    statusMessage('GOODBYE FUNCTION');
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

    // BEHOLD THE ALIGNER OF STACKS, KEEPER OF BALANCE
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
    if value <> 'rax' then // if i didnt do this i get mov rax, rax
        WriteText('    mov rax, ' + value + #10);
    WriteText('    mov ' + variable + ', rax' + #10);
end;

procedure emitAssignArray(variable : String; value : String; atype: String);
begin
    if aType = 'BYTE' then
        begin
            if value <> 'rax' then // if i didnt do this i get mov rax, rax
                    WriteText('    mov rax, ' + value + #10);
                    WriteText('    mov byte ' + variable + ', al' + #10);
        end
    else
        begin
    if value <> 'rax' then  // if i didnt do this i get mov rax, rax
            WriteText('    mov rax, ' + value + #10);
            WriteText('    mov ' + variable + ', rax' + #10);
        end;
end;

procedure emitAssignFloat(variable : String; value : String);
begin
    if value = 'rax' then // let floats play with pointers
        WriteText('    movq xmm0, rax' + #10)
    else if isNumber(value) then
    begin // keeps getting sassy about being passed normal registers
        WriteText('    mov rax, ' + value + #10);
        WriteText('    cvtsi2sd xmm0, rax' + #10);
    end
    else if value <> 'xmm0' then
        WriteText('    movsd xmm0, ' + value + #10);
    WriteText('    movsd ' + variable + ', xmm0' + #10);
end;

function emitFloatConstant(float: String): String;
begin
        WriteData('   float_' + IntToStr(labelCounter) + ': dq ' + float + #10);
        emitFloatConstant := 'float_' + IntToStr(labelCounter);
        Inc(labelCounter);
end;

// note to self; making a length label and a datalabel seprate, no matter how much it sounds like, does not make
// a length prefixed string. You will fight pointer math for quite some time before you realize that
// to labels mean two locations in memory, dumbass.
function emitStringConstant(content: String): String;
var
    sLength, i: LongInt;
    theOneTrueEntry: String;
    inQuote: Boolean;
begin
    inQuote := False;
    theOneTrueEntry := '';
    sLength := length(content);
    for i := 1 to sLength do
    begin
        if (content[i] >= #32) and (content[i] <> #39) then // so pascal doesnt get sassy about '' inside ''
            begin
                if not inQuote then
                begin
                    if theOneTrueEntry <> '' then theOneTrueEntry := theOneTrueEntry + ', '; // split for nasm
                        theOneTrueEntry := theOneTrueEntry + #39; // close token
                    inQuote := True;
                end;
                theOneTrueEntry := theOneTrueEntry + content[i];
            end
        else  // if its a number or a ' then close the quotes and output it as ascii code
        begin
            if inQuote then
            begin
                theOneTrueEntry := theOneTrueEntry + #39;
                inQuote := False;
            end;
            if theOneTrueEntry <> '' then theOneTrueEntry := theOneTrueEntry + ', ';
            theOneTrueEntry := theOneTrueEntry + IntToStr(Ord(content[i]));
        end;
    end;

    if inQuote then // close the straggler
        theOneTrueEntry := theOneTrueEntry + #39;

    if theOneTrueEntry <> '' then theOneTrueEntry := theOneTrueEntry + ', '; // null terminator baby
    theOneTrueEntry :=theOneTrueEntry + '0';

    WriteData('   str_' + IntToStr(labelCounter) + ': dq ' + IntToStr(sLength) + #10 + 'db ' + theOneTrueEntry + #10);

    emitStringConstant := 'str_' + IntToStr(labelCounter);
    Inc(labelCounter);
end;

function functionBytesToString(): String; // for my battle with readLn
begin
end;

// ARRAYS / MEMORY -----------------------------------------------------------

function emitAddressOf(variable: String): String; // &a
begin
        WriteText('    lea rax, ' + variable + #10);
        emitAddressOf := 'rax';
end;

function emitDereference(variable: String): String; // := x^
begin
        WriteText('    mov rax, ' + variable + #10); // load pointers value (addr)
        WriteText('    mov rax, [rax]' + #10); // use that register as memory and read through it
        emitDereference := 'rax';
end;

function emitWritePointer(variable, value: String): String; // x^ :=
begin
        WriteText('    mov rax, ' + variable + #10); // load pointers value (addr)
        WriteText('    mov [rax], ' + value + #10); // write value into it
        emitWritePointer := 'rax';
end;

// who really needs the heap anyways?
procedure emitMalloc(); begin end;            // cm(size)
procedure emitFree(); begin end;              // fm(p)

// MATH -----------------------------------------------------------

// signed vs unsigned debacle
// signed due to presence of negative numbers

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
// needs another lookover

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

// PARSER =================================================================================================
// ========================================================
// Helpers ------------------------------------

function peekV(): String; begin peekV := tokenValue[position]; end;
function peekV2(): String; begin peekV2 := tokenValue[position+1]; end;
function peekV3(): String; begin peekV3 := tokenValue[position+2]; end;
function peek(): String; begin peek := tokenKind[position]; end;
function peek2(): String; begin peek2 := tokenKind[position+1]; end;
function peek3(): String; begin peek3 := tokenKind[position+2]; end;
function currentLine(): String; begin currentLine := intToStr(t_line[position]); end;
function computeOffset(offset: Integer): String; begin computeOffset := '[rbp-' + IntToStr(offset) + ']'; end;

function consume(): String;
begin
    consume := tokenValue[position];
    //WriteLn( 'CNSM - K ' + tokenKind[position] + ' V ' + tokenValue[position]);
    Inc(position);
end;



// signed vs unsigned debacle
// interactions with memeory need to be unsigned because they dont go negative

// slap a label on that bad boy
function varToMem(variable: String): String;
var
    foundIndex: Integer;
begin
    varToMem := '';
    foundIndex := matchIndex(variable, 'ARRAY');
    statusMessage('VAR_TO_MEM');
    if foundIndex = -1 then
    begin
        if matchName(variable, 'SYM') then
            varToMem := '[rbp-' + IntToStr(symOffset[matchIndex(variable, 'SYM')]) + ']';
    end
    else
    begin
        if aType[foundIndex] <> 'VAR' then
            Exit(variable)
        else
            varToMem := '[' + variable + ']';
    end;

    if varToMem = '' then
        hardFault('VAR_TO_MEM', variable);
end;

// also slap a label on theese bad boys
function arrayToMem(arrayName, aindex: String): String;
var
    i, intindex ,elementSize: Integer;
    arType: String;
begin
    arrayToMem := '';
    i := 0;
    statusMessage('ARRAY_TO_MEM');
    arType := matchType(arrayName, 'ARRAY');

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
                            if StrToInt(aIndex) > StrToInt(aSize[i]) then
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
        hardFault('ARRAY_TO_MEM', arrayName);
end;

// pay no mind to this here function
function recordToMem(recordName, field: String): String;
var
    offsets, size: String;
    index: integer;

begin
    // the kernel is going to be more sassy about me walking in with a trenchcoat pretending i am C than expected
    // I need to find out how i can convert on the fly from qword to those types that are used for dirent and
    // stat and such while making it invisible to the user.

    // going to have some sort of auto truncate and expanison based off of declared offsets. Gettings things out should ideally zero exmpand be the The One True Type but going in is going to be a silent truncation that I need to make people aware of.

    // Requirements: Arrays come in, fields, offsets and sizes all come in like "f1 f2 f3" "0 4 8" "4 4 8"
    // i need to split on that whitespace and associate each with their companions baed off how many spcaes
    // deep they are. They will then be referenced as offsets of their bss declaration.

    if RecordIdent(recordName, 'NAME') <> -1 then
    begin
        index := RecordIdent(recordName, 'NAME');
        offsets := recOffsets[index];
        // find offset with whilespace delimiter comparison and compare to fields
        size := recSize[index];

        // gotta think this ordering through and whether or not to loop over it (probably yes)
        // run var based off lookup on incoming field name that pulls field string, splits it
        // and assigns an integer based on which # in the field string it was.
        offsets := ExtractDelimited(1, offsets, ' ');
        size := ExtractDelimited(1, size, ' ');




        // after determining what belongs to who, within loop write instructions directly from here, not
        // shelled out to another emmiter.






        // PLACEHOLDER
        WriteText('    mov r10, ' + varToMem(IntToStr(index)) + #10);
        recordToMem := '   [' + recordname + ' + r10*' + size + ']';

    end
    else
        hardFault('RECORD_TO_MEM', recordName);

end;

function discriminateArrays(variable: String): Boolean;
procedure setFree(arrayname, arrayIndex, rightside, arrayType: String);
begin
    consume;
    variable := arrayToMem(arrayname, arrayIndex);
    rightside := evaluateExpression(False);
    emitAssignArray(variable, rightside, arrayType);
    discriminateArrays := True;
    Exit;
end;

var
    rightside, arrayName, arrayIndex, arrayType: String;
begin
    statusMessage('DISCRIMINATE ARRAYS');
    rightside := '';
    discriminateArrays := False;

    // Word Arrays
    if peek() = 'LBRAC' then
    begin
        arrayname := variable;
        consume; // [
        arrayIndex := consume;
        consume; // ]
        arrayType := 'WORD';
        setFree(arrayname, arrayIndex, rightside, arrayType);
    end;

      // Float Arrays
    if peek() = 'LBRACE' then
    begin
        arrayname := variable;
        consume; // [
        arrayIndex := consume;
        consume; // ]
        arrayType := 'FLOAT';
        setFree(arrayname, arrayIndex, rightside, arrayType);
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
        setFree(arrayname, arrayIndex, rightside, arrayType);
    end;
end;

// function calls
function call(fname: String; returnsFloat: Boolean): String;
begin
    statusMessage('CALL');
          if returnsFloat then
            begin
                WriteText('    call ' + fname + #10); call := 'xmm0';
            end
        else
            begin
                WriteText('    call ' + fname + #10); call := 'rax';
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
                hardFault('EMIT_MATH - FLOAT', op);
        end
    else
        begin
            if      op = 'PLUS'  then emitAdd('rax', second)
            else if op = 'MINUS' then emitSub('rax', second)
            else if op = 'STAR'  then emitMul('rax', second)
            else if op = 'SLASH' then emitDiv('rax', second)
            else
                hardFault('EMIT_MATH - FIXED', op);
        end;
end;

// calls that rely on asm in the compiler
function parseIntrinsic(name: String): String;
var
    a, b, c, d, e, f, num: String;
    isFloat: Boolean;
begin
    statusMessage('PARSE INTRINSIC');
    consume; // (
    if name = 'printf' then
    begin
        a := theOracle(isFloat);
        consume; // )
        functionPrintF(a);
        parseIntrinsic := '';
    end
    else if name = 'printw' then
    begin
        a := theOracle(isFloat);
        consume; // )
        functionPrintW(a);
        parseIntrinsic := '';
    end
    else if name = 'sys' then
    begin
        num := theOracle(isFloat); consume;
        a   := theOracle(isFloat); consume;
        b   := theOracle(isFloat); consume;
        c   := theOracle(isFloat); consume;
        d   := theOracle(isFloat); consume;
        e   := theOracle(isFloat); consume;
        f   := theOracle(isFloat); consume;
        parseIntrinsic := emitSyscall(num, a, b, c, d, e, f);
    end;
end;

// high tech, incredibly optimized cold folding
function foldCode(first: String; isFloat: boolean): String;
var
    result1: Double;
    result2: Integer;
    second, op: String;
begin
            op := peek(); // Operator
            consume;
            second := consume; // Operand
            statusMessage('FOLDING');

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

// who really are you Mr. Variable
function WhoGoesThere(intruder: String): String;
var
    isFloat: Boolean;
begin
    statusMessage('WHOGOESTHERE');
    isFloat := False;

    if isNumber(intruder) then // RAW NUM
        begin
        if Pos('.', intruder) > 0 then
            isFloat := True;
        end
    else
        if matchType(intruder, 'SYM') = 'FLOAT' then
            isFloat := True;

    if matchType(intruder, 'RETURN') = 'FLOAT' then
        isFloat := True;

    if isFloat then WhoGoesTHere := 'FLOAT' else WhoGoesTHere := 'QWORD';

end;

// MAIN PARSER MACHINERY ==========================================================================

function argumentParser(fname: String; returnsFloat: Boolean; argfindex: Integer): String;
var
    argname: String;
    seenFloats, seenInts, argCounter: Integer;
    isFloat: Boolean;
begin
            //WriteLn('ARGUMENT PARSER - I' + IntToStr(argfindex) + '- N' + argname); // DEBUG
            statusMessage('ARGPARSER');
            argcounter := 0;
            seenFloats := 0;
            seenInts := 0;

            repeat
                argname := theOracle(isFloat);

                if isFloat then
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
            argumentParser := call(fname, returnsFloat);
end;

function bitwiseEvaluator(first: String; isFloat: Boolean): String;
var
    second, op: String;
begin
    statusMessage('BITWISE');
    loadRAX(first);

    while ((peek() = 'DOLLAR') or (peek() = 'PIPE') or (peek() = 'NOR') or (peek() = 'NOY') or (peek() = 'SHL') or (peek() = 'SHR')) do
    begin
        op := peek();
        consume;
        second := theOracle(isFloat);

        if      op = 'DOLLAR' then emitAnd('rax', second)
        else if op = 'PIPE'   then emitOr('rax', second)
        else if op = 'XOR'    then emitXor('rax', second)
        else if op = 'NOT'    then emitNot('rax')
        else if op = 'SHL'    then emitShl('rax', second)
        else if op = 'SHR'    then emitShr('rax', second)
        else
            hardFault('BITWISE', op);
    end;
    bitwiseEvaluator := 'rax';
end;

// who's calling?
function parseCall(fname: String): String;
var
    returnsFloat: Boolean;
    argfindex: Integer;
begin
    statusMessage('PARSECALL');
    returnsFloat := False;
    if WhoGoesThere(fname) = 'FLOAT' then
        returnsFloat := True;
    argfindex := matchIndex(fname, 'PARAM');

    consume(); // (
    if peek() <> 'RPAR' then
        parseCall := argumentParser(fname, returnsFloat, argfindex)
    else
    begin
        consume(); // )
        parseCall := call(fname, returnsFloat);
    end;
end;

function evaluateExpression(isFloat: Boolean): String;
var
    first, second, op, return, math_ret: String;
begin
    first := '';

    statusMessage('EXPRESSION EVALUATOR');


    if (peek() = 'NUMBER') and (peek3() = 'NUMBER') then
            begin
                return := foldCode(first, isFloat);
                Exit(return);
            end;

    first := theOracle(isFloat);

    if ((peek() = 'DOLLAR') or (peek() = 'PIPE') or (peek() = 'NOR') or (peek() = 'NOY') or (peek() = 'SHL') or (peek() = 'SHR')) then
            Exit(bitwiseEvaluator(first, isFloat));

    // if next token isnt operator, return the first operand eg if var := 5 not var := 5 + b
    if not ((peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH')) then
                evaluateExpression := first
            else
                begin
                    statusMessage('EXPRESSION EVALUATOR - OPERATOR BRANCH');

                    if isFloat then
                        loadXMM0(first) // floats need Xtra Math Man
                    else
                        loadRAX(first);

                    // BEHOLD THE CHAINER OR OPERATORS, SOLVER OF EXPRESSIONS
                    while ((peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH')) do
                    begin
                        op := peek();
                        consume;
                        second := theOracle(isFloat);
                        math_ret := emitMath(op, second, isFloat);
            end;
        Exit(math_ret)
    end;
end;

// You name it, the oracle knows it.
// Has caused significant bugs because old DI/EE only method would only give strict instructions to the emitters.
// now theyre being talked too more freely and NASM is getting sassy. Overall I am very happy with this
// it makes bug chasing much easier and is also boosting my assembly knowledge having to hunt down the
// edge cases.
function theOracle(var isFloat: Boolean): String;
var
    float, str, ident, arrayName, index, ampaddr: String;
begin
    isFloat := False;
    statusMessage('YOU HAVE ENTERED THE ORACLE');
    case peek() of
        'NUMBER': begin theOracle := consume; isFloat := False ;end;
        'FLOAT': begin
                float := consume;
                float := copy(float, 1, Length(float) - 1);
                theOracle := '[' + emitFloatConstant(float) + ']';
                isFloat := True;
            end;
        'STRING': begin
                str := consume;
                isFloat := False;
                theOracle := emitStringConstant(str);
            end;
        'VESCAPE': begin
                consume;                          // [[
                theOracle := '[' + consume() + ']';
                consume;                          // ]
                consume;
                isFloat := False;
            end;
        'AMP': begin
                consume;
                ampaddr := VarToMem(consume);
                isFloat := False;
                Exit(emitAddressOf(ampaddr));
            end;
        'IDENTIFIER': begin
                if peek2() = 'CARET' then
                begin
                    ident := consume;
                    consume;
                    isFloat := False;
                    Exit(emitDereference(VarToMem(ident)))
                end
                else if (peek2() = 'LBRAC') or (peek2() = 'LBRACE') or (peek2() = 'BANG') then
                begin
                    isFloat := False;
                    if peek2() = 'LBRACE' then isFloat := True;
                    arrayName := consume;
                    if peek() = 'BANG' then consume;
                    consume;
                    index := consume;
                    consume;
                    theOracle := arrayToMem(arrayName, index)
                end
                else if peek2() = 'LPAR' then
                begin
                    ident := consume;
                    if (ident = 'sys') or (ident = 'printf') or (ident = 'printw') then
                    begin
                        theOracle := parseIntrinsic(ident); isFloat := False;
                    end
                    else
                    begin
                        theOracle := parseCall(ident);
                        if WhoGoesThere(ident) = 'FLOAT' then isFloat := True;
                    end;
                end
                else
                begin
                    ident := consume;
                    theOracle := varToMem(ident);
                    if matchType(ident, 'SYM') = 'FLOAT' then
                        isFloat := True;
                end;
            end;
        else
            hardFault('I CANT BELEIVE YOUVE DONE THIS - YOU HAVE DISPLEASED THE ORACLE', peek() + ' ' + peekV());
    end;
end;

// determine what to do with the left side of the expression. x :=
procedure discriminateIdentifier();
var
    variable, rightside, twoname, value, gvar, field: String;
    isDeclared, isReturn, isFloat, didArrays: boolean;
    ii, symIndex, argfindex: Integer;
    returnsFloat, isGlobal: Boolean;
begin
    ii := 0;
    symIndex := 0;
    value := '';
    variable := '';
    field := '';
    isDeclared := False;
    isReturn := False;
    isFloat := False;
    isGlobal := False;

    // globals are in the array arrays, i know i know
    if matchName(variable, 'ARRAY') then isGlobal := True;

    variable := consume(); // consume the a in a := 5

    if variable = 'r' then isReturn := True;

    didArrays := discriminateArrays(variable);
    if didArrays then Exit;

    if matchName(variable, 'SYM') then
        begin
            isDeclared := True;
            symIndex := matchIndex(variable, 'SYM');
        end;

    if matchType(variable, 'SYM') = 'FLOAT' then isFloat := True;

    if peek() = 'CARET' then // dereferenc sym on left side of assign, write through pointer
        begin
            consume; // :=
            value := consume;
            if isNumber(value) then
                emitWritePointer(variable, value)
            else
                begin
                    value := varToMem(value);
                    emitWritePointer(variable, value);
                end;
            Exit;
        end;

    if peek() = 'DOT' then // records
    begin
        consume; //.
        field := consume;
        recordToMem(variable, field)
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
                                    emitAssignFloat(variable, rightside);
                                end
                            else
                                begin
                                    rightside := evaluateExpression(isFloat);
                                    emitAssign(variable, rightside);
                                end;
                        statusMessage('ASSIGN - DECLARED');
                end
            else if isGlobal then
            begin
                gvar := VarToMem(variable);
                rightside := evaluateExpression(False);
                emitAssign(gvar, rightside);
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
                        doubleReturnCapacity();
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
                        statusMessage('ASSIGN - UNDECLARED');
                    end;
        end
        else
        begin
                if peek() = 'LPAR' then
                    begin

                        // off to the ASM calls
                        if (variable = 'sys') or (variable = 'printf') or (variable = 'printw') then
                        begin
                            statusMessage('DI - ASM');
                            parseIntrinsic(variable);
                        end
                        else
                            begin
                                statusMessage('DI - FUNCTION CALL');
                                consume(); // (
                                if peek() <> 'RPAR' then
                                    begin

                                        if WhoGoesThere(variable) = 'FLOAT' then
                                            returnsFloat := True;

                                        argfindex := matchIndex(variable, 'PARAM');
                                        argumentParser(variable, returnsFloat, argfindex);
                                    end
                                else
                                    begin
                                        consume; //)
                                        call(variable, returnsFloat);
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


// CONTROL FLOW =============================================================
// USE AT YOUR OWN RISK
// ASM IS *NOT* MY STRONG SUIT but i am learning slowly but surely

   {cfKind, cfTLabel, cfELabel, cfLVar: Array[0..64] of String;
    cfDepth: Integer;}

// these use the flags set in emitComapareAndJump
// the flags are ZeroF, SignD, OvrflwF, or CarryF and wiped by the next instruction so it has to be ASAP
// ASM flags are runtime, do I jump? Pascal insertions are compile time, WHEN do I jump?

// signed vs unsigned debacle
// keep signed in case something goes negative

procedure condJumpTable(condition, endLabel: String);
begin
    statusMessage('LOOP - JUMP TABLE');
    if condition = 'LESSEQUAL' then  // all the shit is backwards here
        WriteText('    jg ' + endlabel + #10)       // jump if greater (skip when i > limit)
    else if condition = 'LESS' then
        WriteText('    jge ' + endlabel + #10)      // jump if greater or equal
    else if condition = 'GREQUAL' then
        WriteText('    jl ' + endlabel + #10)       // jump if less
    else if condition = 'MORE' then
        WriteText('    jle ' + endlabel + #10)      // jump if less or equal
    else if condition = 'EQUAL' then
        WriteText('    jne ' + endlabel + #10)     // jump if not equal
    else if condition = 'NOTEQUAL' then
        WriteText('    je ' + endlabel + #10);

end;

procedure emitCompareAndJump(leftVal, rightVal, condition, skipLabel: String);
begin
    statusMessage('LOOP - COMPARE');
    WriteText('    mov rax, ' + leftVal + #10);
    WriteText('    push rax' + #10);    // psh that bad boy on the stack so its not clobbered
    WriteText('    mov rbx, ' + rightVal + #10);
    WriteText('    pop rax' + #10); // bring it back for the compare
    WriteText('    cmp rax, rbx' + #10);
    condJumpTable(condition, skipLabel);
end;

procedure loopWhile();
var
    loopvar, loopcond, looplimit, toplabel, endlabel: String;
begin
    statusMessage('LOOP - WHILE');
    consume; //consume LW
    consume; // consume LPAR
    loopvar := varToMem(consume); // handle variable variables
    loopcond := peek; // grab TYPE not the damn value
    consume; // now eat it
    looplimit := consume;
    consume; // RPAR
    toplabel := labelMaker('LW'); // prep labels
    endlabel := labelMaker('LW');
    emitLabel(toplabel); // it is I, the start of the loop

    WriteText('    mov rax, ' + loopvar + #10);
    WriteText('    cmp rax, ' + looplimit + #10); // same comparison as above, runtime decisions

    condJumpTable(loopCond, endLabel); // off to decide what operators are going to be placed

    cfKind[cfDepth] := 'WHILE';
    cfTLabel[cfDepth] := toplabel;
    cfELabel[cfDepth] := endlabel;
    Inc(cfDepth);
end;

procedure loopFor();
var
    loopvar, loopstart, looplimit, toplabel, endlabel: String;
begin
    statusMessage('LOOP - FOR');
    consume; //consume LF
    consume; // consume LPAR
    loopvar := varToMem(consume);
    consume; // :=
    loopstart := consume; // 0
    consume; // until
    looplimit := evaluateExpression(False); // throw the limit into the evaluator so its not locked to litterals
    consume; // RPAR
    WriteText('    mov rax, ' + loopstart + #10);
    WriteText('    mov ' + loopvar + ', rax' + #10);

    toplabel := labelMaker('LF');
    endlabel := labelMaker('LF');
    emitLabel(toplabel);

    WriteText('    mov rax, ' + loopvar + #10);
    WriteText('    cmp rax, ' + looplimit + #10);
    WriteText('    jge ' + endlabel + #10); // exit when loopvar > looplimit

    cfKind[cfDepth] := 'FOR';
    cfTLabel[cfDepth] := toplabel;
    cfELabel[cfDepth] := endlabel;
    cfLVar[cfDepth] := loopvar;
    Inc(cfDepth);
end;

function loopLocate(): Boolean;
var
    cvar, willToLive, arrname, countTok, endlabel, toplabel, nextlabel: String;
    elementSize, countVal, n: Integer;
    arrType: String;
begin
    statusMessage('LOOP - LOCATE');
    consume; // LOCATE
    consume; // (
    cvar := varToMem(consume);
    consume; // ,
    willToLive := consume();
    if not isNumber(willToLive) then
        willToLive := varToMem(willToLive);
    consume; // ,
    arrname := consume();
    consume; // [
    countTok := consume();
    consume; // ]
    consume; // )

    arrType := matchType(arrName, 'ARRAY');

    if arrType = 'BYTE' then elementSize := 1 else elementSize := 8;

    WriteText('    mov qword ' + cvar + ', -1' + #10);   // c := -1, assume not found

    if isNumber(countTok) and (StrToInt(countTok) < 10) then // if the number is below 10 its unrolled
        begin
            countVal := StrToInt(countTok);
            endlabel := labelMaker('LOC');
            for n := 0 to countVal - 1 do // DO loop, this is done at compile time
                begin
                    WriteText('    mov rax, [' + arrname + ' + ' + IntToStr(n * elementSize) + ']' + #10); // LD
                    WriteText('    cmp rax, ' + willToLive + #10);
                    nextlabel := labelMaker('LOC');
                    WriteText('    jne ' + nextlabel + #10); // if NOT = skip to next check
                    WriteText('    mov qword ' + cvar + ', ' + IntToStr(n) + #10); // if = store
                    WriteText('    jmp ' + endlabel + #10); // adios
                    emitLabel(nextlabel);
                end;
            emitLabel(endlabel);
        end
    else // if the number is > 10 it transitions into a for loop so your NAsM file isnt 100MB if using often
    begin // thoeretically worse performance but negligible
            WriteText('    mov r11, 0' + #10); // hop up into r11 staying away from the rax for less traffic
            toplabel := labelMaker('LOC');
            endlabel := labelMaker('LOC');
            emitLabel(toplabel);
            WriteText('    cmp r11, ' + countTok + #10); // compare counter
            WriteText('    jge ' + endlabel + #10); // exit if its the end
            WriteText('    mov rax, [' + arrname + ' + r11*' + IntToStr(elementSize) + ']' + #10); // ld elem
            WriteText('    cmp rax, ' + willToLive + #10); // compare with search. ^^ r11*8 mult counter by elmsize
            nextlabel := labelMaker('LOC');
            WriteText('    jne ' + nextlabel + #10); // if NOT = continue
            WriteText('    mov qword ' + cvar + ', r11' + #10); // if you find it load
            WriteText('    jmp ' + endlabel + #10); // exit if found
            emitLabel(nextlabel);
            WriteText('    inc r11' + #10); // icnrement counter and restart loop
            WriteText('    jmp ' + toplabel + #10);
            emitLabel(endlabel);
        end;

    loopLocate := True;
end;

procedure loopDo();
var
    loopvar, loopstart, looplimit: String;
    loopCounter, doDepth, n, bodyStart, bodyEnd: Integer;
begin
    statusMessage('LOOP - DO');
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

    repeat // BEHOLD, THE DESTORYER OF NESTS, FINDER OF CODE
            if tokenKind[loopCounter] = 'LBRACE' then
                begin
                    Inc(doDepth);
                end;
            if tokenKind[loopCounter] = 'RBRACE' then
                    Dec(doDepth);

            Inc(loopCounter);
        until doDepth = 0;

    frameOffset := frameOffset + 8; // your making another var, remeber always allocate memory
    symOffset[symCount] := frameOffset;
    symName[symCount] := loopvar;
    Inc(symCount);

    loopvar := varToMem(loopvar); // make memory label

    // the brace check above grabbed the offsets so this is preparing the bounds
    bodyStart := position + 1;
    bodyEnd := loopCounter - 1;

    // Compiler wisdom
    if StrToInt(looplimit) > 10000 then
        writeLn('DO LOOP > 10000 ITERATION - VAYA CON DIOS')
    else if StrToInt(looplimit) > 500 then
        writeLn('WHOA THERE PARTNER - YOUR SOURCE IS ABOUT TO BE BIGGER THAN FIREFOX WITH > 500 ITERATIONS OF A DO LOOP')
    else if StrToInt(looplimit) > 100 then
        writeLn('YOU HAVE FRUSTRATED THE COMPILER - YOU DARE EXCEED 100 ITERATIONS OF A DO LOOP?');

    // COMPILE TIME unrolled do loop
    for n := StrToInt(loopstart) to StrToInt(looplimit) - 1 do
        begin
            WriteText('    mov qword ' + computeOffset(symOffset[symCount-1]) + ', ' + IntToStr(n) + #10); //stre
            position := bodyStart; // pull the parser into the loop, trapped to forever do its bidding
            while position < bodyEnd do // RERERERE REEEWWWIIINNNNDDDDDD
                dispatch; // parse as if it was coming from the lexer
        end;

    position := bodyEnd + 1; // free at last
end;

procedure condWhen();
var
    condvar, condition, condlimit, endlabel: String;
begin
    statusMessage('CONDITIONAL - WHEN');
    consume; //consume W
    consume; // consume LPAR
    condvar := evaluateExpression(False);
    condition := peek; // grab TYPE not the damn value
    consume; // now eat it
    condlimit := evaluateExpression(False);
    consume; // RPAR

    endlabel := labelMaker('W'); // label of where to SKIP to

    // if the condition of the when is NOT true, it skips the body and jumps to the endlabel
    emitCompareAndJump(condvar, condlimit, condition, endlabel);

    cfKind[cfDepth] := 'WHEN';
    cfELabel[cfDepth] := endlabel;
    Inc(cfDepth);
end;

procedure condIf();
var
    condvar, condition, condlimit, endlabel, misslabel: String;
begin
    statusMessage('CONDITIONAL - IF');
    consume; //consume W
    consume; // consume LPAR
    condvar := evaluateExpression(False);
    condition := peek; // grab TYPE not the damn value
    consume; // now eat it
    condlimit := evaluateExpression(False);
    consume; // RPAR

    if not chainContinuing then // if its the end of the line, makes the end label to jump to
        begin

            endlabel := labelMaker('IF');
            cfELabel[cfDepth] := endlabel;
            cfKind[cfDepth] := 'IF';
            Inc(cfDepth);
        end;

    misslabel := labelMaker('IF'); // generates a stopover jump label because this is now assumed to be an elseif
    cfTLabel[cfDepth - 1] := misslabel;

    emitCompareAndJump(condvar, condlimit, condition, misslabel); // continue the party

    chainContinuing := False;
end;

procedure condElse();
begin
    consume;
    statusMessage('CONDITIONAL - ELSE');
    if not chainContinuing then // if there is no flag set stating an if was opened, you mustve just put an else
        begin
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - ALL ELSE NO IF HUH?');
            Halt(1);
        end;

    // say this was an else, stop the chain
    cfKind[cfDepth - 1] := 'E';
    chainContinuing := False;
end;

function constructFunction(): Boolean;
var
    i: Integer;
begin
    statusMessage('CONSTRUCT FUNCTION');
                constructFunction := (peek() = 'P');
                consume;
                currentFN := consume;
                emitFN(currentFN);
                frameOffset := 0;
                argCount := 0;
                symCount := 0;
                awaitingFunctionOpen := True;
                        for i := 0 to 1023 do // reset that there symbol table
                            begin
                                symName[i] := '';
                                symType[i] := '';
                                symOffset[i] := 0;
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
                                doubleParamCapacity(); // manage the dynamic arrays
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
                                doubleParamOffsetCapacity();
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
    arrayName, arraySize, variable, value: String;
begin
    arrayName := '';
    arraySize := '';
    variable := '';
    value := '';
    consume; // consume |V
        while peek() <> 'PIPE' do
            begin
                if peek2() = 'ASSIGN' then // globals
                            begin
                                variable := consume;
                                consume;
                                value := consume; // no floats
                                aName[aCount] := variable;
                                aType[aCount] := 'VAR';
                                WriteData(variable + ': dq ' + value + #10);
                                Inc(aCount);
                            end
                        else if peek2() = 'BANG' then // byte arrays
                            begin
                                doubleArrayCapacity();
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
                                doubleArrayCapacity();
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
                                doubleArrayCapacity();
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
                                WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - VARBLOCK - THAT IS SOMETHING.... BUT NOT A DECLARATION>> ' + peek() + ' ' + peekV());
                                Halt(1);
                            end;
            end;
    consume;
end;

// collection now implemented but record field creation and modificationa are not done at all
// do not use theese until this flag is cleared
procedure recordBlock();
var
    recordName, field, offset, range, size, offCounter, fieldList: String;
    counter: Integer;
begin
    recordName := '';
    offCounter := '';
    fieldList := '';
    field := '';
    offset := '';
    range := '';
    size := '';
    counter := 0;
    consume; // consume |V
    recordName := consume;
    while peek() <> 'PIPE' do
    begin
        if peek2() = 'IDENTIFIER' then
        begin
            field := consume;
            fieldList := field + ' ';
            offset := consume;
            offCounter := offset + ' ';
            consume; // :
            range := consume;
            counter := counter + StrToInt(range);
        end
        else
        begin
            WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - RECORDBLOCK - YOUVE SCRATCHED MY COLLECTION>> ' + peek() + ' ' + peekV());
            Halt(1);
        end;
    end;
    size := IntToStr(counter);
    recName[recCount] := recordName;
    recFields[recCount] := fieldList;
    recSize[recCount] := size;
    recOffsets[recCount] := offCounter;
    WriteBSS(recordName + ': resb ' + size + #10);
    consume;
end;

// PARSER -----------

procedure rightbrace();
begin
    consume;
        statusMessage('RBRACE');
            if cfDepth > 0 then // are we currently in a loop or conditional?
                begin
                    Dec(cfDepth); // drop a brace from the count
                    case cfKind[cfDepth] of
                        'FOR': begin
                            WriteText('    inc qword ' + cfLVar[cfDepth] + #10); // increment counter
                            WriteText('    jmp ' + cfTLabel[cfDepth] + #10); // jump to check
                            emitLabel(cfELabel[cfDepth]);
                        end;
                        'WHILE': begin
                            WriteText('    jmp ' + cfTLabel[cfDepth] + #10); // jump back to condition
                            emitLabel(cfELabel[cfDepth]);
                        end;
                        'WHEN': begin emitLabel(cfELabel[cfDepth]); end; // materialize skip label
                        'IF': begin
                            WriteText('    jmp ' + cfELabel[cfDepth] + #10);
                            emitLabel(cfTLabel[cfDepth]);   // elseif label
                            chainContinuing := True;
                            Inc(cfDepth); // it goes DEEPER
                        end;
                        'E': begin emitLabel(cfELabel[cfDepth]); end; // exit label
                    end;
                end
                else
                    emitFunctionTeardown(returnAddr, isProcedure);
end;

procedure dispatch();
var
    i, d, seenFloats, seenInts: Integer;
    asmgrab, atok, asmend: String;
begin
    statusMessage('DISPATCH');
    asmend := '';
    asmgrab := '';
    atok := '';
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
            'BREAK': begin
                consume;
                d := cfDepth - 1;
                while (d >= 0) and (cfKind[d] <> 'FOR') and (cfKind[d] <> 'WHILE') do
                    Dec(d);
                if d < 0 then
                    hardFault('BREAK', 'YOU DARE BREAK OUTSIDE OF CONTROL FLOW? JUST HIT CTRL-C ITS EASIER')
                else
                    WriteText('    jmp ' + cfELabel[d] + #10);
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
            'RBRACE': begin rightbrace(); end;
            'IDENTIFIER': begin discriminateIdentifier(); end;
            'ASSIGN': begin  consume; end;
            {'AMP': begin
                consume;
            end;
            'CARET': begin
                consume;
            end;}
            'W': begin condWhen(); end;
            'IF': begin condIf(); end;
            'E': begin condElse(); end;
            'LF': begin loopFor(); end;
            'LW': begin loopWhile(); end;
            'LOCATE': begin loopLocate(); end;
            'DO': begin loopDo(); end;
            'VARBLOCK': begin varBlock(); end;
            'RECORDBLOCK': begin
                recordBlock();
            end;
            'ASMBLOCK': begin
                consume; // consume |A
                while peek() <> 'PIPE' Do
                    begin
                        asmgrab := '';
                        while peek() <> 'TILDE' do
                            begin
                                atok := consume;
                                atok := atok + ' ';
                                asmgrab := asmgrab + atok + '';
                            end;
                        asmend := asmend + '    ' + asmgrab + #10;
                        consume; // ~
                    end;
                WriteText(asmend);
                consume; // |
            end;

            else
            begin
                WriteLn(IntToStr(t_line[position]) + ' - ' + 'I CANT BELIEVE YOUVE DONE THIS - PARSER - YOU CORRUPTED MY PARSER WITH YOUR FILTH>> ' + peek() + ' ' + peekV());
                Halt(1);
            end;

        end;
end;

procedure parser();
begin
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
    i, linecount: LongInt;
    word: String;
    isKeyword, isFloat, prevIsValue: Boolean;
    isMultiple: Boolean;

    //
    procedure assignSingleChar(Tvalue: String; Ttype: String);
    begin
        doubleTokenCapacity();
        tokenKind[tokenCount] := Ttype;
        tokenValue[tokenCount] := Tvalue;
        t_line[tokenCount] := linecount;
        Inc(tokenCount);
    end;

    procedure assignDoubleChar(Tvalue: String; Ttype: String);
    begin
        doubleTokenCapacity();
        tokenKind[tokenCount] := Ttype;
        tokenValue[tokenCount] := Tvalue;
        t_line[tokenCount] := linecount;
        isMultiple := True;
        Inc(tokenCount);
        Inc(i);
    end;

    procedure assignTripleChar(Tvalue: String; Ttype: String);
    begin
        doubleTokenCapacity();
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

    i := 0; // POSITION TRACKER
    repeat
        isMultiple := False;

        if buf[i] = #10 then // NEWLINE
            Inc(linecount);

        // TRIPLE CHARACHTER TOKENS
        case buf[i] + buf[i+1] + buf[i+2] of
            'nor': assignTripleChar('nor', 'NOR');
            'xor': assignTripleChar('xor', 'XOR');
            'not': assignTripleChar('not', 'NOT');
        end;
        // DOUBLE CHARACHTER TOKENS
        case buf[i] + buf[i+1] of
            ':=': assignDoubleChar(':=', 'ASSIGN');
            '|V': assignDoubleChar('|V', 'VARBLOCK');
            '|R': assignDoubleChar('|S', 'RECORDBLOCK');
            '|D': assignDoubleChar('|D', 'DIRECTIVE');
            '|A': assignDoubleChar('|A', 'ASMBLOCK');
            '>=': assignDoubleChar('>=', 'GREQUAL');
            '<=': assignDoubleChar('<=', 'LESSEQUAL');
            '++': assignDoubleChar('++', 'VADD');
            '**': assignDoubleChar('**', 'VMUL');
            '>>': assignDoubleChar('>>', 'SHR');
            '<<': assignDoubleChar('<<', 'SHL');
            '[[': assignDoubleChar('[[', 'VESCAPE');
            '<>': assignDoubleChar('<>', 'NOTEQUAL');
        end;

        prevIsValue := (tokenCount > 0) and
            ( (tokenKind[tokenCount-1] = 'NUMBER')     or
              (tokenKind[tokenCount-1] = 'FLOAT')      or
              (tokenKind[tokenCount-1] = 'IDENTIFIER') or
              (tokenKind[tokenCount-1] = 'RPAR')       or
              (tokenKind[tokenCount-1] = 'RBRAC')      or
              (tokenKind[tokenCount-1] = 'STRING') );

        if (not isMultiple) and (buf[i] = '-') and (buf[i+1] in ['0'..'9']) and (not prevIsValue) then
            begin
                word := '-';
                Inc(i); // step past the '-', land on the first digit
                isFloat := False;
                while buf[i] in ['0'..'9', '.', 'f'] do
                    begin
                        word := word + buf[i];
                        Inc(i);
                    end;

                if (Pos('.', word) > 0) or (Pos('f', word) > 0) then
                    isFloat := True;

                if isFloat then
                    assignSingleChar(word, 'FLOAT')
                else
                    assignSingleChar(word, 'NUMBER');

                Dec(i); // outer Inc(i) below will land correctly
                isMultiple := True; // suppress the old single-char '-' case
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
                    '$': assignSingleChar('$', 'DOLLAR');
                    '!': assignSingleChar('!', 'BANG');
                    '~': assignSingleChar('~', 'TILDE');
                    '.': assignSingleChar('.', 'DOT');

                    ';': begin
                        while (i < bytes) and (buf[i] <> #10) do
                            Inc(i);
                        if buf[i] = #10 then Inc(linecount);
            end
        else
                if buf[i] in ['a'..'z', 'A'..'Z', '_'] then // Handle letters
                    begin
                    word := '';
                    while buf[i] in ['a'..'z', 'A'..'Z', '_', '0'..'9'] do
                        begin
                            word := word + buf[i];
                            Inc(i);
                        end;

                    if word = 'nil' then
                        assignSingleChar('0','NUMBER')
                    else if word = 'NEXTFILE' then
                        begin
                            linecount := 0;   // see note below on why 0, not 1
                            Dec(i);
                        end
                    else
                        begin
                            isKeyword := keywordCheck(word);
                            if isKeyword then
                                begin
                                doubleTokenCapacity();
                                assignSingleChar(UpperCase(word), UpperCase(word))
                                end
                            else
                                assignSingleChar(word,'IDENTIFIER');
                            Dec(i);
                        end;
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
                                        word := word + buf[i];
                                end;
                            end
                            else
                                word := word + buf[i];
                            Inc(i);
                        end;

                        if i >= bytes then
                            begin
                                WriteLn('I CANT BELIEVE YOUVE DONE THIS - FORGOT A CLOSING QUOTE AND NOW MY LEXER IS SPEAKING IN TOUNGES ' + IntToStr(linecount));
                                Halt(1);
                            end;
                        // buf[i] is now closing quote
                        assignSingleChar(word,'STRING');
                    end;
            end;
        end;
        Inc(i); // Increment position in buffer
    until i >= bytes; // Runs until EOF

    i := 0;
    if Debug then begin
    for i := 0 to tokenCount - 1 do
        WriteLn(IntToStr(i) + ': ' + tokenKind[i] + '  ' + tokenValue[i]);
    end;
end;

// INIT / MAINTENANCE ============================================
// SUSPICIOUS TECHNOLOGY
// first time using dynamic arrays to this is relatively unproven

procedure doubleTokenCapacity();
begin
    if tokenCount >= Length(tokenKind) then
    begin
        SetLength(tokenKind, Length(tokenKind) * 2);
        SetLength(tokenValue, Length(tokenValue) * 2);
        SetLength(t_line, Length(t_line) * 2);
    end;
end;

procedure doubleArrayCapacity();
begin
    if aCount >= Length(aName) then
    begin
        SetLength(aName, Length(aName) * 2);
        SetLength(aType, Length(aType) * 2);
        SetLength(aSize, Length(aSize) * 2);
    end;
end;

procedure doubleRecordCapacity();
begin
    if recCount >= Length(recName) then
    begin
        SetLength(recName, Length(aName) * 2);
        SetLength(recOffsets, Length(aType) * 2);
        SetLength(recSize, Length(aSize) * 2);
        SetLength(recFields, Length(aSize) * 2);
    end;
end;

procedure doubleReturnCapacity();
begin
    if return_FCount >= Length(return_FName) then
    begin
        SetLength(return_FName, Length(return_FName) * 2);
        SetLength(return_FType, Length(return_FType) * 2);
    end;
end;

procedure doubleParamCapacity();
begin
    if param_FCount >= Length(param_FName) then
    begin
        SetLength(param_FName, Length(param_FName) * 2);
        SetLength(param_FIndex, Length(param_FIndex) * 2);
        SetLength(param_FType, Length(param_FType) * 2);
    end;
end;

procedure doubleParamOffsetCapacity();
begin
    if argCount >= Length(paramOffset) then
        SetLength(paramOffset, Length(paramOffset) * 2);
end;

procedure arrayInit();
var
    i: Integer;
begin
    frameOffset := 0;

    for i := 0 to 1023 do
    begin
        symName[i] := '';
        symType[i] := '';
        symOffset[i] := 0;
    end;

    SetLength(aName, INITIAL_ARRAY_CAP);
    SetLength(aType, INITIAL_ARRAY_CAP);
    SetLength(aSize, INITIAL_ARRAY_CAP);
    SetLength(recName, INITIAL_RECORD_CAP);
    SetLength(recOffsets, INITIAL_RECORD_CAP);
    SetLength(recSize, INITIAL_RECORD_CAP);
    SetLength(recFields, INITIAL_RECORD_CAP);
    SetLength(tokenKind, INITIAL_TOKEN_CAP);
    SetLength(tokenValue, INITIAL_TOKEN_CAP);
    SetLength(t_line, INITIAL_TOKEN_CAP);
    SetLength(return_FName, INITIAL_FUNC_CAP);
    SetLength(return_FType, INITIAL_FUNC_CAP);
    SetLength(param_FName, INITIAL_FUNC_CAP);
    SetLength(param_FIndex, INITIAL_FUNC_CAP);
    SetLength(param_FType, INITIAL_FUNC_CAP);
    SetLength(paramOffset, INITIAL_FUNC_CAP);

    for i := 0 to 64 do
    begin
        cfKind[i] := '';
        cfTLabel[i] := '';
        cfELabel[i] := '';
        cfLVar[i] := '';
    end;

    deleteFile('intermediate.asm');
    deleteFile('text.tmp');
    deleteFile('data.tmp');
    deleteFile('bss.tmp');

    param_FCount := 0;
    return_FCount := 0;
    awaitingFunctionOpen := False;
    paramPending := False;
    symCount := 0;
    cfDepth := 0;
    aCount := 0;
    argCount := 0;
    labelCounter := 0;
    position := 0;
    tokenCount := 0;
    currentFN := '';
    returnAddr := '';
    isProcedure := False;
    chainContinuing := False;

end;

procedure sendToNASM(outputName: String);
var
    cmd: String;
    result: Integer;
begin
    WriteLn('FLY FREE LITTLE BIRD');
    cmd := 'nasm -f elf64 intermediate.asm -o ' + outputName + '.o';
    result := fpSystem(cmd);
    if result <> 0 then
        begin
            WriteLn('YOU HAVE FRUSTRATED THE COMPILER - NASM FAILED - DONT BLAME ME, YOU WROTE IT');
            Halt(1);
        end;

    cmd := 'ld ' + outputName + '.o -o ' + outputName;
    result := fpSystem(cmd);
    if result <> 0 then
        begin
            WriteLn('I CANT BELIEVE YOUVE DONE THIS - LINK FAILED');
            Halt(1);
        end
    else
        WriteLn('ASSEMBLED AND LINKED' + #10);
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
        writeLn('DUTIFULLY PARSING');
        parser;
        closeIntermediateFile;
        writeASM;
        Optimize;
        sendToNASM(output_filename);

        deleteFile(output_filename + '.o');
    end
else
    begin
    WriteLn(#10 + 'No File Loaded' + #10);
    end;
end.

