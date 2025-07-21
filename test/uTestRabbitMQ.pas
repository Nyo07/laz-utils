unit uTestRabbitMQ;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DateUtils,
  uRabbitMQClient, uRabbitMQMonitor,
  fpcunit, testregistry;

type
  TRabbitMQFPCUnitTest = class(TTestCase)
  private
    FClient: TRabbitMQClient;
    FMonitor: TRabbitMQMonitor;
    FTestQueue: string;
    FMessagesReceived: Integer;
    FLastMessage: string;
    FLastQueue: string;
    FMonitorError: string;

    procedure OnMessageReceived(const AQueue: string; AMessageCount: Integer; const AMessage: string);
    procedure OnMonitorError(const AQueue: string; const AError: string);
    function WaitForMessage(ATimeoutMs: Integer = 3000): Boolean;
    function WaitForMonitorStart(ATimeoutMs: Integer = 1000): Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConnection;
    procedure TestCreateQueue;
    procedure TestQueueInfo;
    procedure TestQueueMessageCount;
    procedure TestQueueExists;
    procedure TestDeleteQueue;
    procedure TestPublishMessage;
    procedure TestConsumeMessage;
    procedure TestPublishJSONMessage;
    procedure TestConsumeJSONMessage;
    procedure TestMonitorStart;
    procedure TestMonitorStop;
    procedure TestMonitorReceiveMessage;
    procedure TestErrorHandlingInvalidQueue;
    procedure TestErrorHandlingInvalidJSON;
    procedure TestVirtualHostEncoding;
  end;

implementation

{ TRabbitMQFPCUnitTest }

procedure TRabbitMQFPCUnitTest.SetUp;
begin
  inherited SetUp;

  // Gera nome único para fila de teste
  FTestQueue := 'test_queue_' + FormatDateTime('yyyymmdd_hhnnss_zzz', Now);

  // Inicializa cliente
  FClient := TRabbitMQClient.Create('192.168.168.140', 15672, 'admin', '1N*4OA!xyl', '/');
  AssertNotNull('Cliente deve ser criado', FClient);

  // Inicializa monitor
  FMonitor := TRabbitMQMonitor.Create(FClient);
  AssertNotNull('Monitor deve ser criado', FMonitor);

  FMonitor.OnMessage := @OnMessageReceived;
  FMonitor.OnError := @OnMonitorError;
  FMonitor.Interval := 500; // 500ms para testes mais rápidos

  // Reset contadores
  FMessagesReceived := 0;
  FLastMessage := '';
  FLastQueue := '';
  FMonitorError := '';
end;

procedure TRabbitMQFPCUnitTest.TearDown;
begin
  // Para monitor se estiver ativo
  if Assigned(FMonitor) and FMonitor.Active then
    FMonitor.Stop;

  // Remove fila de teste
  if Assigned(FClient) then
  begin
    try
      FClient.DeleteQueue(FTestQueue);
    except
      // Ignora erros na limpeza
    end;
  end;

  // Libera recursos
  FreeAndNil(FMonitor);
  FreeAndNil(FClient);

  inherited TearDown;
end;

procedure TRabbitMQFPCUnitTest.OnMessageReceived(const AQueue: string;
  AMessageCount: Integer; const AMessage: string);
begin
  Inc(FMessagesReceived);
  FLastMessage := AMessage;
  FLastQueue := AQueue;
end;

procedure TRabbitMQFPCUnitTest.OnMonitorError(const AQueue: string; const AError: string);
begin
  FMonitorError := Format('Fila "%s": %s', [AQueue, AError]);
end;

function TRabbitMQFPCUnitTest.WaitForMessage(ATimeoutMs: Integer): Boolean;
var
  StartTime: TDateTime;
  InitialCount: Integer;
begin
  Result := False;
  StartTime := Now;
  InitialCount := FMessagesReceived;

  while MilliSecondsBetween(Now, StartTime) < ATimeoutMs do
  begin
    Sleep(50);

    if FMessagesReceived > InitialCount then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TRabbitMQFPCUnitTest.WaitForMonitorStart(ATimeoutMs: Integer): Boolean;
var
  StartTime: TDateTime;
begin
  Result := False;
  StartTime := Now;

  while MilliSecondsBetween(Now, StartTime) < ATimeoutMs do
  begin
    Sleep(50);

    if FMonitor.Active then
    begin
      Result := True;
      Break;
    end;
  end;
end;

// ===== TESTES DE CONEXÃO =====

procedure TRabbitMQFPCUnitTest.TestConnection;
var
  QueueInfo: TJSONObject;
begin
  // Testa se consegue fazer uma requisição sem erro de conexão
  QueueInfo := FClient.GetQueueInfo('fila_inexistente_teste_123');

  // Deve retornar nil para fila inexistente, mas sem erro de conexão
  AssertNull('Fila inexistente deve retornar nil', QueueInfo);

  // Se chegou até aqui, a conexão está OK
  AssertTrue('Conexão estabelecida com sucesso', True);
