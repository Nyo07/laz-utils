unit utils.http;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, HTTPDefs, httpprotocol;

function trataParam(AReq : TRequest): String;

implementation

function trataParam(AReq: TRequest): String;
var
  LPos: integer;
begin

  Result := AReq.URL;
  if (Result = '') then Result := AReq.URI;
  if (Result = '') then Result := AReq.PathInfo;

  Lpos := LastDelimiter('/', Result);
  Result := copy(Result, LPos + 1, Length(Result));

  LPos := pos('?', Result);
  if (LPos > 0) then
    Result := copy(Result, 1, LPos - 1);

end;

end.

