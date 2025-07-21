unit RabbitMQClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  // Estruturas básicas do RabbitMQ
  Pamqp_connection_state_t = Pointer;
  Pamqp_socket_t = Pointer;
  amqp_channel_t = Word;
  amqp_boolean_t = Byte;

  amqp_bytes_t = record
    len: NativeUInt;
    bytes: Pointer;
  end;

  amqp_channel_close_t = record
    reply_code: Word;
    reply_text: amqp_bytes_t;
    class_id: Word;
    method_id: Word;
  end;

  Pamqp_channel_close_t = ^amqp_channel_close_t;

  amqp_method_t = record
    id: Word;
    decoded: Pointer;
  end;

  amqp_rpc_reply_t = record
    reply_type: Integer;
    reply: amqp_method_t;
    library_error: Integer;
  end;

  amqp_table_t = record
    num_entries: Integer;
    entries: Pointer;
  end;

  amqp_basic_properties_t = record
    _flags: Cardinal;
    content_type: amqp_bytes_t;
    content_encoding: amqp_bytes_t;
    headers: amqp_table_t;
    delivery_mode: Byte;
    priority: Byte;
    correlation_id: amqp_bytes_t;
    reply_to: amqp_bytes_t;
    expiration: amqp_bytes_t;
    message_id: amqp_bytes_t;
    timestamp: Int64;
    type_: amqp_bytes_t;
    user_id: amqp_bytes_t;
    app_id: amqp_bytes_t;
    cluster_id: amqp_bytes_t;
  end;

  amqp_envelope_t = record
    channel: Word;
    consumer_tag: amqp_bytes_t;
    delivery_tag: Int64;
    redelivered: Boolean;
    exchange: amqp_bytes_t;
    routing_key: amqp_bytes_t;
    properties: amqp_basic_properties_t;
    body: amqp_bytes_t;
  end;

  // Enum para tipos de resposta RPC
  amqp_rpc_reply_type_enum = (
    AMQP_RESPONSE_NONE = 0,
    AMQP_RESPONSE_NORMAL = 1,
    AMQP_RESPONSE_LIBRARY_EXCEPTION = 2,
    AMQP_RESPONSE_SERVER_EXCEPTION = 3
  );

  Pamqp_queue_declare_ok_t = Pointer;



  { TRabbitMQClient }

  TRabbitMQClient = class
  private
    FConnection: Pamqp_connection_state_t;
    FSocket: Pamqp_socket_t;
    FHost: string;
    FPort: Integer;
    FUsername: string;
    FPassword: string;
    FVHost: string;
    FConnected: Boolean;

    function StringToBytes(const AString: string): amqp_bytes_t;
    function BytesToString(const ABytes: amqp_bytes_t): string;

  public
    constructor Create;
    destructor Destroy; override;

    function StartConsumer(const AQueueName: string): Boolean;
    function WaitForMessage(out AMessage: string): Boolean;

    function Connect(const AHost: string; APort: Integer;
                    const AUsername, APassword, AVHost: string): Boolean;
    procedure Disconnect;

    function DeclareQueue(const AQueueName: string; ADurable: Boolean; APassive: Boolean = False): Boolean;
    function PublishMessage(const AExchange, ARoutingKey, AMessage: string): Boolean;
    function ConsumeMessage(const AQueueName: string; out AMessage: string;
      ATimeout: Integer): Boolean;

    property Connected: Boolean read FConnected;
    property Host: string read FHost;
    property Port: Integer read FPort;
  end;

  procedure LogToFile(const Msg: string);

const
  AMQP_SASL_METHOD_PLAIN = 0;
  AMQP_BASIC_CONTENT_TYPE_FLAG = $800;
  AMQP_BASIC_DELIVERY_MODE_FLAG = $20;

var
  amqp_empty_table: amqp_table_t; cvar; external 'librabbitmq.so';

// Funções da librabbitmq-c
function amqp_new_connection: Pamqp_connection_state_t; cdecl; external 'librabbitmq.so';
function amqp_tcp_socket_new(state: Pamqp_connection_state_t): Pamqp_socket_t; cdecl; external 'librabbitmq.so';
function amqp_socket_open(socket: Pamqp_socket_t; host: PChar; port: Integer): Integer; cdecl; external 'librabbitmq.so';

