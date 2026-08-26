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

    // NOTE TO ANYONE THAT IS ALSO WINGING IT AND LEARNING AS THEY GO. IF YOU DECREMENT THE COUNTER YOU USE TO COLLECT ALL THE CHARACHTERS INTO THE BUFFER, THEY WILL BE BACKWARDS AND YOU WILL SPEND HOURS TRYING TO FIGURE OUT WHY

    WriteText(#10 + 'print_qword:' + #10);
    WriteText('mov rcx, 0' + #10);      // start collection counter at zero
    WriteText('mov rsi, digitbuf' + #10);  // prepare buffer
    WriteText('mov rbx, 10' + #10);     // pull in 10 for the ascii conversion division
    WriteText('xor r11, r11' + #10);    // initialize buffer counter
    WriteText('mov r11, 0' + #10);      // start at 0
    WriteText('.collect:' + #10);
    WriteText('cqo' + #10);             // prep registers
    WriteText('idiv rbx' + #10);        // divide rax rbx
    WriteText('add rdx, 48' + #10);     // add ascii '0' to remainder, completing conversion to charachter
    WriteText('push rdx' + #10);        // hide rdx in the stack so it doesnt get clobbered and
                                        //stack is like forth so its in right order
    WriteText('inc rcx' + #10);         // increment counter
    WriteText('test rax, rax' + #10);   // check if rax = 0
    WriteText('jnz .collect' + #10);    // if its not 0, continue loop
    WriteText('.emit:' + #10);
    WriteText('pop rdx' + #10);         // pull the charachters back out of the stack, LIFO like forth
    WriteText('mov [digitbuf + r11], dl' + #10); // mov the low bytes of rdx into the buffer at the offset of the counter
    WriteText('inc r11' + #10);
    WriteText('cmp rcx, r11' + #10);    // check match
    WriteText('jne .emit' + #10);       // continue loop if no match
    WriteText('xor rdx, rdx' + #10);    // reinit rdx
    WriteText('add rdx, 32' + #10);     // add ascii space code
//WriteText('add [digitbuf + r10 + 1], dl' + #10); // add the space at the end of the line, actually
                                        //corrupt the output lol
//WriteText('add rcx, 1' + #10); // account for space? I dont think this is working
// Threaten the linux kernel
    WriteText('mov rax, 1' + #10);
    WriteText('mov rdi, 1' + #10);
    WriteText('mov rsi, digitbuf' + #10);
    WriteText('mov rdx, rcx' + #10);    // put saved counter amount into rdx for the syscall
    WriteText('syscall' + #10);
    WriteText('ret' + #10 + #10);

    // PRINT_FLOAT =======================================
    // PLACEHOLDER
    WriteText(#10 + 'print_float:' + #10);
    WriteText('mov rcx, 0' + #10);      // start collection counter at zero
    WriteText('mov rsi, digitbuf' + #10);  // prepare buffer
    WriteText('mov rbx, 10' + #10);     // pull in 10 for the ascii conversion division
    WriteText('xor r11, r11' + #10);    // initialize buffer counter
    WriteText('mov r11, 0' + #10);      // start at 0
    WriteText('.collect:' + #10);
    WriteText('cqo' + #10);             // prep registers
    WriteText('idiv rbx' + #10);        // divide rax rbx
    WriteText('add rdx, 48' + #10);     // add ascii '0' to remainder, completing conversion to charachter
    WriteText('push rdx' + #10);        // hide rdx in the stack so it doesnt get clobbered and
                                        //stack is like forth so its in right order
    WriteText('inc rcx' + #10);         // increment counter
    WriteText('test rax, rax' + #10);   // check if rax = 0
    WriteText('jnz .collect' + #10);    // if its not 0, continue loop
    WriteText('.emit:' + #10);
    WriteText('pop rdx' + #10);         // pull the charachters back out of the stack, LIFO like forth
    WriteText('mov [digitbuf + r11], dl' + #10); // mov the low bytes of rdx into the buffer at the offset of the counter
    WriteText('inc r11' + #10);
    WriteText('cmp rcx, r11' + #10);    // check match
    WriteText('jne .emit' + #10);       // continue loop if no match
    WriteText('xor rdx, rdx' + #10);    // reinit rdx
    WriteText('add rdx, 32' + #10);     // add ascii space code
//WriteText('add [digitbuf + r10 + 1], dl' + #10); // add the space at the end of the line, actually
                                        //corrupt the output lol
//WriteText('add rcx, 1' + #10); // account for space? I dont think this is working
// Threaten the linux kernel
    WriteText('mov rax, 1' + #10);
    WriteText('mov rdi, 1' + #10);
    WriteText('mov rsi, digitbuf' + #10);
    WriteText('mov rdx, rcx' + #10);    // put saved counter amount into rdx for the syscall
    WriteText('syscall' + #10);
    WriteText('ret' + #10 + #10);

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
