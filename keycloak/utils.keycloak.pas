unit utils.keycloak;

{$mode ObjFPC}{$H+}

interface

uses
  fphttpclient, fpjson, jsonparser, sysutils, classes, HTTPDefs, utils.env,
  base64, utils.jsonException, opensslsockets, httpsend, ssl_openssl,
  blcksock;

function ValidarToken(ARequest: TRequest; var AResponse: TResponse; ClientSecret, keycloakUrl: string): Boolean;
function ValidarTokenViaApi(const AToken, BaseUrl: string): Boolean;
function ExtrairBearerToken(const ARequest: TRequest): string;
function GetRealm(const AToken :String): String;

implementation

function Base64URLToBase64(const Input: string): string;
var
  S: string;
begin
  S := Input;
  S := StringReplace(S, '-', '+', [rfReplaceAll]);
  S := StringReplace(S, '_', '/', [rfReplaceAll]);
  while Length(S) mod 4 <> 0 do
    S := S + '=';
  Result := S;
end;

function GetJWTClaim(const Token: string; const Claim: string): string;
var
  Parts: TStringArray;
  Payload, JSONStr: string;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  ClaimData: TJSONData;
begin
  Result := '';
  try
    Parts := Token.Split(['.']);
    if Length(Parts) <> 3 then Exit;

    Payload := Parts[1];
    JSONStr := DecodeStringBase64(Base64URLToBase64(Payload));

    JSONData := GetJSON(JSONStr);
    try
      if JSONData.JSONType = jtObject then
      begin
        JSONObject := TJSONObject(JSONData);
        ClaimData := JSONObject.Find(Claim);
        if Assigned(ClaimData) then
        begin
          case ClaimData.JSONType of
            jtString, jtNumber, jtBoolean: Result := ClaimData.AsString;
            else Result := ClaimData.AsString; // fallback
          end;
        end;
      end;
    finally
      JSONData.Free;
    end;
  except
    Result := '';
  end;
end;

function ExtrairBearerToken(const ARequest: TRequest): string;
var
  AuthHeader: string;
  Parts: TStringArray;
begin
  AuthHeader := ARequest.Authorization;
  if AuthHeader = '' then
    raise EJsonException.Create('Authorization header is missing', 401);

  Parts := AuthHeader.Split([' ']);
  if (Length(Parts) <> 2) or (Parts[0] <> 'Bearer') then
    raise EJsonException.Create('Invalid Authorization header format', 401);

  Result := Parts[1];
end;

function ValidarTokenViaApi(const AToken, BaseUrl: string): Boolean;
var
  LHttp: THTTPSend;
  ResponseStr: string;
  JsonResp: TJSONObject;
  ValidateUrl: string;
  Payload: string;
begin
  Result := False;

  if Trim(AToken) = '' then
    raise EJsonException.Create('Token is missing', 401);

  // BaseUrl + /auth/token/validate
  ValidateUrl := BaseUrl;
  if ValidateUrl.EndsWith('/') then
    ValidateUrl := ValidateUrl.Substring(0, ValidateUrl.Length - 1);
  ValidateUrl := ValidateUrl + '/auth/token/validate';

  LHttp := THTTPSend.Create;
  JsonResp := nil;
  try
    try
      LHttp.Clear;
      LHttp.Timeout := 15000;
      LHttp.Sock.SSL.SSLType := LT_TLSv1_3;

      // Endpoint retorna JSON, então enviamos JSON também
      LHttp.MimeType := 'application/json';

      // Corpo: {"token":"..."}
      Payload := '{"token":"' + StringReplace(AToken, '"', '\"', [rfReplaceAll]) + '"}';
      LHttp.Document.WriteBuffer(Pointer(Payload)^, Length(Payload));

      if LHttp.HTTPMethod('POST', ValidateUrl) then
      begin
        SetLength(ResponseStr, LHttp.Document.Size);
        if LHttp.Document.Size > 0 then
          LHttp.Document.ReadBuffer(Pointer(ResponseStr)^, LHttp.Document.Size);
      end;

      if LHttp.ResultCode <> 200 then
      begin
        ResponseStr := LHttp.ResultString;
        if ResponseStr = '' then
          ResponseStr := 'Erro ao validar token, code: ' + LHttp.ResultCode.ToString();

        // Se sua API usar 401 pra expirado/inválido, aqui já cai com o status correto
        raise EJsonException.Create(ResponseStr + ' url:' + ValidateUrl, LHttp.ResultCode);
      end;

      JsonResp := TJSONObject(GetJSON(ResponseStr));

      // Só usa o "active" e ignora o resto
      if JsonResp.Get('active', False) then
        Result := True
      else
        raise EJsonException.Create('Token inválido ou expirado', 401);

    except
      on E: EJsonException do
        raise;
      on E: Exception do
        raise EJsonException.Create(E.Message, 500);
    end;
  finally
    JsonResp.Free;
    LHttp.Free;
  end;
