program rockskunk_x64;
uses
    BaseUnix, SysUtils, Unix;

const
    acceptedKeywords: array[0..14] of String =
    ('ADD', 'V', 'S', 'R', 'D',
     'F', 'LF', 'LW', 'W', 'I', 'E',
     'OR', 'AND', 'NOR', 'XOR');
var
    buf: Array[0..65535] of Char;
    floats: Array[0..512] of String;
    t_type, t_val: Array[0..4096] of String;

    braceEmitted: Boolean;
    bytes: CInt;
    currentFN: String;
    f_count, labelCounter, position, t_count: Integer;
    fd, fd2: CInt;
    filename: String;

{
    Ripped from a Pascal -> C Transpiler for an old language I had
    Undergoing massive restructuring to output rockskunk -> NASM
}

// HELPERS =================================================
// ========================================================

procedure writeOut(s: String); // NASM sourcefile write helper
begin
    fpWrite(fd2, s[1], Length(s));
end;

function keywordCheck(word: String): Boolean; // Flag keywords
var
    i: Integer;
begin
    keywordCheck := False;
    for i := 0 to 29 do
        begin
            if word = acceptedKeywords[i] then 
                begin
                keywordCheck := True;
                break;
                end;
        end;
end;

function isFloat(word: String): Boolean; // check array to see if var is float
var
    i: Integer;
begin
    isFloat := False;
    for i := 0 to f_count - 1 do
        begin
            if word = floats[i] then 
                begin
                isFloat := True;
                break;
                end;
        end;
end;

procedure openFile; // Open sourcefile, SLANG 
begin
    FillChar(buf, SizeOf(buf), 0);
    fd := fpOpen(filename,O_RdOnly);
    bytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);
end;

procedure openIntermediateFile; // open NASM sourcefile
begin
    fd2 := fpOpen('intermediate.asm',O_WRONLY OR O_CREAT OR O_TRUNC, 438);
end;

procedure closeIntermediateFile; begin fpClose(fd2); end;

// CODE GENERATION ===========================================
// ========================================================

// BLOCKS -----------------------------------------------------------
procedure emitGlobalBlock(); begin end;   // {V ...}
procedure emitStaticBlock(); begin end;   // {S ...}
procedure emitRecordBlock(); begin end;   // {R name ...}
procedure emitDirectiveBlock(); begin end; // {D ...}
procedure emitFileInclude(); begin end;   // ADD("file.rsk")

