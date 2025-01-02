unit utils.os;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

  function diretorioApp(): String;

implementation

function diretorioApp(): String;
begin
  Result := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

end.