// Função corrigida para retornar amqp_rpc_reply_t
function amqp_login(state: Pamqp_connection_state_t; vhost: PChar;
                   channel_max, frame_max, heartbeat: Integer;
                   sasl_method: Integer; username, password: PChar): amqp_rpc_reply_t; cdecl; external 'librabbitmq.so';

procedure amqp_channel_open(state: Pamqp_connection_state_t; channel: Word); cdecl; external 'librabbitmq.so';
function amqp_get_rpc_reply(state: Pamqp_connection_state_t): amqp_rpc_reply_t; cdecl; external 'librabbitmq.so';

function amqp_queue_declare(
  state: Pamqp_connection_state_t;
  channel: amqp_channel_t;
  queue: amqp_bytes_t;
  passive: amqp_boolean_t;     // Era Byte, agora amqp_boolean_t
  durable: amqp_boolean_t;     // Era Byte, agora amqp_boolean_t
  exclusive: amqp_boolean_t;   // Era Byte, agora amqp_boolean_t
  auto_delete: amqp_boolean_t; // Era Byte, agora amqp_boolean_t
  arguments: amqp_table_t
): Pamqp_queue_declare_ok_t; cdecl; external 'librabbitmq.so';

function amqp_basic_publish(
  state: Pamqp_connection_state_t;
  channel: amqp_channel_t;
  exchange, routing_key: amqp_bytes_t;
  mandatory, immediate: amqp_boolean_t;
  properties: Pointer;
  body: amqp_bytes_t
): Integer; cdecl; external 'librabbitmq.so';

function amqp_connection_close(state: Pamqp_connection_state_t; code: Integer): amqp_rpc_reply_t; cdecl; external 'librabbitmq.so';
procedure amqp_destroy_connection(state: Pamqp_connection_state_t); cdecl; external 'librabbitmq.so';

function amqp_cstring_bytes(cstr: PChar): amqp_bytes_t; cdecl; external 'librabbitmq.so';


// Funções para consumo de mensagens
function amqp_basic_get(state: Pamqp_connection_state_t; channel: amqp_channel_t;
                       queue: amqp_bytes_t; no_ack: amqp_boolean_t): amqp_rpc_reply_t; cdecl; external 'librabbitmq.so';

function amqp_read_message(state: Pamqp_connection_state_t; channel: Word;
                          message: Pointer; flags: Integer): amqp_rpc_reply_t; cdecl; external 'librabbitmq.so';

implementation

constructor TRabbitMQClient.Create;
begin
  inherited Create;
  FConnection := nil;
  FSocket := nil;
  FConnected := False;
  FHost := '';
  FPort := 5672;
  FUsername := '';
  FPassword := '';
  FVHost := '/';
end;

destructor TRabbitMQClient.Destroy;
begin
  if FConnected then
    Disconnect;
  inherited Destroy;
end;

function TRabbitMQClient.StringToBytes(const AString: string): amqp_bytes_t;
begin
  Result := amqp_cstring_bytes(PChar(AString));
end;

function TRabbitMQClient.BytesToString(const ABytes: amqp_bytes_t): string;
begin
  if (ABytes.bytes <> nil) and (ABytes.len > 0) then
  begin
    SetLength(Result, ABytes.len);
    Move(ABytes.bytes^, Result[1], ABytes.len);
  end
  else
    Result := '';
end;

function TRabbitMQClient.Connect(const AHost: string; APort: Integer;
                                const AUsername, APassword, AVHost: string): Boolean;
var
  LoginResult: amqp_rpc_reply_t;
  ChannelResult: amqp_rpc_reply_t;