// FUNCTIONS -----------------------------------------------------------
procedure emitFN(fname : String);
begin 
    writeOut(fname + ':' + #10);
end;

procedure emitFunctionSetup();
begin 
    writeOut('    push rbp' + #10);
    writeOut('    mov rbp, rsp' + #10);
    writeOut('    sub rsp, 16' + #10);
end;

procedure emitFunctionTeardown(result : String);
begin 
    writeOut('    mov rax, ' + result + #10);
    writeOut('    add rsp, 16' + #10);
    writeOut('    pop rbp' + #10);
    writeOut('    ret' + #10);
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
    writeOut('   mov rax, ' + value + #10);

end;

procedure emitPairAssign(); begin end;
procedure emitCompoundAssign(); begin end; // :+=

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
procedure emitAdd(dst, src: String);
begin
    writeOut('    add ' + dst + ', ' + src + #10);
end;

procedure emitSub(dst, src: String);
begin
    writeOut('    sub ' + dst + ', ' + src + #10);
end;

procedure emitMul(dst, src: String);
begin
    writeOut('    imul ' + dst + ', ' + src + #10);
end;

procedure emitDiv(dividend, divisor: String);
begin
    begin
        // GUARD DIV 0
        writeOut('    cmp ' + divisor + ', 0' + #10);
        writeOut('    je .divzero_' + inttostr(labelCounter) + #10);
        writeOut('    mov rax, ' + dividend + #10);
        writeOut('    cqo' + #10);
        writeOut('    idiv ' + divisor + #10);
        writeOut('.divzero_' + inttostr(labelCounter) + ':' + #10);
    end;
end;

procedure emitMod(); begin end;

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


// AST ================================================================
// ========================================================

// Maybe skip? Track strack offset by buffering to string before writing
// to a file directly and counting 


// PARSER =============================================================
// ========================================================

// Used to check type (identifier) and value of words for decision making
function peek(): String; // Look at the next token non-destructively
begin
    peek := t_type[position]; // check type, type used to determine decisions
end;
function consume(): String; // Eat the next token and then remove it
begin
    consume := t_val[position]; // pull value (actual content of token)
    Inc(position);  // Increment counter to drop the token
end;

procedure parser();
begin

end;

// LEXER =============================================================
// ========================================================
//Tokenizes input into a pair, ex = is type (EQUAL) and value (=). 

procedure lexer();
var
    i, linecount: Integer;
    word: String;
    isKeyword: Boolean;
begin
    linecount := 0;
    isKeyword := False;
    word := '';
    t_count := 0;
    for i := 0 to 1023 do
        begin
            t_type[i] := '';
            t_val[i] := '';
        end;
    
    i := 0; // Tracks position in buffer
    repeat
        
        if buf[i] = #10 then // Handle newline
            Inc(linecount);
        case buf[i] of // Handle intrinsic words 
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
            #39: begin WriteLn('SINGLEQUOTE');
                t_type[t_count] := 'SINGLEQUOTE';
                t_val[t_count] := #39;
                Inc(t_count);
            end;
            #96: begin WriteLn('QUOTE');
                t_type[t_count] := 'QUOTE';
                t_val[t_count] := #96;
                Inc(t_count);
            end;
            ';': begin WriteLn('SEMICOLON');
                t_type[t_count] := 'SEMICOLON';
                t_val[t_count] := ';';
                Inc(t_count);
            end;
            ',': begin
                t_type[t_count] := 'COMMA';
                t_val[t_count] := ',';
                Inc(t_count);
            end;
            ';': begin WriteLn('COMMENT');
                while (i < bytes) and (buf[i] <> #10) do
                    Inc(i);
            end;
            ' ', #9, #13: ; 
            else
                if buf[i] in ['a'..'z', 'A'..'Z', '_'] then // Handle letters
                    begin
                    word := '';
                    while buf[i] in ['a'..'z', 'A'..'Z', '_', '0'..'9'] do
                        begin
                            word := word + buf[i];  // Collect words, add charachters to word
                            Inc(i); // Increment position in file, +1 charachter
                        end;
                        // DEBATING WHETHER TO REUSE FOR PASCAL OUT BUT NOT SURE HOW
                        isKeyword := keywordCheck(UpperCase(word)); // Check if word is keyword
                        if isKeyword then  
                            begin
                                t_type[t_count] := UpperCase(word);
                            end
                            else
                                t_type[t_count] := 'IDENTIFIER';
                        t_val[t_count] := word;
                        Inc(t_count);
                        Dec(i);  
                    end
                    
                else if buf[i] in ['0'..'9'] then // Handle numbers
                begin
                    word := '';
                    while buf[i] in ['0'..'9'] do // Collect digits
                        begin   
                            word := word + buf[i]; // add charachters to word
                            Inc(i); 
                        end;
                        if buf[i] = '.' then // check decimal, float
                        begin
                            word := word + '.'; // append decimal
                            Inc(i); // move past decimal
                            while buf[i] in ['0'..'9'] do // collect digits past decimal
                            begin
                                word := word + buf[i];
                                Inc(i);
                            end;
                        end;
                        t_type[t_count] := 'NUMBER'; // Store as type NUMBER
                        t_val[t_count] := word; // put number into value
                        Inc(t_count);
                        Dec(i); // Dec to counteract Inc at bottom of main loop
                    end
                else if buf[i] = #39 then // Handle single quotes
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

// INIT
begin
if ParamCount = 1 then
    begin
        filename := ParamStr(1);
        openFile;
        lexer;
        parser;
    end
else
    WriteLn('No File Loaded');
end.