end;

function ExtractRealmFromIssuer(const Issuer: string): string;
var
  Parts: TStringArray;
begin
  Parts := Issuer.Split(['/']);
  if Length(Parts) > 0 then
    Result := Parts[High(Parts)]
  else
    Result := '';
end;

function ValidarToken(ARequest: TRequest; var AResponse: TResponse; ClientSecret, keycloakUrl: string): Boolean;
var
  AuthHeader, Token: string;
  TokenParts: TStringArray;
  FormData : String;
  LHttp : THTTPSend;
  ResponseStr: string;
  JsonResp: TJSONObject;
  IntrospectUrl, Realm, ClientId, Issuer: string;
begin
  Result := False;

  // Pular validação para OPTIONS (CORS)
  if ARequest.Method = 'OPTIONS' then
  begin
    Result := True;
    Exit;
  end;

  // 1. Obter token do header Authorization
  AuthHeader := ARequest.Authorization;
  if AuthHeader = '' then
  begin
    raise EJsonException.Create('Authorization header is missing', 401);
  end;

  // 2. Extrair token do formato "Bearer <token>"
  TokenParts := AuthHeader.Split([' ']);
  if (Length(TokenParts) <> 2) or (TokenParts[0] <> 'Bearer') then
  begin
    raise EJsonException.Create('Invalid Authorization header format', 401);
  end;

  Token := TokenParts[1];

  // 3. Extrair realm do campo iss do token
  Issuer := GetJWTClaim(Token, 'iss');
  if Issuer = '' then
  begin
    raise EJsonException.Create('Issuer (iss) claim missing in token', 401);
  end;
  Realm := ExtractRealmFromIssuer(Issuer);
  if Realm = '' then
  begin
    raise EJsonException.Create('Invalid realm extracted from issuer', 401);
  end;

  // 4. Extrair client_id do campo azp do token
  ClientId := GetJWTClaim(Token, 'azp');
  if ClientId = '' then
  begin
    raise EJsonException.Create('Client ID (azp) claim missing in token', 401);
  end;

  // 5. Preparar URL de introspecção
  IntrospectUrl := Format('%s/realms/%s/protocol/openid-connect/token/introspect',
    [keycloakUrl, Realm]);


  LHttp := THTTPSend.Create;
  JsonResp:= TJSONObject.Create;
  try
    try
    LHttp.Clear;
    LHttp.Timeout := 15000;
    LHttp.Sock.SSL.SSLType := LT_TLSv1_3;
    LHttp.MimeType := 'application/x-www-form-urlencoded';

    FormData := Format('client_id=%s&client_secret=%s&token=%s', [ClientId, ClientSecret, Token]);
    LHttp.Document.WriteBuffer(Pointer(FormData)^, Length(FormData));

    if (LHttp.HTTPMethod('POST', IntrospectUrl)) then
    begin
      SetLength(ResponseStr, LHttp.Document.Size);
      LHttp.Document.ReadBuffer(Pointer(ResponseStr)^, LHttp.Document.Size);
    end;

    if LHttp.ResultCode <> 200 then
    begin
      ResponseStr := LHttp.ResultString;
      if (ResponseStr = '') then
        ResponseStr := 'Erro ao obter token, code: ' + LHttp.ResultCode.ToString();
      raise EJsonException.Create('Emissor: '+ResponseStr + ' url:'+IntrospectUrl, LHttp.ResultCode);
    end;

    JsonResp := TJSONObject(GetJSON(ResponseStr));

    if JsonResp.Get('active', False) then
    begin
      Result := True;
    end
    else
    begin
     raise EJsonException.Create('Invalid or inactive token', 401);
    end;

    except
      on E: EJsonException do
        raise;
      on E: Exception do
        raise EJsonException.Create(E.Message, 500);
    end;
  finally
    JsonResp.Free;
    LHttp.Free;
  end;

end;

function GetRealm(const AToken: String): String;
var
  vIss, vRealm :String;
begin
  vIss := GetJWTClaim(AToken, 'iss');
  vRealm := ExtractRealmFromIssuer(vIss);
  Result := vRealm;
end;

end.