begin

  Result := False;

  try
    // Criar conexão
    FConnection := amqp_new_connection;
    if FConnection = nil then
      Exit;

    // Criar socket
    FSocket := amqp_tcp_socket_new(FConnection);
    if FSocket = nil then
      Exit;

    // Abrir socket
    if amqp_socket_open(FSocket, PChar(AHost), APort) <> 0 then
      Exit;

    // Fazer login
    LoginResult := amqp_login(FConnection, PChar(AVHost),
                             0, 131072, 0, AMQP_SASL_METHOD_PLAIN,
                             PChar(AUsername), PChar(APassword));

    // Verificar se o login foi bem-sucedido
    if LoginResult.reply_type <> Integer(AMQP_RESPONSE_NORMAL) then
    begin
      Exit;
    end;

    // Abrir canal
    amqp_channel_open(FConnection, 1);
    ChannelResult := amqp_get_rpc_reply(FConnection);
    if ChannelResult.reply_type <> Integer(AMQP_RESPONSE_NORMAL) then
      Exit;

    FHost := AHost;
    FPort := APort;
    FUsername := AUsername;
    FPassword := APassword;
    FVHost := AVHost;
    FConnected := True;
    Result := True;

  except
    on E: Exception do
    begin
      FConnected := False;
      Result := False;
    end;
  end;
end;

procedure TRabbitMQClient.Disconnect;
begin
  if FConnection <> nil then
  begin
    try
      amqp_destroy_connection(FConnection);
    except
      // Ignora erros
    end;
    FConnection := nil;
    FSocket := nil;
  end;
  FConnected := False;
end;

function TRabbitMQClient.DeclareQueue(const AQueueName: string;
  ADurable: Boolean; APassive: Boolean): Boolean;
var
  QueueBytes: amqp_bytes_t;
  EmptyTable: amqp_table_t;
  DeclareResult: amqp_rpc_reply_t;
  DurableByte, PassiveByte: amqp_boolean_t;
  DeclareOk: Pamqp_queue_declare_ok_t;
