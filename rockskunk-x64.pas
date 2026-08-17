program rockskunk_x64;
uses
    BaseUnix, SysUtils, Unix;

const
    acceptedKeywords: array[0..13] of String = // MAKE SURE TO UPDATE KEYWORD CHECK WHEN ADDING
    ('ADD', 'V', 'S',
     'F', 'LF', 'LW', 'W', 'I', 'E',
     'OR', 'AND', 'NOR', 'XOR', 'CALL');
var
    buf, databuf, textbuf: Array[0..65535] of Char;
    symName, symType: array[0..255] of String;
    symOffset: array[0..255] of Integer;
    t_type, t_val: Array[0..4096] of String;


    // for capturing return types so assingment to function return knows whats up
    return_FName: array[0..255] of String; 
    return_FType: array[0..255] of String;
    return_FCount: Integer;

    stack: Array [0..255] of String;
    sp: Integer;

    braceEmitted: Boolean;
    bytes: CInt;
    currentFN: String;
    fd, fd2, fd3, fd4: CInt;
    filename, returnAddr: String;
    paramPending: Boolean; paramOffset: Integer;
    frameOffset, labelCounter, position, symCount, t_count: Integer;

{
    Ripped lexer and scaffolding from a Pascal -> C Transpiler for an old language I had
    Undergoing massive restructuring to output rockskunk -> NASM
}

// HELPERS =================================================
// ========================================================

procedure push(value: String); 
begin 
    stack[sp] := value;
    Inc(sp);
end;

function pop(): String;
begin 
    Dec(sp);
    pop := stack[sp];
end;

procedure writeOut(s: String); begin fpWrite(fd2, s[1], Length(s)); end;
procedure writeText(s: String); begin fpWrite(fd3, s[1], Length(s)); end;
procedure writeData(s: String); begin fpWrite(fd4, s[1], Length(s)); end;

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
    i: Integer;
begin
    isNumber := True;
    for i := 1 to Length(token) do
        if not (token[i] in ['0'..'9', '.']) then
            isNumber := False;
end;

