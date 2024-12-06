unit utils.crypt;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

function Crypt(Pass, Strg : String) : String;

implementation

function Crypt(Pass, Strg : String) : String;
var
  i, a, b : integer;
begin
  a := 1;
  For i := 1 To Length(Strg) do
  begin
     B := Ord(copy(Pass, a, 1)[1]);
     a := a + 1;
     If a > Length(Pass) Then
       a := 1;
     Result := Result + Chr(Ord(copy(Strg, i, 1)[1]) Xor B);
  end;
end;

end.