begin
  Result := False;
  LogToFile('=== DeclareQueue INÍCIO ===');
  LogToFile('DeclareQueue: Fila: ' + AQueueName + ', Durável: ' + BoolToStr(ADurable));

  if not FConnected then
  begin
    LogToFile('DeclareQueue: ERRO - Não conectado!');
    Exit;
  end;

  try
    QueueBytes := StringToBytes(AQueueName);
    EmptyTable := amqp_empty_table;

    // Conversão correta para amqp_boolean_t
    if ADurable then
      DurableByte := 1
    else
      DurableByte := 0;

    if APassive then
      PassiveByte := 1
    else
      PassiveByte := 0;

    LogToFile('DeclareQueue: Chamando amqp_queue_declare...');

    DeclareOk := amqp_queue_declare(
      FConnection,
      1,           // channel
      QueueBytes,  // queue name
      PassiveByte, // passive (amqp_boolean_t)
      DurableByte, // durable (amqp_boolean_t)
      0,           // exclusive (amqp_boolean_t)
      0,           // auto_delete (amqp_boolean_t)
      EmptyTable   // arguments
    );

    DeclareResult := amqp_get_rpc_reply(FConnection);

    if DeclareResult.reply_type = Integer(AMQP_RESPONSE_NORMAL) then
    begin
      LogToFile('DeclareQueue: SUCESSO!');
      Result := True;
    end
    else
    begin
      LogToFile('DeclareQueue: FALHOU! reply_type = ' + IntToStr(DeclareResult.reply_type));
      case DeclareResult.reply_type of
        Integer(AMQP_RESPONSE_NONE): LogToFile('  -> AMQP_RESPONSE_NONE');
        Integer(AMQP_RESPONSE_LIBRARY_EXCEPTION): LogToFile('  -> AMQP_RESPONSE_LIBRARY_EXCEPTION');
      else
        LogToFile('  -> Tipo desconhecido: ' + IntToStr(DeclareResult.reply_type));
      end;

      // Feche o canal
      Disconnect;

    end;

  except
    on E: Exception do
    begin
      LogToFile('DeclareQueue: EXCEÇÃO: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TRabbitMQClient.PublishMessage(const AExchange, ARoutingKey, AMessage: string): Boolean;
var
  ExchangeBytes, RoutingKeyBytes, MessageBytes: amqp_bytes_t;
  PublishResult: Integer;
  Props: amqp_basic_properties_t;
begin
  Result := False;

  if not FConnected then
  begin
    LogToFile('Erro: Não conectado');
    Exit;
  end;

  try
    ExchangeBytes := StringToBytes(AExchange);
    RoutingKeyBytes := StringToBytes(ARoutingKey);
    MessageBytes := StringToBytes(AMessage);

    // Configurar propriedades básicas da mensagem
    FillChar(Props, SizeOf(Props), 0);
    Props._flags := AMQP_BASIC_CONTENT_TYPE_FLAG or AMQP_BASIC_DELIVERY_MODE_FLAG;
    Props.content_type := StringToBytes('text/plain');
    Props.delivery_mode := 2; // Persistente

    PublishResult := amqp_basic_publish(
      FConnection,
      1,                    // channel (amqp_channel_t)
      ExchangeBytes,
      RoutingKeyBytes,
      0,                    // mandatory (amqp_boolean_t)
      0,                    // immediate (amqp_boolean_t)
      @Props,               // properties
      MessageBytes
    );

    LogToFile(Format('PublishResult: %d, Exchange: "%s", RoutingKey: "%s", Message: "%s"',
                     [PublishResult, AExchange, ARoutingKey, AMessage]));

    if PublishResult <> 0 then
    begin
      LogToFile('Erro na publicação - código: ' + IntToStr(PublishResult));
      Exit;
    end;

    Result := True;

  except
    on E: Exception do
    begin
      LogToFile('Exception: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TRabbitMQClient.ConsumeMessage(const AQueueName: string; out AMessage: string;
                                       ATimeout: Integer): Boolean;
var
  QueueBytes: amqp_bytes_t;
  GetResult: amqp_rpc_reply_t;
  Envelope: amqp_envelope_t;
begin
  Result := False;
  AMessage := '';

  if not FConnected then
    Exit;

  try
    QueueBytes := StringToBytes(AQueueName);

    // Tenta pegar uma mensagem da fila (no_ack = 1)
    GetResult := amqp_basic_get(FConnection, 1, QueueBytes, 1);

    if GetResult.reply_type = Integer(AMQP_RESPONSE_NORMAL) then
    begin
      // Tenta ler o envelope (corpo da mensagem)
      if amqp_read_message(FConnection, 1, @Envelope, 0).reply_type = Integer(AMQP_RESPONSE_NORMAL) then
      begin
        if Envelope.body.len > 0 then
        begin
          SetLength(AMessage, Envelope.body.len);
          Move(Envelope.body.bytes^, AMessage[1], Envelope.body.len);
          Result := True;
        end
        else
        begin
          LogToFile('ConsumeMessage: Envelope.body.len = 0');
        end;
      end
      else
      begin
        LogToFile('ConsumeMessage: Falha ao ler envelope');
      end;
    end
    else
    begin
      LogToFile('ConsumeMessage: Nenhuma mensagem disponível ou erro');
    end;

  except
    on E: Exception do
    begin
      LogToFile('ConsumeMessage: EXCEÇÃO: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TRabbitMQClient.StartConsumer(const AQueueName: string): Boolean;
var
  QueueBytes: amqp_bytes_t;
begin
  QueueBytes := StringToBytes(AQueueName);
  // Chama amqp_basic_consume (verifique a assinatura no seu binding)
  // Exemplo:
  // amqp_basic_consume(FConnection, 1, QueueBytes, amqp_empty_bytes, 0, 1, 0, amqp_empty_table);
  Result := True;
end;

function TRabbitMQClient.WaitForMessage(out AMessage: string): Boolean;
var
  Envelope: amqp_envelope_t;
begin
  Result := False;
  if amqp_read_message(FConnection, 1, @Envelope, 0).reply_type = Integer(AMQP_RESPONSE_NORMAL) then
  begin
    if Envelope.body.len > 0 then
    begin
      SetLength(AMessage, Envelope.body.len);
      Move(Envelope.body.bytes^, AMessage[1], Envelope.body.len);
      Result := True;
    end;
  end;
end;

procedure LogToFile(const Msg: string);
var
  F: TextFile;
begin
  AssignFile(F, 'rabbitmq_test.log');
  if FileExists('rabbitmq_test.log') then
    Append(F)
  else
    Rewrite(F);
  writeln(F, Msg);
  CloseFile(F);
end;

end.