procedure openFile; // Open rockskunk sourcefile
begin
    FillChar(buf, SizeOf(buf), 0);
    fd := fpOpen(filename,O_RdOnly);
    bytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);
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
    WriteOut('section .data' + #10);
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

procedure closeIntermediateFile;
begin  
    fpClose(fd3);
    fpClose(fd4);
end;

// CODE GENERATION ===========================================
// ========================================================

// HELPERS ----------------------------------------------------------

procedure loadRAX(addr: String);
begin
    WriteText('    mov rax, ' + addr + #10);
end;

procedure loadRBX(addr: String);
begin
    WriteText('    mov rbx, ' + addr + #10);
end;

procedure loadXMM0(addr: String);
begin
    WriteText('    movsd xmm0, ' + addr + #10);
end;

// BLOCKS -----------------------------------------------------------
procedure emitGlobalBlock(); begin end;   // {V ...}
procedure emitStaticBlock(); begin end;   // {S ...}
procedure emitRecordBlock(); begin end;   // {R name ...}
procedure emitDirectiveBlock(); begin end; // {D ...}
procedure emitFileInclude(); begin end;   // ADD("file.rsk")

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

procedure emitFunctionTeardown(result : String);
begin 
    WriteText('    mov rax, ' + result + #10);
    WriteText('    add rsp, 128' + #10);
    WriteText('    pop rbp' + #10);
    WriteText('    ret' + #10 + #10);
end;

procedure emitReturn(); begin end;

// CONTROL FLOW -----------------------------------------------------------
procedure emitIF(); begin end;
procedure emitELSE(); begin end;
procedure emitWHEN(); begin end;
procedure emitFORLoop(); begin end;   // LF
procedure emitWHILELoop(); begin end; // LW
procedure emitLabel(); begin end;

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

procedure emitPairAssign(); begin end;
procedure emitCompoundAssign(); begin end; // :+=

function emitFloatConstant(float: String): String;
begin
        WriteData('   float_' + IntToStr(labelCounter) + ': dq ' + float + #10);
        emitFloatConstant := 'float_' + IntToStr(labelCounter);
        Inc(labelCounter);
end;

// ARRAYS / MEMORY -----------------------------------------------------------
procedure emitArrayAssignWord(); begin end;   // array[i]
procedure emitArrayAssignFloat(); begin end;  // array{i}
procedure emitArrayAssignString(); begin end; // array(i)
procedure emitArrayReadWord(); begin end;
procedure emitArrayReadFloat(); begin end;
procedure emitArrayReadString(); begin end;
procedure emitRecordFieldAccess(); begin end; // rec.field
procedure emitAddressOf(); begin end;         // &a
procedure emitMalloc(); begin end;            // cm(size)
procedure emitFree(); begin end;              // fm(p)

// MATH -----------------------------------------------------------
procedure emitAdd(dst, src: String); begin WriteText('    add ' + dst + ', ' + src + #10); end;
procedure emitSub(dst, src: String); begin WriteText('    sub ' + dst + ', ' + src + #10); end;
procedure emitMul(dst, src: String); begin WriteText('    imul ' + dst + ', ' + src + #10); end;

procedure emitDiv(dividend, divisor: String);
begin
    begin
        // Divide by zero and see what happens lol
        WriteText('    mov rax, ' + dividend + #10);
        WriteText('    cqo' + #10);
        WriteText('    idiv qword ' + divisor + #10);
    end;
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

// VECTOR INTRINSICS -----------------------------------------------------------
procedure emitVSin(); begin end;
procedure emitVCos(); begin end;
procedure emitVAbs(); begin end;
procedure emitVSqrt(); begin end;
procedure emitVMin(); begin end;
procedure emitVMax(); begin end;
procedure emitVFloor(); begin end;
procedure emitVCeil(); begin end;

// STREAMLINING FUNCTIONS -----------------------------------------------------------
procedure emitLint(); begin end;  // linear interpolation
procedure emitBrot(); begin end;  // bitwise rotate

// CONDITIONALS -----------------------------------------------------------
procedure emitCmpLess(); begin end;
procedure emitCmpGreater(); begin end;
procedure emitCmpLessEqual(); begin end;
procedure emitCmpGreaterEqual(); begin end;
procedure emitBitAnd(); begin end;
procedure emitBitOr(); begin end;
procedure emitBitNor(); begin end;
procedure emitBitXor(); begin end;
procedure emitLogicalAnd(); begin end;
procedure emitLogicalOr(); begin end;

// SYSTEM ----------------------------------

procedure emitSyscall(); begin end; // sys(a,b,c)

// PARSER =============================================================
// ========================================================

// Used to check type (identifier) and value of words for decision making
function peekV(): String; // Look at the next token non-destructively
begin
    peekV := t_val[position]; 
end;

function peekV2(): String; // Look at the next token non-destructively
begin
    peekV2 := t_val[position+1]; 
end;

function peekV3(): String; // Look at the next token non-destructively
begin
    peekV3 := t_val[position+2]; 
end;

function peek(): String; // Look at the next token non-destructively
begin
    peek := t_type[position]; 
end;

function peek2(): String; // Look at the next token non-destructively
begin
    peek2 := t_type[position+1]; 
end;

function peek3(): String; // Look at the next token non-destructively
begin
    peek3 := t_type[position+2]; 
end;


function consume(): String; // Eat the next token and then remove it
begin
    consume := t_val[position]; // pull value (actual content of token)
    Inc(position);  // Increment counter to drop the token
end;

function justMakeItAFuckingFloat(misformattedBastard: String): String;
var
    isFloat: Boolean;
begin
    isFloat := False;

    if (Pos('.', misformattedBastard) > 0) or (Pos('f', misformattedBastard) > 0) then
                        isFloat := True;

    if not isFloat then
        Exit(misformattedBastard)
    else
        begin
            if misformattedBastard[Length(misformattedBastard)] = 'f' then misformattedBastard := copy(misformattedBastard, 1, Length(misformattedBastard) - 1); // strip f from float
            justMakeItAFuckingFloat := '[' + emitFloatConstant(misformattedBastard) + ']';
        end;
end;

// symOffset, symName, symCount

function evaluateExpression(isFloat: Boolean): String;
var
    first, second, op, argname, fname: String;
    returnsFloat: Boolean;
    result1: Double;
    i, ii, result2: Integer;
begin
    i := 0;
    ii := 0;
    returnsFloat := False;

    if (peek() = 'IDENTIFIER') and (peek2() = 'LPAR') then 
    begin
        fname := consume(); // function name

        for ii := 0 to return_FCount - 1 do
            begin
                if fname = return_FName[ii] then
                    returnsFloat := True;
            end;
                    
        consume(); // (
        if peek() <> 'RPAR' then
            begin
                argname := consume(); // single arg
                if not isNumber(argname) then
                    for i := 0 to symCount - 1 do
                        if symName[i] = argname then
                            argname := '[rbp-' + IntToStr(symOffset[i]) + ']';
                WriteText('    mov rdi, ' + argname + #10);
            end;
        consume(); // )
        if returnsFloat then
            begin
                WriteText('    call ' + fname + #10);
                first := 'xmm0';
                evaluateExpression := 'xmm0';
            end
        else
            begin
                WriteText('    call ' + fname + #10);
                first := 'rax';
                evaluateExpression := 'rax';
            end;
    end
    else
        begin

    first := consume; // first operand (the a in a + b)

    if not isNumber(first) then // look up addr if identifier
        begin
            for i := 0 to symCount - 1 do
                begin
                if symName[i] = first then
                    first := '[rbp-' + IntToStr(symOffset[i]) + ']';
                end;
        end;

    first := justMakeItAFuckingFloat(first);

    if isNumber(first) and (peek2() = 'NUMBER') then // fold the code if 5 + 5, 5 * 5
            begin
            op := peek(); // Operator
            consume;
            second := consume; // Operand

            if isFloat then
                begin
                if op = 'PLUS' then
                    result1 := StrToFloat(first) + StrToFloat(second)
                else if op = 'MINUS' then
                    result1 := StrToFloat(first) - StrToFloat(second)
                else if op = 'STAR' then
                    result1 := StrToFloat(first) * StrToFloat(second)
                else if op = 'SLASH' then
                    result1 := StrToFloat(first) / StrToFloat(second);
                WriteLn('OPTIMIZATION - FLT ARITHMATIC');
                Exit(FloatToStr(result1));
                end 
            else
                begin
                if op = 'PLUS' then
                    result2 := StrToInt(first) + StrToInt(second)
                else if op = 'MINUS' then
                    result2 := StrToInt(first) - StrToInt(second)
                else if op = 'STAR' then
                    result2 := StrToInt(first) * StrToInt(second)
                else if op = 'SLASH' then
                    result2 := StrToInt(first) div StrToInt(second);
                WriteLn('OPTIMIZATION - FPT ARITHMATIC');
                Exit(IntToStr(result2));
                end;
    end;

    // if next token isnt operator return the first operand eg if var := 5 not var := 5 + b
    if not ((peek() = 'PLUS') or (peek() = 'MINUS') or (peek() = 'STAR') or (peek() = 'SLASH')) then
        begin
           evaluateExpression := first;
           WriteLn('EEVAL - NOT OP BRANCH');
        end
    else
        begin
            WriteLn('EEVAL - OP BRANCH');

            if isFloat then
                loadXMM0(first) // floats need Xtra Math Man
            else
                loadRAX(first); 

            op := peek(); // Operator
            consume;
            second := consume(); // Second

            second := justMakeItAFuckingFloat(second);

            i := 0;
            if not isNumber(second) then
            begin
                for i := 0 to symCount - 1 do
                    begin
                    if symName[i] = second then
                        second := '[rbp-' + IntToStr(symOffset[i]) + ']';
                    end;
            end;

            // ASM emission for math
            if op = 'PLUS' then
                begin    
                    if isFloat then
                        begin
                          emitAddFloat('xmm0', second);
                          evaluateExpression := 'xmm0';  
                        end
                    else
                        begin        
                            emitAdd('rax', second);
                            evaluateExpression := 'rax';
                        end
                end
            else if op = 'MINUS' then
                begin    
                    if isFloat then
                        begin
                          emitSubFloat('xmm0', second);
                          evaluateExpression := 'xmm0';  
                        end
                    else
                        begin        
                            emitSub('rax', second);
                            evaluateExpression := 'rax';
                        end
                end
            else if op = 'STAR' then
                begin    
                    if isFloat then
                        begin
                          emitMulFloat('xmm0', second);
                          evaluateExpression := 'xmm0';  
                        end
                    else
                        begin        
                            emitMul('rax', second);
                            evaluateExpression := 'rax';
                        end
                end
            else if op = 'SLASH' then
                begin    
                    if isFloat then
                        begin
                          emitDivFloat('xmm0', second);
                          evaluateExpression := 'xmm0';  
                        end
                    else
                        begin        
                            emitDiv('rax', second);
                            evaluateExpression := 'rax';
                        end
                end
    end;    end; 
end;

procedure discriminateIdentifier();
var
    variable, rightside, twoname: String;
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

    WriteLn('discrim start: variable=' + variable + ' position=' + IntToStr(position)); // DEBUG

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
                    variable := '[rbp-' + IntToStr(symOffset[symIndex]) + ']';  // [rbp-8] etc
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
                        variable := '[rbp-' + IntToStr(symOffset[symCount]) + ']';  

                    if isReturn then
                        begin
                        return_FName[return_FCount] := currentFN;
                        return_FType[return_FCount] := symType[symCount];
                        returnAddr := '[rbp-' + IntToStr(symOffset[symCount]) + ']';
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
            begin
                 WriteText('call ' + variable + #10);
            end;
end;

procedure parser();
var
    i: Integer;
begin
    i := 0;
    position := 0;
    repeat
        case peek() of
            'F': begin WriteLn('PARSER - F');
                consume;
                currentFN := consume;
                emitFN(currentFN);
                frameOffset := 0;
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
                        if peek() = 'IDENTIFIER' then
                            begin
                                frameOffset := frameOffset + 8;
                                symOffset[symCount] := frameOffset;
                                symName[symCount] := consume(); // grab param name
                                symType[symCount] := 'NUMBER'; // int param for now
                                inc(symCount);
                                paramPending := True;
                                paramOffset := frameOffset;
                            end;
                        consume; // )
                    end;
            end;
            'LPAR': begin WriteLn('PARSER - (');
                consume; // PLACEHOLDER
            end;
            'RPAR': begin WriteLn('PARSER - )');
                consume; // PLACEHOLDER
            end;
            'LBRACE': begin WriteLn('PARSER - {');
                consume;
                emitFunctionSetup();
                if paramPending then
                    begin
                        WriteText('    mov [rbp-' + IntToStr(paramOffset) + '], rdi' + #10);
                        paramPending := False;
                    end;
            end;
            'RBRACE': begin WriteLn('PARSER - }');
                consume;
                emitFunctionTeardown(returnAddr);
            end;
            'IDENTIFIER': begin WriteLn('PARSER - IDENT');
                discriminateIdentifier();
            end;
            'ASSIGN': begin WriteLn('PARSER - ASSIGN');
                consume;
            end;
            'TERMINATOR': begin WriteLn('PARSER - TERMINATOR');
                consume;
            end;
            'V': begin WriteLn('PARSER - GLOBAL VARIABLES');
                consume;
            end;
            'S': begin WriteLn('PARSER - STATIC');
                consume;
            end;
            'W': begin WriteLn('PARSER - WHEN');
                consume;
            end;
            'I': begin WriteLn('PARSER - IF');
                consume;
            end;
            'E': begin WriteLn('PARSER - ELSE');
                consume;
            end;
            'LF': begin WriteLn('PARSER - LOOP/FOR');
                consume;
            end;
            'LW': begin WriteLn('PARSER - LOOP/WHILE');
                consume;
            end;
            'VARBLOCK': begin WriteLn('PARSER - GLOBAL VAR');
                consume; // consume '
            end;
            'STATICBLOCK': begin WriteLn('PARSER - STATIC');
                consume; // consume '
            end;
            'RECORDBLOCK': begin WriteLn('PARSER - RECORD');
                consume; // consume '
            end;
        
        end;
    until position >= t_count;

    // placed at bottom for file
    WriteText('global _start'+ #10);  // entry point so linker can do linker things
    WriteText('_start:'+ #10);
    WriteText('  call main'+ #10);
    WriteText('  mov rdi, rax'+ #10);
    WriteText('  mov rax, 60'+ #10);
    WriteText('  syscall'+ #10);

end;

// LEXER =============================================================
// ========================================================
//Tokenizes input into a pair, ex = is type (EQUAL) and value (=). 

procedure lexer();
var
    i, linecount: Integer;
    word: String;
    isKeyword, isFloat: Boolean;
    isMultiple: Boolean;
begin
    linecount := 0;
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
            ':=': begin WriteLn('ASSIGN');
                t_type[t_count] := 'ASSIGN';
                t_val[t_count] := ':=';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '|V': begin WriteLn('VARBLOCK');
                t_type[t_count] := 'VARBLOCK';
                t_val[t_count] := '|V';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '|S': begin WriteLn('STATICBLOCK');
                t_type[t_count] := 'STATICBLOCK';
                t_val[t_count] := '|S';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '|D': begin WriteLn('DIRECTIVE');
                t_type[t_count] := 'DIRECTIVE';
                t_val[t_count] := '|D';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '|R': begin WriteLn('RECORDBLOCK');
                t_type[t_count] := 'RECORDBLOCK';
                t_val[t_count] := '|R';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '>=': begin WriteLn('GREQUAL');
                t_type[t_count] := 'GRQEUAL';
                t_val[t_count] := '>=';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '<=': begin WriteLn('LESSEQUAL');
                t_type[t_count] := 'LESSQEUAL';
                t_val[t_count] := '<=';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '++': begin WriteLn('VADD');
                t_type[t_count] := 'VADD';
                t_val[t_count] := '++';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
            '**': begin WriteLn('VMUL');
                t_type[t_count] := 'VMUL';
                t_val[t_count] := '**';
                isMultiple := True;
                Inc(t_count);
                Inc(i);
            end;
        end;

        // SINGLE CHARACHTER TOKENS 
        if not isMultiple then 
        begin       
            case buf[i] of 
                '=': begin WriteLn('EQUAL');
                    t_type[t_count] := 'EQUAL';
                    t_val[t_count] := '=';
                    Inc(t_count);
                end;
                '+': begin WriteLn('PLUS');
                    t_type[t_count] := 'PLUS';
                    t_val[t_count] := '+';
                    Inc(t_count);
                end;
                '-': begin WriteLn('MINUS');
                    t_type[t_count] := 'MINUS';
                    t_val[t_count] := '-';
                    Inc(t_count);
                end;
                '*': begin WriteLn('STAR');
                    t_type[t_count] := 'STAR';
                    t_val[t_count] := '*';
                    Inc(t_count);
                end;
                '/': begin WriteLn('SLASH');
                    t_type[t_count] := 'SLASH';
                    t_val[t_count] := '/';
                    Inc(t_count);
                end;
                '{': begin WriteLn('LBRACE');
                    t_type[t_count] := 'LBRACE';
                    t_val[t_count] := '{';
                    Inc(t_count);
                end;
                '}': begin WriteLn('RBRACE');
                    t_type[t_count] := 'RBRACE';
                    t_val[t_count] := '}';
                    Inc(t_count);
                end;
                '(': begin WriteLn('LPAR');
                    t_type[t_count] := 'LPAR';
                    t_val[t_count] := '(';
                    Inc(t_count);
                end;
                ')': begin WriteLn('RPAR');
                    t_type[t_count] := 'RPAR';
                    t_val[t_count] := ')';
                    Inc(t_count);
                end;
                '[': begin WriteLn('LBRAC');
                    t_type[t_count] := 'LBRAC';
                    t_val[t_count] := '[';
                    Inc(t_count);
                end;
                ']': begin WriteLn('RBRAC');
                    t_type[t_count] := 'RBRAC';
                    t_val[t_count] := ']';
                    Inc(t_count);
                end;
                #39: begin WriteLn('TERMINATOR');
                    t_type[t_count] := 'TERMINATOR';
                    t_val[t_count] := #39;
                    Inc(t_count);
                end;
                #96: begin WriteLn('QUOTE');
                    t_type[t_count] := 'QUOTE';
                    t_val[t_count] := #96;
                    Inc(t_count);
                end;
                ',': begin WriteLn('COMMA');
                    t_type[t_count] := 'COMMA';
                    t_val[t_count] := ',';
                    Inc(t_count);
                end;
                '|': begin WriteLn('PIPE');
                    t_type[t_count] := 'PIPE';
                    t_val[t_count] := '|';
                    Inc(t_count);
                end;
                ';': begin WriteLn('COMMENT');
                    while (i < bytes) and (buf[i] <> #10) do
                        Inc(i);
                end;
          
            // ' ', #9, #13: ; dont remeber what this was
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
                                t_type[t_count] := UpperCase(word);
                                WriteLn(UpperCase(word)); // DEBUG PRINT
                            end
                            else
                                begin
                                t_type[t_count] := 'IDENTIFIER';
                                WriteLn('IDENTIFIER'); // DEBUG PRINT
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
                            word := word + buf[i];
                            Inc(i);
                        end;
                    
                   if (Pos('.', word) > 0) or (Pos('f', word) > 0) then
                        isFloat := True;

                    if isFloat then
                        begin
                            t_type[t_count] := 'FLOAT'; // Store as type NUMBER
                            t_val[t_count] := word; // put number into value
                            WriteLn('FLOAT');
                            Inc(t_count);
                            Dec(i); // Dec to counteract Inc at bottom of main loop
                        end
                    else
                        begin
                            t_type[t_count] := 'NUMBER'; // Store as type NUMBER
                            t_val[t_count] := word; // put number into value
                            WriteLn('NUMBER');
                            Inc(t_count);
                            Dec(i); // Dec to counteract Inc at bottom of main loop
                        end;
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
                    t_type[t_count] := 'STRING';
                    t_val[t_count] := word;
                    Inc(t_count);
                    // no Dec(i) needed, already on closing quote, main Inc(i) moves past it
                end; 
                
        end; 
        end; 
        Inc(i); // Increment position in buffer
    until i >= bytes; // Runs until EOF
    {// ARRAY PRINT DEBUG
    iii := 0;
   for iii := 0 to t_count - 1 do
    Writeln(t_type[iii]);
    iii := 0;
    for iii := 0 to t_count - 1 do
    Writeln(t_val[iii]);
    // ARRAY PRINT DEBUG}
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
        symName[i] := '';
        end;
    FillChar(stack, SizeOf(stack), 0);
    FillChar(return_FName, SizeOf(return_FName), 0);
    FillChar(return_FType, SizeOf(return_FType), 0);
    deleteFile('intermediate.asm');
    deleteFile('text.tmp');
    deleteFile('data.tmp');
    return_FCount := 0;
    symCount := 0;
    sp := 0;
end;

begin
if ParamCount = 1 then
    begin
        filename := ParamStr(1);
        openFile;    
        arrayInit;
        lexer;
        openIntermediateFile;
        parser;
        closeIntermediateFile;
        writeASM;
    end
else
    WriteLn('No File Loaded');
end.