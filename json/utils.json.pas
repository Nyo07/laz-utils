unit utils.json;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DateUtils;

function GetJSONInteger(JsonObj: TJSONObject; const FieldName: String; const Default: Integer = -1; UseDefault: Boolean = False): Integer;
function GetJSONNumber(JsonObj: TJSONObject; const FieldName: String; UseDefault: Boolean = False; const Default: Double = 0.0): Double;
function GetJSONString(JsonObj: TJSONObject; const FieldName: String; UseDefault: Boolean = False; const Default: String = ''; const APrefixDefault: String = ''): String;
function GetJSONDate(JsonObj: TJSONObject; const FieldName: String; const Default: TDateTime = 0; UseDefault: Boolean = False): TDateTime;
function GetJSONDateTime(JsonObj: TJSONObject; const FieldName: String; const Default: TDateTime) : TDateTime;
function GetJSONDateTime(JsonObj: TJSONObject; const FieldName: String) : TDateTime;

function FindJSONFieldCaseInsensitive(AObj: TJSONObject; const AName: String): TJSONData;
function FindPathCI(AObj: TJSONObject; const APath: String): TJSONData;


function GetJSONIntegerCI(JsonObj: TJSONObject; const FieldName: String; const Default: Integer = -1; UseDefault: Boolean = False): Integer;
function GetJSONStringCI(JsonObj: TJSONObject; const FieldName: String; UseDefault: Boolean = False; const Default: String = ''; const APrefixDefault: String = ''): String;

function GetJSONNumberCI(JsonObj: TJSONObject; const FieldName: String; UseDefault: Boolean = False; const Default: Double = 0.0): Double;
function GetJSONDateCI(JsonObj: TJSONObject; const FieldName: String; const Default: TDateTime = 0; UseDefault: Boolean = False): TDateTime;
function GetJSONDateTimeCI(JsonObj: TJSONObject; const FieldName: String; const Default: TDateTime): TDateTime;
function GetJSONDateTimeCI(JsonObj: TJSONObject; const FieldName: String): TDateTime;



implementation

function FindPathCI(AObj: TJSONObject; const APath: String): TJSONData;
var
  Parts: TStringArray;
  I: Integer;
  CurrentData: TJSONData;
  Obj: TJSONObject;
begin
  Result := nil;
  if (AObj = nil) or (APath = '') then Exit;

  Parts := APath.Split(['.']); // separa por níveis

  CurrentData := AObj;

  for I := 0 to High(Parts) do
  begin
    if not (CurrentData is TJSONObject) then
      Exit(nil);

    Obj := TJSONObject(CurrentData);
    CurrentData := FindJSONFieldCaseInsensitive(Obj, Parts[I]);

    if CurrentData = nil then
      Exit(nil);
  end;

  Result := CurrentData;
end;

function GetJSONNumberCI(JsonObj: TJSONObject; const FieldName: String;
  UseDefault: Boolean; const Default: Double): Double;
var
  FieldValue: TJSONData;
begin
  FieldValue := FindJSONFieldCaseInsensitive(JsonObj, FieldName);

  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Exit(Default)
    else
      raise Exception.CreateFmt('Campo numérico %s não encontrado no JSON.', [FieldName]);
  end;

  if FieldValue.JSONType = jtNumber then
    Result := FieldValue.AsFloat
  else
    raise Exception.CreateFmt('Campo %s não é numérico.', [FieldName]);
end;

function GetJSONDateCI(JsonObj: TJSONObject; const FieldName: String;
  const Default: TDateTime; UseDefault: Boolean): TDateTime;
var
  FieldValue: TJSONData;
  FS: TFormatSettings;
begin
  FieldValue := FindJSONFieldCaseInsensitive(JsonObj, FieldName);

  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Exit(Default)
    else
      raise Exception.CreateFmt('Campo data %s não encontrado no JSON.', [FieldName]);
  end;

  try
    FS := DefaultFormatSettings;
    FS.DateSeparator := '/';
    FS.ShortDateFormat := 'DD/MM/YYYY';
    Result := StrToDateTime(FieldValue.AsString, FS);
  except
    on E: Exception do
      raise Exception.CreateFmt('Campo %s não é uma data válida: %s, valor: %s',
        [FieldName, E.Message, FieldValue.AsString]);
  end;
end;

function GetJSONDateTimeCI(JsonObj: TJSONObject; const FieldName: String; const Default: TDateTime): TDateTime;
var
  FieldValue: TJSONData;
begin
  FieldValue := FindJSONFieldCaseInsensitive(JsonObj, FieldName);

  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if Default <> 0 then
      Exit(Default)
    else
      raise Exception.CreateFmt('Campo data %s não encontrado no JSON.', [FieldName]);
  end;

  try
    Result := ISO8601ToDate(FieldValue.AsString, False);
  except
    on E: Exception do
      raise Exception.CreateFmt('Campo %s não é uma data válida: %s', [FieldName, E.Message]);
  end;
end;

function GetJSONDateTimeCI(JsonObj: TJSONObject; const FieldName: String): TDateTime;
begin
  Result := GetJSONDateTimeCI(JsonObj, FieldName, 0);
end;


function FindJSONFieldCaseInsensitive(AObj: TJSONObject; const AName: String): TJSONData;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AObj.Count - 1 do
  begin
    if SameText(AObj.Names[I], AName) then // ignora maiúsc/minúsc
      Exit(AObj.Items[I]);
  end;
end;

