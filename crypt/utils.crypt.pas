unit utils.crypt;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

const
  chaveDefault = '3tic@S3nh@';

function Criptografar(const Texto: string; Chave: string = chaveDefault): string;
function Descriptografar(const TextoCriptografado: string;
  Chave: string = chaveDefault): string;


implementation

function GerarChaveExtendida(const Chave: string; TamanhoTexto: integer): string;
var
  i: integer;
begin
  SetLength(Result, TamanhoTexto);
  for i := 1 to TamanhoTexto do
  begin
    Result[i] := Chave[((i - 1) mod Length(Chave)) + 1];
  end;
end;

function Criptografar(const Texto: string; Chave: string): string;
var
  i: integer;
  ChaveExtendida: string;
  ValorCriptografado: byte;
begin
  // Verifica se a chave está vazia
  if Trim(Chave) = '' then
  begin
    Result := Texto;
    Exit;
  end;

  // Gera uma chave do mesmo tamanho do texto
  ChaveExtendida := GerarChaveExtendida(Chave, Length(Texto));

  // Inicializa o resultado
  SetLength(Result, Length(Texto));

  // Criptografa cada caractere
  for i := 1 to Length(Texto) do
  begin
    // Aplica XOR com a chave e adiciona um deslocamento adicional
    ValorCriptografado := Ord(Texto[i]) xor Ord(ChaveExtendida[i]) xor (i mod 256);
    Result[i] := Chr(ValorCriptografado);
  end;
end;

function Descriptografar(const TextoCriptografado: string; Chave: string): string;
var
  i: integer;
  ChaveExtendida: string;
  ValorDescriptografado: byte;
begin
  // Verifica se a chave está vazia
  if Trim(Chave) = '' then
  begin
    Result := TextoCriptografado;
    Exit;
  end;

  // Gera uma chave do mesmo tamanho do texto
  ChaveExtendida := GerarChaveExtendida(Chave, Length(TextoCriptografado));

  // Inicializa o resultado
  SetLength(Result, Length(TextoCriptografado));

  // Descriptografa cada caractere
  for i := 1 to Length(TextoCriptografado) do
  begin
    // Reverte o processo de criptografia
    ValorDescriptografado := Ord(TextoCriptografado[i]) xor
      Ord(ChaveExtendida[i]) xor (i mod 256);
    Result[i] := Chr(ValorDescriptografado);
  end;
end;

end.
