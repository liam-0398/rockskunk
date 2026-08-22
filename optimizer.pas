unit Optimizer;
// Passes over intermediate.asm before NASM and optimizaes the ASM with regex

interface
    uses
        BaseUnix, SysUtils, Unix, RegExpr;
    var
        fd, bytes: cint;
        buf: Array[0..1048575] of Byte;
        filename: String;
        contents: ANSIString;
        RE: TRegExpr;

    procedure openFileO();
    procedure writeFileO();
    procedure deadCodePass();
    procedure optimize(); 

implementation

procedure openFileO();
begin
    WriteLn('OPTIMIZER - OPENING FILE');
    fd := fpOpen(filename, O_RDWR);
    bytes := FpRead(fd, buf[bytes], SizeOf(buf));
        if bytes = 0 then
            WriteLn('OPTIMIZER - I CANT BELIEVE YOUVE DONE THIS - EMPTY FILE');
    
    SetString(contents, PAnsiChar(@buf[0]), bytes);
   
end;

procedure writeFileO();
begin
    WriteLn('OPTIMIZER - WRITING FILE');
    fpLseek(fd, 0, SEEK_SET);
    fpFTruncate(fd, 0);
    fpWrite(fd, contents[1], Length(contents));

    fpClose(fd);
end;

procedure deadCodePass();
begin
    WriteLn('OPTIMIZER - DEAD CODE');

    // store reload fix across all registers (label-safe)
    // store reload fix across all registers
    RE.Expression := '^[ \t]*(mov[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*(rax|rbx|rcx|rdx|rsi|rdi|r8|r9|r10|r11|r12|r13|r14|r15)[ \t]*\r?\n)[ \t]*mov[ \t]*\3[ \t]*,[ \t]*\[rbp-\2\][ \t]*\r?\n';
    contents := RE.Replace(contents, '$1', True);

    // chained store reload
    RE.Expression := '(mov (\w+), (.+)\r?\nmov (\[.+\]), \2\r?\n)mov \2, \4\r?\n';
    contents := RE.Replace(contents, '$1', True);

    // syscall
    RE.Expression := '^[ \t]*mov[ \t]+(rsi|rdx)[ \t]*,[ \t]*0[ \t]*\r?\n[ \t]*mov[ \t]+(rsi|rdx)[ \t]*,[ \t]*0[ \t]*\r?\n([ \t]*syscall)';
    contents := RE.Replace(contents, '$3', True);

    // no-ops
    RE.Expression := 'mov ([a-z0-9]+), \1\r?\n';
    contents := RE.Replace(contents, '', True);

end;

procedure optimize();
begin
    WriteLn('OPTIMIZER');
    filename := 'intermediate.asm';
    openFileO;
    RE := TRegExpr.Create();
    RE.ModifierM := True;
    deadCodePass;
    deadCodePass;
    deadCodePass;
    writeFileO;
    RE.Free;
end;
end.