function GetJSONIntegerCI(JsonObj: TJSONObject; const FieldName: String; const Default: Integer; UseDefault: Boolean): Integer;
var
  FieldValue: TJSONData;
begin
  FieldValue := FindJSONFieldCaseInsensitive(JsonObj, FieldName);

  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Exit(Default)
    else
      raise Exception.CreateFmt('Campo inteiro %s não encontrado no JSON.', [FieldName]);
  end;

  if FieldValue.JSONType = jtNumber then
    Result := FieldValue.AsInteger
  else
    raise Exception.CreateFmt('Campo %s não é numérico.', [FieldName]);
end;

function GetJSONStringCI(JsonObj: TJSONObject; const FieldName: String;
  UseDefault: Boolean; const Default: String; const APrefixDefault: String): String;
var
  FieldValue: TJSONData;
begin
  FieldValue := FindJSONFieldCaseInsensitive(JsonObj, FieldName);

  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Exit(Default)
    else
      raise Exception.CreateFmt(APrefixDefault + 'Campo string %s não encontrado no JSON.', [FieldName]);
  end;

  if FieldValue.JSONType in [jtString, jtNumber] then
  begin
    if FieldValue.AsString <> '' then
      Result := FieldValue.AsString
    else
      Result := Default;
  end
  else
    raise Exception.CreateFmt(APrefixDefault + 'Campo %s não é uma string válida.', [FieldName]);
end;



function GetJSONInteger(JsonObj: TJSONObject; const FieldName: String; const Default: Integer = -1; UseDefault: Boolean = False): Integer;
var
  FieldValue: TJSONData;
begin
  FieldValue := JsonObj.Find(FieldName);
  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Result := Default
    else
      raise Exception.CreateFmt('Campo inteiro %s não encontrado no JSON.', [FieldName]);
  end
  else
  begin
    if (FieldValue.JSONType = jtNumber)  then
      Result := FieldValue.AsInteger
    else
      raise Exception.CreateFmt('Campo %s não é numérico.', [FieldName]);
  end;
end;

function GetJSONNumber(JsonObj: TJSONObject; const FieldName: String;
  UseDefault: Boolean; const Default: Double): Double;
var
  FieldValue: TJSONData;
begin
  FieldValue := JsonObj.Find(FieldName);
  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Result := Default
    else
      raise Exception.CreateFmt('Campo numérico %s não encontrado no JSON.', [FieldName]);
  end
  else
  begin
    if FieldValue.JSONType = jtNumber then
      Result := FieldValue.AsFloat
    else
      raise Exception.CreateFmt('Campo %s não é numérico.', [FieldName]);
  end;

end;

function GetJSONString(JsonObj: TJSONObject; const FieldName: String;
  UseDefault: Boolean; const Default: String; const APrefixDefault: String): String;
var
  FieldValue: TJSONData;
begin
  FieldValue := JsonObj.Find(FieldName);
  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Result := Default
    else
      raise Exception.CreateFmt(APrefixDefault + 'Campo string %s não encontrado no JSON.', [FieldName]);
  end
  else
  begin
    if FieldValue.JSONType in [jtString, jtNumber] then
    begin
      if FieldValue.AsString <> '' then
        Result := FieldValue.AsString
      else
        Result := Default
    end
    else
      raise Exception.CreateFmt(APrefixDefault + 'Campo %s não é uma string válida.', [FieldName]);
  end;
end;

function GetJSONDate(JsonObj: TJSONObject; const FieldName: String;
  const Default: TDateTime; UseDefault: Boolean): TDateTime;
var
  FieldValue: TJSONData;
  FS : TFormatSettings;
begin
  FieldValue := JsonObj.Find(FieldName);
  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if UseDefault then
      Result := Default
    else
      raise Exception.CreateFmt('Campo data %s não encontrado no JSON.', [FieldName]);
  end
  else
  begin
    try
      FS := DefaultFormatSettings;
      FS.DateSeparator := '/';
      FS.ShortDateFormat:='DD/MM/YYYY';
      Result := StrToDateTime(FieldValue.AsString, FS);
    except
      on E: Exception do
        raise Exception.CreateFmt('Campo %s não é uma data válida: %s, valor: %s', [FieldName, E.Message, FieldValue.AsString]);
    end;
  end;
end;

function GetJSONDateTime(JsonObj: TJSONObject; const FieldName: String; const Default: TDateTime): TDateTime;
var
  FieldValue: TJSONData;
begin
  FieldValue := JsonObj.Find(FieldName);

  FieldValue := JsonObj.Find(FieldName);
  if ((FieldValue = nil) or (FieldValue.JSONType = jtNull)) then
  begin
    if Default <> 0 then
      Result := Default
    else
      raise Exception.CreateFmt('Campo data %s não encontrado no JSON.', [FieldName]);
  end
  else
  begin
    try
      Result := ISO8601ToDate(FieldValue.AsString, false);
    except
      on E: Exception do
        raise Exception.CreateFmt('Campo %s não é uma data válida: %s', [FieldName, E.Message]);
    end
  end
end;

function GetJSONDateTime(JsonObj: TJSONObject; const FieldName: String
  ): TDateTime;
var
  FS : TFormatSettings;
begin
  FS.DateSeparator := '-';
  FS.ShortDateFormat := 'YYYY-MM-DD';
  FS.TimeSeparator := ':';
  FS.ShortTimeFormat := 'hh:nn:ss';
  GetJSONDateTime(JsonObj, FieldName, 0);
end;

end.

