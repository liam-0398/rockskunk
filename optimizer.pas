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
    bytes := FpRead(fd, buf[bytes], SizeOf(buf) - bytes);
        if bytes = 0 then
            WriteLn('OPTIMIZER - I CANT BELIEVE YOUVE DONE THIS - EMPTY FILE');
   
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
    SetString(contents, PAnsiChar(@buf[0]), bytes);

    // mov rax, rax
    RE.Expression := '^[ \t]*mov[ \t]+rax[ \t]*,[ \t]*rax[ \t]*\r?\n';
    contents := RE.Replace(contents, '', True);

    // move rax into var and immediately move var back into rax
    RE.Expression := '^[ \t]*mov[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*rax[ \t]*\r?\n([ \t]*mov[ \t]*rax[ \t]*,[ \t]*\[rbp-\1\][ \t]*\r?\n)';
    contents := RE.Replace(contents, '', True);

    // move rdi into var and immediately move var back into rdi
    RE.Expression := '^[ \t]*mov[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*rdi[ \t]*\r?\n([ \t]*mov[ \t]*rdi[ \t]*,[ \t]*\[rbp-\1\][ \t]*\r?\n)';
    contents := RE.Replace(contents, '', True);

    // rsi 
    RE.Expression := '^[ \t]*mov[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*rsi[ \t]*\r?\n([ \t]*mov[ \t]*rsi[ \t]*,[ \t]*\[rbp-\1\][ \t]*\r?\n)';
    contents := RE.Replace(contents, '', True);

    // rdx
    RE.Expression := '^[ \t]*mov[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*rdx[ \t]*\r?\n([ \t]*mov[ \t]*rdx[ \t]*,[ \t]*\[rbp-\1\][ \t]*\r?\n)';
    contents := RE.Replace(contents, '', True);

    // syscall
    RE.Expression := '^[ \t]*mov[ \t]+(rsi|rdx)[ \t]*,[ \t]*0[ \t]*\r?\n[ \t]*mov[ \t]+(rsi|rdx)[ \t]*,[ \t]*0[ \t]*\r?\n([ \t]*syscall)';
    contents := RE.Replace(contents, '$3', True);


end;

procedure optimize();
begin
    WriteLn('OPTIMIZER');
    filename := 'intermediate.asm';
    openFileO;
    RE := TRegExpr.Create();
    RE.ModifierM := True;
    deadCodePass;
    writeFileO;
    RE.Free;
end;
end.