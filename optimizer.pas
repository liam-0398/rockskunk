unit Optimizer;
// Passes over intermediate.asm before NASM and optimizaes the ASM with regex

interface
    uses
        BaseUnix, SysUtils, Unix;
    var
        fd, bytes: cint;
        buf: Array[0..8192] of Byte;
        filename: String;


implementation



procedure openFileO();
begin
    fd := fpOpen(filename, O_RdOnly);
    bytes := FpRead(fd, buf[bytes], SizeOf(buf) - bytes);
   
end;

procedure closeFileO(); begin fpClose(fd); end;


procedure optimizer();
begin
    filename := 'intermediate.asm';
    openFileO;
    closeFileO;



end;
end.