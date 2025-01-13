unit utils.files;

{$mode delphi}

interface

uses
  Classes, SysUtils, base64, System.NetEncoding;

function DeleteFilesOlderThanXDays(
    Path: string;
    DaysOld: integer = 0; // 0 => Delete every file, ignoring the file age
    FileMask: string = '*.*'): integer;

function fileDate(AFile : String) : TDateTime;
function base64ToFile(info64, fileWithPath: String): Boolean;
function FileToBase64(const AFile: String): String;

implementation

function DeleteFilesOlderThanXDays(
    Path: string;
    DaysOld: integer = 0; // 0 => Delete every file, ignoring the file age
    FileMask: string = '*.*'): integer;
var
  iFindResult : integer;
  SearchRecord : tSearchRec;
  iFilesDeleted: integer;
begin
  iFilesDeleted := 0;
  iFindResult := FindFirst(FileMask, faAnyFile, SearchRecord);
  if iFindResult = 0 then begin
    while iFindResult = 0 do begin
      if ((SearchRecord.Attr and faDirectory) = 0) then begin
        if (FileDateToDateTime(SearchRecord.Time) < Now - DaysOld) or (DaysOld = 0) then begin
          DeleteFile(path+DirectorySeparator+SearchRecord.Name);
          iFilesDeleted := iFilesDeleted + 1;
        end;
      end;
      iFindResult := FindNext(SearchRecord);
    end;
    FindClose(SearchRecord);
  end;
  Result := iFilesDeleted;
end;

function fileDate(AFile:String):TDateTime;
Var
  S : TDateTime;
  fa : Longint;
Begin
  fa:=FileAge(AFile);
  If Fa<>-1 then
    result:=FileDateTodateTime(fa)
  else
    result := 0;

end;

function base64ToFile(info64, fileWithPath: String): Boolean;
var
  f       : TextFile;
  dado,
  path    : String;
begin

  Result := false;

  path := ExtractFilePath(fileWithPath);
  if not ForceDirectories(path) then
    raise Exception.Create('Erro ao criar diretorio');

  AssignFile(f, fileWithPath);
  dado := DecodeStringBase64(info64);

  try
    try

      Rewrite(f);
      Write(f, dado);

      Result := true;

    except
      on E: Exception do
      begin
        Exception.Create('Erro ao criar o arquivo');
      end;
    end;

  finally
    CloseFile(f);
  end;
end;

function FileToBase64(const AFile: String): String;
var
  MS: TMemoryStream;
  Str: String;
begin
  Result := '';
  if not FileExists(AFile) then
    Exit;
  MS := TMemoryStream.Create;
  try
    MS.LoadFromFile(AFile);
    if MS.Size > 0 then
    begin
      SetLength(Str, MS.Size div SizeOf(Char));
      MS.ReadBuffer(Str[1], MS.Size div SizeOf(Char));
      Result := EncodeStringBase64(Str);
    end;
  finally
    MS.Free;
  end;
end;

end.

