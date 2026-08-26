unit IO;
// All file operations and ASM instrinsics

interface
uses
    BaseUnix, SysUtils, Unix;
var
    buf, databuf, textbuf, bbuf: Array[0..1048575] of Char;
    filename, output_filename, stdlib_filename: String;
    fd, fd2, fd3, fd4, fd5: CInt;
    bytes, bbytes: CInt;

procedure writeOut(s: String);
procedure writeText(s: String);
procedure writeData(s: String);
procedure writeBSS(s: String);

procedure openFile;
procedure openIntermediateFile;
procedure writeASM;
procedure closeIntermediateFile;

function emitSyscall(num, arg1, arg2, arg3, arg4, arg5, arg6: String): String;

procedure functionPrintW(source: String);
procedure functionPrintF(source: String);

procedure asmFoundations();

implementation

procedure writeOut(s: String); begin fpWrite(fd2, s[1], Length(s)); end;
procedure writeText(s: String); begin fpWrite(fd3, s[1], Length(s)); end;
procedure writeData(s: String); begin fpWrite(fd4, s[1], Length(s)); end;
procedure writeBSS(s: String); begin fpWrite(fd5, s[1], Length(s)); end;

procedure closeIntermediateFile; begin fpClose(fd3); fpClose(fd4); end;
procedure openFile; // includes standard library
var
    libBytes, markerLen, i: CInt;
    marker: String;
begin
    WriteLn(#10 + 'LOADING STANDARD LIBRARY');
    FillChar(buf, SizeOf(buf), 0);
    fd := fpOpen(stdlib_filename, O_RdOnly);
    libBytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);

    marker := #10 + 'NEXTFILE' + #10;
    markerLen := Length(marker);
    for i := 1 to markerLen do
        buf[libBytes + i - 1] := marker[i];

    WriteLn('LOADING SOURCEFILE LIBRARY');
    fd := fpOpen(filename, O_RdOnly);
    bytes := FpRead(fd, buf[libBytes + markerLen], SizeOf(buf) - libBytes - markerLen);
    fpClose(fd);

    bytes := bytes + libBytes + markerLen;
end;

{procedure openFile; // USE TO SKIP StANDARD LIBRARY
begin
    WriteLn('LOADING SOURCEFILE LIBRARY');
    fd := fpOpen(filename, O_RdOnly);
    bytes := FpRead(fd, buf, SizeOf(buf));
    fpClose(fd);
end;}

