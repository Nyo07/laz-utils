unit utils.env;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fileinfo, winpeimagereader;

function LoadEnv(const FileName: string): TStringList;
function GetEnvFromFile(sl: TStringList; const Key: string): string;
function GetVersaoApp :String;

implementation

function LoadEnv(const FileName: string): TStringList;
var
  sl: TStringList;
begin
  sl := TStringList.Create;
  if FileExists(FileName) then
    sl.LoadFromFile(FileName);
  Result := sl;
end;

function GetEnvFromFile(sl: TStringList; const Key: string): string;
var
  i: Integer;
  s, k, v: string;
begin
  Result := '';
  for i := 0 to sl.Count - 1 do
  begin
    s := sl[i];
    if (Pos('=', s) > 0) then
    begin
      k := Trim(Copy(s, 1, Pos('=', s) - 1));
      v := Trim(Copy(s, Pos('=', s) + 1, Length(s)));
      if k = Key then
      begin
        Result := v;
        Exit;
      end;
    end;
  end;
end;

function GetVersaoApp: String;
var
  FileVerInfo: TFileVersionInfo;
begin
  FileVerInfo := TFileVersionInfo.Create(nil);
  try
    FileVerInfo.ReadFileInfo;
    Result := FileVerInfo.VersionStrings.Values['FileVersion'];
  finally
    FileVerInfo.Free;
  end;
end;

end.

