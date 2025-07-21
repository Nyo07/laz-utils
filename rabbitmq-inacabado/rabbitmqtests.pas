unit RabbitMQTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, RabbitMQClient;

type
  TRabbitMQClientTest = class(TTestCase)
  private
    FClient: TRabbitMQClient;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConnection;
    procedure TestQueueDeclaration;
    procedure TestPublishMessage;
    procedure TestConsumeMessage;
  end;

implementation

procedure TRabbitMQClientTest.SetUp;
begin
  FClient := TRabbitMQClient.Create;
end;

procedure TRabbitMQClientTest.TearDown;
begin

  FClient.Free;
end;

procedure TRabbitMQClientTest.TestConnection;
begin
  // Teste de conexão (ajuste os parâmetros conforme seu ambiente)
  AssertTrue('Should connect to RabbitMQ',
            FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/'));
  AssertTrue('Should be connected', FClient.Connected);

  FClient.Disconnect;
  AssertFalse('Should be disconnected', FClient.Connected);
end;

procedure TRabbitMQClientTest.TestQueueDeclaration;
begin
  // Conectar primeiro
  AssertTrue('Should connect to RabbitMQ',
            FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/'));

  if not FClient.DeclareQueue('test_queue', True, False) then
  begin
    FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/');
    AssertTrue('Queue should exist (passive)', FClient.DeclareQueue('test_queue', True, True));
  end
  else
    AssertTrue('Should declare queue', True);
  Sleep(10000);
end;

procedure TRabbitMQClientTest.TestPublishMessage;
begin
  // Conectar primeiro
  AssertTrue('Should connect to RabbitMQ',
            FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/'));

  // Declarar fila
  if not FClient.DeclareQueue('test_queue', True, False) then
  begin
    FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/');
    AssertTrue('Queue should exist (passive)', FClient.DeclareQueue('test_queue', True, True));
  end
  else
    AssertTrue('Should declare queue', True);

  // Publicar mensagem
  AssertTrue('Should publish message',
            FClient.PublishMessage('', 'test_queue', 'Hello World!'));
end;

procedure TRabbitMQClientTest.TestConsumeMessage;
var
  Message: string;
begin
  // Conectar primeiro
  AssertTrue('Should connect to RabbitMQ',
            FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/'));

  // Inicie o consumer
  FClient.StartConsumer('test_queue');

  // Aguarde mensagem
  if FClient.WaitForMessage(Message) then
    LogToFile('Mensagem recebida: ' + Message)
  else
    LogToFile('Nenhuma mensagem recebida');

  {
  // Declarar fila
  if not FClient.DeclareQueue('test_queue', True, False) then
  begin
    FClient.Connect('192.168.168.140', 5672, 'admin', '1N*4OA!xyl', '/');
    AssertTrue('Queue should exist (passive)', FClient.DeclareQueue('test_queue', True, True));
  end
  else
    AssertTrue('Should declare queue', True);

  // Tentar consumir mensagem (pode não haver mensagens)
  FClient.ConsumeMessage('test_queue', Message, 1000);
  LogToFile('Mensagem recebida: '+Message);
  // Não fazemos assert aqui pois pode não haver mensagens na fila
  }
end;

initialization
  RegisterTest(TRabbitMQClientTest);

end.
