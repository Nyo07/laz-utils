unit UtilsCrypt;

interface

uses
  Classes, SysUtils;

const
  CHAVE_DEFAULT = '3tic@S3nh@';

function Criptografar(const Texto: string; Chave: string = CHAVE_DEFAULT): string;
function Descriptografar(const TextoCriptografado: string; Chave: string = CHAVE_DEFAULT): string;

implementation

// Função para codificar em Base64 (implementação simples para Delphi 7)
function EncodeBase64Simple(const Input: string): string;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  i, j: Integer;
  Temp: array[0..2] of Byte;
  Output: string;
begin
  Result := '';
  i := 1;
  while i <= Length(Input) do
  begin
    // Preenche o array temporário
    FillChar(Temp, SizeOf(Temp), 0);
    for j := 0 to 2 do
    begin
      if i + j <= Length(Input) then
        Temp[j] := Ord(Input[i + j]);
    end;

    // Converte para Base64
    Output := Base64Chars[((Temp[0] and $FC) shr 2) + 1] +
              Base64Chars[(((Temp[0] and $03) shl 4) or ((Temp[1] and $F0) shr 4)) + 1] +
              Base64Chars[(((Temp[1] and $0F) shl 2) or ((Temp[2] and $C0) shr 6)) + 1] +
              Base64Chars[(Temp[2] and $3F) + 1];

    // Adiciona padding se necessário
    if i + 1 > Length(Input) then Output[3] := '=';
    if i + 2 > Length(Input) then Output[4] := '=';

    Result := Result + Output;
    Inc(i, 3);
  end;
end;

// Função para decodificar Base64 (implementação simples para Delphi 7)
function DecodeBase64Simple(const Input: string): string;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  i, j, PaddingCount: Integer;
  Temp: array[0..3] of Integer;
  Output: array[0..2] of Byte;
  CleanInput: string;
begin
  Result := '';

  // Remove caracteres de quebra de linha e espaços
  CleanInput := StringReplace(Input, #13#10, '', [rfReplaceAll]);
  CleanInput := StringReplace(CleanInput, ' ', '', [rfReplaceAll]);

  // Conta o padding
  PaddingCount := 0;
  if (Length(CleanInput) > 0) and (CleanInput[Length(CleanInput)] = '=') then Inc(PaddingCount);
  if (Length(CleanInput) > 1) and (CleanInput[Length(CleanInput)-1] = '=') then Inc(PaddingCount);

  i := 1;
  while i <= Length(CleanInput) do
  begin
    // Converte 4 caracteres Base64 para índices
    for j := 0 to 3 do
    begin
      if i + j <= Length(CleanInput) then
      begin
        if CleanInput[i + j] = '=' then
          Temp[j] := 0
        else
          Temp[j] := Pos(CleanInput[i + j], Base64Chars) - 1;
      end
      else
        Temp[j] := 0;
    end;

    // Decodifica
    Output[0] := (Temp[0] shl 2) or (Temp[1] shr 4);
    Output[1] := (Temp[1] shl 4) or (Temp[2] shr 2);
    Output[2] := (Temp[2] shl 6) or Temp[3];

    // Adiciona ao resultado
    Result := Result + Chr(Output[0]);
    if (i + 4 < Length(CleanInput)) or (PaddingCount < 2) then
      Result := Result + Chr(Output[1]);
    if (i + 4 < Length(CleanInput)) or (PaddingCount < 1) then
      Result := Result + Chr(Output[2]);

    Inc(i, 4);
  end;
end;

function GerarChaveExtendida(const Chave: string; TamanhoTexto: Integer): string;
var
  i: Integer;
begin
  SetLength(Result, TamanhoTexto);
  for i := 1 to TamanhoTexto do
  begin
    Result[i] := Chave[((i - 1) mod Length(Chave)) + 1];
  end;
end;

function Criptografar(const Texto: string; Chave: string): string;
var
  i: Integer;
  ChaveExtendida: string;
  ValorCriptografado: Byte;
  TextoCriptografado: string;
begin
  // Verifica se a chave está vazia
  if Trim(Chave) = '' then
  begin
    Result := Texto;
    Exit;
  end;

  // Verifica se o texto está vazio
  if Texto = '' then
  begin
    Result := '';
    Exit;
  end;

  // Gera uma chave do mesmo tamanho do texto
  ChaveExtendida := GerarChaveExtendida(Chave, Length(Texto));

  // Inicializa o resultado
  SetLength(TextoCriptografado, Length(Texto));

  // Criptografa cada caractere
  for i := 1 to Length(Texto) do
  begin
    // Aplica XOR com a chave e adiciona um deslocamento adicional
    ValorCriptografado := Ord(Texto[i]) xor Ord(ChaveExtendida[i]) xor (i mod 256);
    TextoCriptografado[i] := Chr(ValorCriptografado);
  end;

  // Converte para Base64 para evitar caracteres especiais
  Result := EncodeBase64Simple(TextoCriptografado);
end;

function Descriptografar(const TextoCriptografado: string; Chave: string): string;
var
  i: Integer;
  ChaveExtendida: string;
  ValorDescriptografado: Byte;
  TextoDecodificado: string;
begin
  // Verifica se a chave está vazia
  if Trim(Chave) = '' then
  begin
    Result := TextoCriptografado;
    Exit;
  end;

  // Verifica se o texto está vazio
  if TextoCriptografado = '' then
  begin
    Result := '';
    Exit;
  end;

  try
    // Decodifica de Base64
    TextoDecodificado := DecodeBase64Simple(TextoCriptografado);
  except
    Result := ''; // Retorna vazio se não conseguir decodificar
    Exit;
  end;

  // Gera uma chave do mesmo tamanho do texto
  ChaveExtendida := GerarChaveExtendida(Chave, Length(TextoDecodificado));

  // Inicializa o resultado
  SetLength(Result, Length(TextoDecodificado));

  // Descriptografa cada caractere
  for i := 1 to Length(TextoDecodificado) do
  begin
    // Reverte o processo de criptografia
    ValorDescriptografado := Ord(TextoDecodificado[i]) xor 
      Ord(ChaveExtendida[i]) xor (i mod 256);
    Result[i] := Chr(ValorDescriptografado);
  end;
end;

end.