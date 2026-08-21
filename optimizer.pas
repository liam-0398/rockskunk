program rskc-optimizer;
// Passes over intermediate.asm before NASM and optimizaes the ASM with regex
var
    fd, bytes: cint;
    buf: array[0..8192] of Byte;

procedure openFile();
begin
    WriteLn(IntToStr(t_line[tokenCount]) + ' - ' + 'LOADING SOURCEFILE LIBRARY');
    fd := fpOpen(filename, O_RdOnly);
    bytes := FpRead(fd, buf[bytes], SizeOf(buf) - bytes);
   
end;

procedure closeFile(); begin fpClose(fd); end;

begin
    openFile;
    closeFile;

end.