procedure openIntermediateFile; // open temp sourcefiles
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
    WriteOut('   g_argc: resq 1' + #10);
    WriteOut('   g_argv: resq 1' + #10);
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

// picky about which registers are loaded
function emitSyscall(num, arg1, arg2, arg3, arg4, arg5, arg6: String): String;
begin
    Writeln('RMIT SYSCALL');
    WriteText('    mov rax, ' + num + #10);
    WriteText('    mov rdi, ' + arg1 + #10);
    WriteText('    mov rsi, ' + arg2 + #10);
    WriteText('    mov rdx, ' + arg3 + #10);
    WriteText('    mov r10, ' + arg4 + #10);
    WriteText('    mov r8, ' + arg5 + #10);
    WriteText('    mov r9, ' + arg6 + #10);
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

// these print functions are harder to me than 80% of the compiler was
procedure asmFoundationsMINE(); // Its happening
begin
    WriteText(#10 + 'global _start' + #10);
    WriteText('_start:'+ #10);
    WriteText('  mov rax, [rsp]'+ #10);
    WriteText('  mov [g_argc], rax'+ #10);
    WriteText('  lea rax, [rsp + 8]'+ #10);
    WriteText('  mov [g_argv], rax'+ #10);
    WriteText('  call main'+ #10);
    WriteText('  mov rdi, rax'+ #10);
    WriteText('  mov rax, 60'+ #10);
    WriteText('  syscall'+ #10);

    // PRINT_QWORD =======================================
    // raw value is deposited into rax before this ever runs
    // dividing by 10 and taking the remainder the adding ascii zero code convers it into ascii
    // gives order wrong after loop, goes by least signifiacnt digit need it most signifiacnt for output
    WriteText(#10 + 'print_qword:' + #10);
    // setup counter
    WriteText(#10 + 'mov rcx, 0' + #10); // counter to count how many charachters while walking buffer
    WriteText(#10 + 'mov rsi, digitbuf + 20' + #10); // set maxiumum legth of the buffer?
    WriteText(#10 + 'mov rbx, 10' + #10); // /10 for conversion
    // loop over chars --------------------------
    WriteText(#10 + '.collect:' + #10); // self-explanitory
    WriteText(#10 + 'cqo' + #10);
    WriteText(#10 + 'idiv rbx' + #10);
    WriteText(#10 + 'add rdx, 48' + #10); // add 48 to the remainder to convert it into the ascii value '0' aval
    WriteText(#10 + 'push rdx' + #10); // remainder here, pushing into stack will invert the order. it will get
                                      // pushed down by subsequent pushes like how a forth stack works
    WriteText(#10 + 'inc rcx' + #10); // increment counter
    WriteText(#10 + 'test rax, rax' + #10); // see if 0, does an and and sets zero flag. if zero then ZF
                                            // if it is not zero then the flag is cleared
    WriteText(#10 + 'jnz .collect' + #10); // uses flags from test and and jumps if not zero, repeating the loop
                                            // until its zero and there are no more charachters
    // emit -----------------------------------------
    WriteText(#10 + 'xor r10, r10' + #10); // initialize
    WriteText(#10 + 'add r10, rcx' + #10); // copy counter to r10 because that boy is about be CLOBBERED

    WriteText(#10 + '.emit:' + #10); // jump point
    WriteText(#10 + 'pop rdx' + #10); // return rax to the stack (flipped and in correct order)
    WriteText(#10 + 'mov [digitbuf + r10], rdx' + #10); // throw chars at the end of the buffer (i hope)
    WriteText(#10 + 'dec rcx' + #10);
    WriteText(#10 + 'test rcx, rcx' + #10); // check if zero
    WriteText(#10 + 'jnz .emit' + #10); // jump not zero so itll loops down to zero and then quits

    //WriteText(#10 + 'add r10, 1' + #10)
    ///WriteText(#10 + 'xor rax, rax' + #10); // initialize
    WriteText(#10 + 'add rdx, 32' + #10); // put a space on the end of that bitch
    WriteText(#10 + 'add [digitbuf + r10], rdx' + #10); // move the contents of into the buffer
    WriteText(#10 + 'mov rdx, r10' + #10); // THE GREAT UNCLOBBER
    // sys(num, location, buffer, count) --------------------
    WriteText('    mov rax, 1' + #10); // write
    WriteText('    mov rdi, 1' + #10);
    WriteText('    mov rsi, digitbuf' + #10);
    //WriteText('    mov rdx, 1' + #10); no need, happens above
    WriteText('    syscall' + #10);
    WriteText('    ret' + #10 + #10);

    // PRINT_FLOAT =======================================
    // PLACEHOLDER
    // raw value is deposited into rax before this ever runs
    // dividing by 10 and taking the remainder the adding ascii zero convers it into ascii
    // gives order wrong after loop, goes by least signifiacnt digit need it most signifiacnt for output
    WriteText(#10 + 'print_float:' + #10);
    // setup counter
    WriteText(#10 + 'mov rcx, 0' + #10); // counter to count how many charachters while walking buffer
    WriteText(#10 + 'mov rsi, [digitbuf] + 20' + #10); // set maxiumum legth of the buffer?
    WriteText(#10 + 'mov xmm1, 10' + #10); // /10 for conversion
    // loop over chars --------------------------
    WriteText(#10 + '.collect:' + #10); // self-explanitory
    WriteText(#10 + 'cqo' + #10);
    WriteText(#10 + 'idiv xmm0' + #10);
    WriteText(#10 + 'add rdx, 48' + #10); // add 48 to the remainder to convert it into the ascii value '0' aval
    WriteText(#10 + 'push rdx' + #10); // remainder here, pushing into stack will invert the order. it will get
                                      // pushed down by subsequent pushes like how a forth stack works
    WriteText(#10 + 'inc rcx' + #10); // increment counter
    WriteText(#10 + 'test rax, rax' + #10); // see if 0, does an and and sets zero flag. if zero then ZF
                                            // if it is not zero then the flag is cleared
    WriteText(#10 + 'jnz .collect' + #10); // uses flags from test and and jumps if not zero, repeating the loop
                                            // until its zero and there are no more charachters
    // emit -----------------------------------------
    WriteText(#10 + '.emit' + #10);
    WriteText(#10 + 'pop rdx' + #10); // return rax to the stack (flipped and in correct order)
    WriteText(#10 + 'mov rdx, 32' + #10); // put a space on the end of that bitch
    WriteText(#10 + 'mov [digitbuf], rdx' + #10); // move the contents of into the buffer
    // sys(num, location, buffer, count) --------------------
    // write(rax (1), rdi (1), rsi [digitbuf], rdx (count))
    WriteText('    mov rax, 1' + #10); // write
    WriteText('    mov rdi, 1' + #10);
    WriteText('    mov rsi, digitbuf' + #10);
    WriteText('    mov rdx, 1' + #10);
    WriteText('    syscall' + #10);
    WriteText('    ret' + #10 + #10);

    // conversions
    WriteText(#10 + 'intToFloat:' + #10); // broken
    WriteText('    cvtsi2sd xmm0, rax' + #10);
    WriteText('    ret' + #10 + #10);

    WriteText(#10 + 'floatToInt:' + #10);
    WriteText('    cvttsd2si rax, xmm0' + #10);  // arg comes in xmm0
    WriteText('    ret' + #10 + #10);

    //WriteText(#10 + 'strToVal:' + #10);

end;

procedure asmFoundations();
begin
    // placed at bottom for file
    WriteText(#10 + 'global _start' + #10);
    WriteText('_start:'+ #10);
    WriteText('  mov rax, [rsp]'+ #10);
    WriteText('  mov [g_argc], rax'+ #10);
    WriteText('  lea rax, [rsp + 8]'+ #10);
    WriteText('  mov [g_argv], rax'+ #10);
    WriteText('  call main'+ #10);
    WriteText('  mov rdi, rax'+ #10);
    WriteText('  mov rax, 60'+ #10);
    WriteText('  syscall'+ #10);


    // NO LONGER PUTTING THIS OFF I WILL BE REWrITING SOON, PREPARE YOURSELVES FOR SOME GRADE D ASSEMBLY
    // NOT MY WORK NEED TO REWRITE WHEN I KNOW MORE ASM> FOR DEBUGGING ONLY ===========
    // char code in AL, writes it to stdout via digitbuf
    WriteText(#10 + 'print_char:' + #10);
    WriteText('    mov [digitbuf], al' + #10);
    WriteText('    mov rax, 1' + #10);
    WriteText('    mov rdi, 1' + #10);
    WriteText('    mov rsi, digitbuf' + #10);
    WriteText('    mov rdx, 1' + #10);
    WriteText('    syscall' + #10);
    WriteText('    ret' + #10 + #10);

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
    // consolidated: identical to print_qword_nosp, plus a trailing space
    WriteText(#10 + 'print_qword:' + #10);
    WriteText('    call print_qword_nosp' + #10);
    WriteText('    mov al, 32' + #10);                   // ASCII space
    WriteText('    call print_char' + #10);
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
    WriteText('    mov al, 46' + #10);                  // ASCII '.'
    WriteText('    call print_char' + #10);             // print '.'
    WriteText('    pop rax' + #10);                     // frac digits
    WriteText('    call print_frac3' + #10);            // print them, zero padded to 3
    WriteText('    mov al, 32' + #10);                  // ASCII space
    WriteText('    call print_char' + #10);             // print separator space
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

    // i did write these though
    // probably explais why intToFloat is broken haha
    WriteText(#10 + 'intToFloat:' + #10);
    WriteText('    cvtsi2sd xmm0, rax' + #10);
    WriteText('    ret' + #10 + #10);

    WriteText(#10 + 'floatToInt:' + #10);
    WriteText('    cvttsd2si rax, xmm0' + #10);  // arg comes in xmm0
    WriteText('    ret' + #10 + #10);

end;
end.
