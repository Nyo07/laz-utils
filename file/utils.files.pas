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
function EncodeBase64FromStream(Stream: TStream): string;
function GetFirstMatchingFileBase64(const APath, APartialName: string): string;
function GetFirstMatchingFile(const APath, APartialName: string): string;

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
begin
  Result := '';
  if not FileExists(AFile) then Exit;

  MS := TMemoryStream.Create;
  try
    MS.LoadFromFile(AFile);
    Result := EncodeBase64FromStream(MS);
  finally
    MS.Free;
  end;
end;


function EncodeBase64FromStream(Stream: TStream): string;
const
  Base64Table: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  InBuf: array[0..2] of Byte;
  OutBuf: array[0..3] of Char;
  BytesRead, I: Integer;
begin
  Result := '';
  Stream.Position := 0;

  while True do
  begin
    BytesRead := Stream.Read(InBuf, 3);
    if BytesRead = 0 then Break;

    for I := BytesRead to 2 do
      InBuf[I] := 0;

    OutBuf[0] := Base64Table[(InBuf[0] shr 2) + 1];
    OutBuf[1] := Base64Table[(((InBuf[0] and $03) shl 4) or (InBuf[1] shr 4)) + 1];
    OutBuf[2] := Base64Table[(((InBuf[1] and $0F) shl 2) or (InBuf[2] shr 6)) + 1];
    OutBuf[3] := Base64Table[(InBuf[2] and $3F) + 1];

    if BytesRead < 3 then
    begin
      OutBuf[3] := '=';
      if BytesRead < 2 then
        OutBuf[2] := '=';
    end;

    Result := Result + OutBuf[0] + OutBuf[1] + OutBuf[2] + OutBuf[3];
  end;
end;

function GetFirstMatchingFileBase64(const APath, APartialName: string): string;
var
  SearchRec: TSearchRec;
  FullPath: string;
begin
  Result := '';
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*' + APartialName + '*', faAnyFile and faArchive, SearchRec) = 0 then
  begin
    try
      FullPath := IncludeTrailingPathDelimiter(APath) + SearchRec.Name;
      Result := FileToBase64(FullPath);
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function GetFirstMatchingFile(const APath, APartialName: string): string;
var
  SearchRec: TSearchRec;
  FullPath: string;
begin
  Result := '';
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(APath) + '*' + APartialName + '*', faAnyFile and faArchive, SearchRec) = 0 then
  begin
    try
      FullPath := IncludeTrailingPathDelimiter(APath) + SearchRec.Name;
      Result := IncludeTrailingPathDelimiter(APath) + SearchRec.Name;
    finally
      FindClose(SearchRec);
    end;
  end;
end;



end.

