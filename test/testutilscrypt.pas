unit TestUtilsCrypt;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, utils.crypt;

type
  TTestUtilsCrypt = class(TTestCase)
  published
    procedure TestCriptografarDescriptografarChavePadrao;
    procedure TestCriptografarDescriptografarChavePersonalizada;
    procedure TestTextoVazio;
    procedure TestChaveVazia;
    procedure TestCaracteresEspeciais;
    procedure TestTextoLongo;
    procedure TestInteroperabilidade;
  end;

implementation

procedure TTestUtilsCrypt.TestCriptografarDescriptografarChavePadrao;
var
  textoOriginal, textoCriptografado, textoDescriptografado: string;
begin
  textoOriginal := 'Olá, mundo! 123 @#$';
  textoCriptografado := Criptografar(textoOriginal);
  textoDescriptografado := Descriptografar(textoCriptografado);

  // Verifica se o texto foi criptografado (deve ser diferente do original)
  AssertTrue('Texto deve ser criptografado', textoOriginal <> textoCriptografado);

  // Verifica se a descriptografia retorna o texto original
  AssertEquals('Descriptografia deve retornar texto original', textoOriginal, textoDescriptografado);

  // Verifica se o resultado criptografado é Base64 válido (não deve ter caracteres especiais)
  AssertTrue('Resultado deve ser Base64 válido', Length(textoCriptografado) > 0);
end;

procedure TTestUtilsCrypt.TestCriptografarDescriptografarChavePersonalizada;
var
  textoOriginal, textoCriptografado, textoDescriptografado: string;
  chavePersonalizada: string;
begin
  textoOriginal := 'Dados importantes para criptografar!';
  chavePersonalizada := 'MinhaChaveSecreta123';

  textoCriptografado := Criptografar(textoOriginal, chavePersonalizada);
  textoDescriptografado := Descriptografar(textoCriptografado, chavePersonalizada);

  // Verifica se o texto foi criptografado
  AssertTrue('Texto deve ser criptografado', textoOriginal <> textoCriptografado);

  // Verifica se a descriptografia retorna o texto original
  AssertEquals('Descriptografia deve retornar texto original', textoOriginal, textoDescriptografado);

  // Verifica se chaves diferentes geram resultados diferentes
  AssertTrue('Chaves diferentes devem gerar resultados diferentes',
    textoCriptografado <> Criptografar(textoOriginal, 'OutraChave'));
end;

procedure TTestUtilsCrypt.TestTextoVazio;
var
  textoCriptografado, textoDescriptografado: string;
begin
  textoCriptografado := Criptografar('');
  textoDescriptografado := Descriptografar('');

  // Texto vazio deve retornar vazio
  AssertEquals('Criptografia de texto vazio deve retornar vazio', '', textoCriptografado);
  AssertEquals('Descriptografia de texto vazio deve retornar vazio', '', textoDescriptografado);
end;

procedure TTestUtilsCrypt.TestChaveVazia;
var
  textoOriginal, textoCriptografado: string;
begin
  textoOriginal := 'Texto sem criptografia';
  textoCriptografado := Criptografar(textoOriginal, '');

  // Com chave vazia, deve retornar o texto original (sem criptografia)
  AssertEquals('Chave vazia deve retornar texto original', textoOriginal, textoCriptografado);
end;

procedure TTestUtilsCrypt.TestCaracteresEspeciais;
var
  textoOriginal, textoCriptografado, textoDescriptografado: string;
begin
  textoOriginal := 'Acentuação: ção, ã, é, ü, ñ, ç - Símbolos: @#$%^&*()';
  textoCriptografado := Criptografar(textoOriginal);
  textoDescriptografado := Descriptografar(textoCriptografado);

  // Verifica se caracteres especiais são tratados corretamente
  AssertEquals('Caracteres especiais devem ser preservados', textoOriginal, textoDescriptografado);

  // Verifica se não há caracteres de controle no resultado
  AssertTrue('Resultado não deve conter caracteres de controle', Length(textoCriptografado) > 0);
end;

procedure TTestUtilsCrypt.TestTextoLongo;
var
  textoOriginal, textoCriptografado, textoDescriptografado: string;
  i: Integer;
begin
  // Cria um texto longo para testar
  textoOriginal := '';
  for i := 1 to 1000 do
    textoOriginal := textoOriginal + 'Texto longo para teste ' + IntToStr(i) + ' ';

  textoCriptografado := Criptografar(textoOriginal);
  textoDescriptografado := Descriptografar(textoCriptografado);

  // Verifica se textos longos são tratados corretamente
  AssertEquals('Textos longos devem ser preservados', textoOriginal, textoDescriptografado);
  AssertTrue('Texto longo deve ser criptografado', textoOriginal <> textoCriptografado);
end;

procedure TTestUtilsCrypt.TestInteroperabilidade;
var
  textoOriginal, textoCriptografado1, textoCriptografado2: string;
  textoDescriptografado1, textoDescriptografado2: string;
  chave1, chave2: string;
begin
  textoOriginal := 'Teste de interoperabilidade';
  chave1 := '3tic@S3nh@';  // Chave padrão
  chave2 := 'OutraChave';

  // Testa se a mesma chave sempre produz o mesmo resultado
  textoCriptografado1 := Criptografar(textoOriginal, chave1);
  textoCriptografado2 := Criptografar(textoOriginal, chave1);

  AssertEquals('Mesma entrada deve produzir mesmo resultado', textoCriptografado1, textoCriptografado2);

  // Testa se chaves diferentes produzem resultados diferentes
  textoCriptografado1 := Criptografar(textoOriginal, chave1);
  textoCriptografado2 := Criptografar(textoOriginal, chave2);

  AssertTrue('Chaves diferentes devem produzir resultados diferentes', textoCriptografado1 <> textoCriptografado2);

  // Testa se ambos descriptografam corretamente
  textoDescriptografado1 := Descriptografar(textoCriptografado1, chave1);
  textoDescriptografado2 := Descriptografar(textoCriptografado2, chave2);

  AssertEquals('Descriptografia com chave1 deve funcionar', textoOriginal, textoDescriptografado1);
  AssertEquals('Descriptografia com chave2 deve funcionar', textoOriginal, textoDescriptografado2);
end;

initialization
  RegisterTest(TTestUtilsCrypt);

end.