end;

// ===== TESTES DE OPERAÇÕES DE FILA =====

procedure TRabbitMQFPCUnitTest.TestCreateQueue;
begin
  AssertTrue('Deve criar fila com sucesso', FClient.CreateQueue(FTestQueue, True));

  // Verifica se a fila foi realmente criada
  AssertTrue('Fila deve existir após criação', FClient.QueueExists(FTestQueue));
end;

procedure TRabbitMQFPCUnitTest.TestQueueInfo;
var
  QueueInfo: TJSONObject;
begin
  // Cria fila primeiro
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));

  // Obtém informações
  QueueInfo := FClient.GetQueueInfo(FTestQueue);
  try
    AssertNotNull('Deve retornar informações da fila', QueueInfo);
    AssertTrue('Deve ter campo name', QueueInfo.IndexOfName('name') >= 0);
  finally
    if Assigned(QueueInfo) then
      QueueInfo.Free;
  end;
end;

procedure TRabbitMQFPCUnitTest.TestQueueMessageCount;
var
  MessageCount: Integer;
begin
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
  AssertTrue('Fila deve existir após criação', FClient.WaitForQueueExists(FClient, FTestQueue, 3000));
  MessageCount := FClient.GetQueueMessageCount(FTestQueue);
  AssertEquals('Fila nova deve ter 0 mensagens', 0, MessageCount);
end;

procedure TRabbitMQFPCUnitTest.TestQueueExists;
begin
  // Fila não deve existir inicialmente
  AssertFalse('Fila não deve existir inicialmente', FClient.QueueExists(FTestQueue));

  // Cria fila
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));

  // Agora deve existir
  AssertTrue('Fila deve existir após criação', FClient.QueueExists(FTestQueue));
end;

procedure TRabbitMQFPCUnitTest.TestDeleteQueue;
begin
  // Cria fila
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
  AssertTrue('Fila deve existir', FClient.QueueExists(FTestQueue));

  // Deleta fila
  AssertTrue('Deve deletar fila', FClient.DeleteQueue(FTestQueue));

  // Não deve mais existir
  AssertFalse('Fila não deve existir após deleção', FClient.QueueExists(FTestQueue));
end;

// ===== TESTES DE MENSAGENS =====

procedure TRabbitMQFPCUnitTest.TestPublishMessage;
var
  TestMessage: string;
begin
  TestMessage := 'Mensagem de teste: ' + FormatDateTime('hh:nn:ss.zzz', Now);

  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
  AssertTrue('Fila deve existir após criação', FClient.WaitForQueueExists(FClient, FTestQueue, 3000));
  AssertTrue('Deve enviar mensagem', FClient.PublishMessage(FTestQueue, TestMessage));
  AssertTrue('Mensagem deve aparecer na fila', FClient.WaitForMessageCount(FClient, FTestQueue, 1, 3000));
end;

procedure TRabbitMQFPCUnitTest.TestConsumeMessage;
var
  TestMessage, ReceivedMessage: string;
  Success: Boolean;
begin
  TestMessage := 'Mensagem para consumo: ' + FormatDateTime('hh:nn:ss.zzz', Now);

  // Cria fila e envia mensagem
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
  AssertTrue('Deve enviar mensagem', FClient.PublishMessage(FTestQueue, TestMessage));

  // Consome mensagem
  Success := FClient.ConsumeMessage(FTestQueue, ReceivedMessage);
  AssertTrue('Deve consumir mensagem', Success);
  AssertEquals('Mensagem deve ser igual', TestMessage, ReceivedMessage);

  // Tenta consumir de fila vazia
  Success := FClient.ConsumeMessage(FTestQueue, ReceivedMessage);
  AssertFalse('Fila vazia não deve retornar mensagem', Success);
end;

procedure TRabbitMQFPCUnitTest.TestPublishJSONMessage;
var
  JSONData: TJSONObject;
  MessageCount: Integer;
begin
  // Cria JSON de teste
  JSONData := TJSONObject.Create;
  try
    JSONData.Add('teste', True);
    JSONData.Add('timestamp', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    JSONData.Add('numero', 42);
    JSONData.Add('texto', 'Teste de JSON');

    // Cria fila
    AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));

    // Envia JSON
    AssertTrue('Deve enviar JSON', FClient.PublishJSONMessage(FTestQueue, JSONData));

    // Verifica se foi enfileirada
    Sleep(100);
    MessageCount := FClient.GetQueueMessageCount(FTestQueue);
    AssertTrue('Deve ter mensagem JSON na fila', MessageCount > 0);
  finally
    JSONData.Free;
  end;
end;

procedure TRabbitMQFPCUnitTest.TestConsumeJSONMessage;
var
  JSONData, ReceivedJSON: TJSONObject;
  Success: Boolean;
