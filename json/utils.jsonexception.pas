unit utils.jsonException;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  EJsonException = class(Exception)
  private
    FStatus: Integer;
  public
    constructor Create(const Msg: string; AStatus: Integer = 500); overload;
    constructor CreateFmt(const Msg: string; const Args: array of const; AStatus: Integer = 500); overload;
    property Status: Integer read FStatus;
  end;

implementation

constructor EJsonException.Create(const Msg: string; AStatus: Integer = 500);
begin
  FStatus := AStatus;
  inherited Create(Format('{"status": %d, "error": "%s"}', [FStatus, Msg]));
end;

constructor EJsonException.CreateFmt(const Msg: string; const Args: array of const; AStatus: Integer = 500);
begin
  FStatus := AStatus;
  inherited Create(Format('{"status": %d, "error": "%s"}', [FStatus, Format(Msg, Args)]));
end;

end.
