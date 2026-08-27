unit Optimizer;
// Passes over intermediate.asm before NASM and optimizaes the ASM with regex

interface
    uses
        BaseUnix, SysUtils, Unix, RegExpr;
    var
        fd, bytes: cint;
        buf: Array[0..16777200] of Byte;
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
    fd := fpOpen(filename, O_RDWR);
    bytes := FpRead(fd, buf[0], SizeOf(buf));
        if bytes = 0 then
            WriteLn('OPTIMIZER - I CANT BELIEVE YOUVE DONE THIS - EMPTY FILE');
    
    SetString(contents, PAnsiChar(@buf[0]), bytes);
   
end;

procedure writeFileO();
begin
    WriteLn('WRITING');
    fpLseek(fd, 0, SEEK_SET);
    fpFTruncate(fd, 0);
    fpWrite(fd, contents[1], Length(contents));

    fpClose(fd);
end;

procedure deadCodePass();
begin

    // store reload fix across all registers
    RE.Expression := '^[ \t]*(mov[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*(rax|rbx|rcx|rdx|rsi|rdi|r8|r9|r10|r11|r12|r13|r14|r15)[ \t]*\r?\n)[ \t]*mov[ \t]*\3[ \t]*,[ \t]*\[rbp-\2\][ \t]*\r?\n';
    contents := RE.Replace(contents, '$1', True);

    // chained store reload
    RE.Expression := '(mov (\w+), (.+)\r?\nmov (\[.+\]), \2\r?\n)mov \2, \4\r?\n';
    contents := RE.Replace(contents, '$1', True);

    // no-ops
    RE.Expression := 'mov ([a-z0-9]+), \1\r?\n';
    contents := RE.Replace(contents, '', True);

    // xmm store reload
    RE.Expression := '^[ \t]*movsd[ \t]*\[rbp-(\d+)\][ \t]*,[ \t]*(xmm\d+)[ \t]*\r?\n[ \t]*movsd[ \t]*\2[ \t]*,[ \t]*\[rbp-\1\][ \t]*\r?\n';
    contents := RE.Replace(contents, '', True);  

end;

procedure optimize();
begin
    filename := 'intermediate.asm';
    openFileO;
    RE := TRegExpr.Create();
    RE.ModifierM := True;
    WriteLn('optimizing');
    deadCodePass;
    WriteLn('OPTIMIZING');
    deadCodePass; // another one
    WriteLn('OPTIMIZING!!!!');
    deadCodePass; // ANOTHER ONE
    writeFileO;
    RE.Free;
end;
end.