begin
  // Cria JSON de teste
  JSONData := TJSONObject.Create;
  try
    JSONData.Add('teste', True);
    JSONData.Add('numero', 42);
    JSONData.Add('texto', 'Teste de JSON');

    // Cria fila e envia JSON
    AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
    AssertTrue('Deve enviar JSON', FClient.PublishJSONMessage(FTestQueue, JSONData));

    // Consome JSON
    Success := FClient.ConsumeJSONMessage(FTestQueue, ReceivedJSON);
    AssertTrue('Deve consumir JSON', Success);
    AssertNotNull('JSON recebido não deve ser nil', ReceivedJSON);

    try
      // Valida campos
      AssertEquals('Campo teste deve ser true', True, ReceivedJSON.Get('teste', False));
      AssertEquals('Campo numero deve ser 42', 42, ReceivedJSON.Get('numero', 0));
      AssertEquals('Campo texto deve conferir', 'Teste de JSON', ReceivedJSON.Get('texto', ''));
    finally
      ReceivedJSON.Free;
    end;
  finally
    JSONData.Free;
  end;
end;

// ===== TESTES DE MONITORAMENTO =====

procedure TRabbitMQFPCUnitTest.TestMonitorStart;
begin
  // Cria fila
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));

  // Adiciona fila ao monitor
  FMonitor.AddQueue(FTestQueue);

  // Inicia monitor
  FMonitor.Start;

  // Aguarda ativação
  AssertTrue('Monitor deve ativar', WaitForMonitorStart(2000));
  AssertTrue('Monitor deve estar ativo', FMonitor.Active);
end;

procedure TRabbitMQFPCUnitTest.TestMonitorStop;
begin
  // Cria fila e inicia monitor
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
  FMonitor.AddQueue(FTestQueue);
  FMonitor.Start;
  AssertTrue('Monitor deve ativar', WaitForMonitorStart(2000));

  // Para monitor
  FMonitor.Stop;
  AssertFalse('Monitor deve estar inativo', FMonitor.Active);
end;

procedure TRabbitMQFPCUnitTest.TestMonitorReceiveMessage;
var
  TestMessage: string;
begin
  TestMessage := 'Teste de monitoramento: ' + FormatDateTime('hh:nn:ss.zzz', Now);

  // Cria fila e inicia monitor
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));
  FMonitor.AddQueue(FTestQueue);
  FMonitor.Start;
  AssertTrue('Monitor deve ativar', WaitForMonitorStart(2000));

  // Envia mensagem
  AssertTrue('Deve enviar mensagem', FClient.PublishMessage(FTestQueue, TestMessage));

  // Aguarda recebimento via monitor
  AssertTrue('Monitor deve receber mensagem', WaitForMessage(5000));
  AssertEquals('Fila deve ser a correta', FTestQueue, FLastQueue);
  AssertEquals('Mensagem deve ser a correta', TestMessage, FLastMessage);
  AssertEquals('Deve ter recebido 1 mensagem', 1, FMessagesReceived);
end;

// ===== TESTES DE TRATAMENTO DE ERROS =====

procedure TRabbitMQFPCUnitTest.TestErrorHandlingInvalidQueue;
var
  Message: string;
  Success: Boolean;
begin
  // Tenta consumir de fila inexistente
  Success := FClient.ConsumeMessage('fila_inexistente_12345', Message);

  // Não deve dar exceção, apenas retornar False
  AssertFalse('Fila inexistente deve retornar False', Success);
  AssertEquals('Mensagem deve estar vazia', '', Message);
end;

procedure TRabbitMQFPCUnitTest.TestErrorHandlingInvalidJSON;
var
  InvalidJSON: string;
begin
  InvalidJSON := '{"json": "invalido"'; // JSON malformado

  // Cria fila
  AssertTrue('Deve criar fila', FClient.CreateQueue(FTestQueue, True));

  // Deve conseguir enviar string inválida (não valida JSON no envio)
  AssertTrue('Deve enviar string inválida', FClient.PublishMessage(FTestQueue, InvalidJSON));
end;

// ===== TESTES ESPECÍFICOS =====

procedure TRabbitMQFPCUnitTest.TestVirtualHostEncoding;
var
  Client: TRabbitMQClient;
  TestQueue: string;
begin
  TestQueue := 'test_vhost_' + FormatDateTime('hhnnss', Now);

  // Testa com virtual host padrão "/"
  Client := TRabbitMQClient.Create('192.168.168.140', 15672, 'admin', '1N*4OA!xyl', '/');
  try
    AssertTrue('Deve criar fila no vhost padrão', Client.CreateQueue(TestQueue, True));
    AssertTrue('Deve deletar fila do vhost padrão', Client.DeleteQueue(TestQueue));
  finally
    Client.Free;
  end;
end;

// ===== REGISTRO DA SUITE =====

initialization
  RegisterTest(TRabbitMQFPCUnitTest);

end.
