unit utils.keycloak;

{$mode ObjFPC}{$H+}

interface

uses
  fphttpclient, fpjson, jsonparser, sysutils, classes, HTTPDefs, utils.env, base64;

function ValidarToken(ARequest: TRequest; var AResponse: TResponse; ClientSecret, keycloakUrl: string): Boolean;

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
  Http: TFPHTTPClient;
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
    AResponse.Code := 401;
    AResponse.Content := '{"error": "Authorization header is missing"}';
    Exit;
  end;

  // 2. Extrair token do formato "Bearer <token>"
  TokenParts := AuthHeader.Split([' ']);
  if (Length(TokenParts) <> 2) or (TokenParts[0] <> 'Bearer') then
  begin
    AResponse.Code := 401;
    AResponse.Content := '{"error": "Invalid Authorization header format"}';
    Exit;
  end;

  Token := TokenParts[1];

  // 3. Extrair realm do campo iss do token
  Issuer := GetJWTClaim(Token, 'iss');
  if Issuer = '' then
  begin
    AResponse.Code := 401;
    AResponse.Content := '{"error": "Issuer (iss) claim missing in token"}';
    Exit;
  end;
  Realm := ExtractRealmFromIssuer(Issuer);
  if Realm = '' then
  begin
    AResponse.Code := 401;
    AResponse.Content := '{"error": "Invalid realm extracted from issuer"}';
    Exit;
  end;

  // 4. Extrair client_id do campo azp do token
  ClientId := GetJWTClaim(Token, 'azp');
  if ClientId = '' then
  begin
    AResponse.Code := 401;
    AResponse.Content := '{"error": "Client ID (azp) claim missing in token"}';
    Exit;
  end;

  // 5. Preparar URL de introspecção
  IntrospectUrl := Format('%s/realms/%s/protocol/openid-connect/token/introspect',
    [keycloakUrl, Realm]);

  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Content-Type', 'application/x-www-form-urlencoded');

    // Enviar dados para introspecção
    ResponseStr := Http.FormPost(IntrospectUrl,
      Format('client_id=%s&client_secret=%s&token=%s', [ClientId, ClientSecret, Token]));

    JsonResp := TJSONObject(GetJSON(ResponseStr));
    try
      if JsonResp.Get('active', False) then
      begin
        Result := True;
      end
      else
      begin
        AResponse.Code := 401;
        AResponse.Content := '{ "error": "Invalid or inactive token" }';
      end;
    finally
      JsonResp.Free;
    end;
  except
    on E: Exception do
    begin
      AResponse.Code := 500;
      AResponse.Content := '{"error": "Token introspection failed: ' + E.Message  + '}"';
    end;
  end;
  Http.Free;
end;

end.
