unit utils.xml;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, DOM, XMLRead;

function XMLNodeToJSON(Node: TDOMNode): TJSONData;
function XMLToJSONFromString(const XMLContent: string): string;
function ErroJson(AMenssagem :String) :String;

implementation

function XMLNodeToJSON(Node: TDOMNode): TJSONData;
var
  Obj: TJSONObject;
  ChildObj: TJSONData;
  i: integer;
  NodeName, TextContent: string;
  ChildNode: TDOMNode;
  Attr: TDOMAttr;
  ChildNames: TStringList;
  HasAttributes, HasElementChild, HasTextChild: boolean;
  TextOnlyContent: string;
  ChildArray: TJSONArray;
begin
  // Tratamento para nós de texto puro:
  if (Node.NodeType = TEXT_NODE) or (Node.NodeType = CDATA_SECTION_NODE) then
  begin
    TextContent := Trim(Node.TextContent);
    if TextContent = '' then
      Exit(TJSONNull.Create)
    else
      Exit(TJSONString.Create(TextContent));
  end;

  // Se for um nó elemento, analisamos mais profundamente
  if Node.NodeType = ELEMENT_NODE then
  begin
    HasAttributes := Node.HasAttributes;
    HasElementChild := False;
    HasTextChild := False;
    TextOnlyContent := '';

    ChildNames := TStringList.Create;
    try
      ChildNode := Node.FirstChild;
      while Assigned(ChildNode) do
      begin
        if (ChildNode.NodeType in [TEXT_NODE, CDATA_SECTION_NODE]) then
        begin
          if Trim(ChildNode.TextContent) <> '' then
          begin
            HasTextChild := True;
            TextOnlyContent := Trim(ChildNode.TextContent);
          end;
        end
        else if (ChildNode.NodeType = ELEMENT_NODE) then
        begin
          HasElementChild := True;
        end;
        ChildNode := ChildNode.NextSibling;
      end;

      // Caso: Nó sem atributos, com um único texto e sem filhos de elemento
      // Nesse caso, retornamos apenas o texto
      if (not HasAttributes) and (HasTextChild) and (not HasElementChild) and
        (Node.ChildNodes.Count = 1) then
      begin
        if TextOnlyContent = '' then
          Exit(TJSONNull.Create)
        else
          Exit(TJSONString.Create(TextOnlyContent));
      end;

      // Caso contrário, criamos um objeto JSON
      Obj := TJSONObject.Create;

      // Adiciona atributos do nó, se houver
      if HasAttributes then
        for i := 0 to Node.Attributes.Length - 1 do
        begin
          Attr := TDOMAttr(Node.Attributes.Item[i]);
          Obj.Add(Attr.Name, Attr.Value);
        end;

      // Adiciona filhos
      ChildNode := Node.FirstChild;
      while Assigned(ChildNode) do
      begin
        if (ChildNode.NodeType in [TEXT_NODE, CDATA_SECTION_NODE]) then
        begin
          // Temos texto + atributos ou texto + outros nós
          // Nesse caso, guardamos o texto em uma chave 'value' caso não seja vazio.
          if Trim(ChildNode.TextContent) <> '' then
          begin
            // Só adiciona 'value' se ainda não adicionamos
            if Obj.IndexOfName('value') = -1 then
              Obj.Add('value', Trim(ChildNode.TextContent))
            else
            begin
              // Se por algum motivo existe mais de um texto não-atribuir a #text,
              // Apenas concatenar ou lidar conforme a necessidade:
              Obj.Elements['value'] :=
                TJSONString.Create(Obj.Elements['value'].AsString +
                ' ' + Trim(ChildNode.TextContent));
            end;
          end;
        end
        else if ChildNode.NodeType = ELEMENT_NODE then
        begin
          NodeName := ChildNode.NodeName;
          ChildObj := XMLNodeToJSON(ChildNode);

          if Obj.IndexOfName(NodeName) = -1 then
          begin
            Obj.Add(NodeName, ChildObj);
          end
          else
          begin
            // Já existe a chave, transformar em array se necessário
            if not (Obj.Elements[NodeName] is TJSONArray) then
            begin
              // Cria o array e move o item existente para dentro dele
              ChildArray := TJSONArray.Create;
              ChildArray.Add(Obj.Elements[NodeName]);
              Obj.Elements[NodeName] := ChildArray;
            end;
            TJSONArray(Obj.Elements[NodeName]).Add(ChildObj);
          end;
        end;
        ChildNode := ChildNode.NextSibling;
      end;

      Result := Obj;
    finally
      ChildNames.Free;
    end;
  end
  else
    Result := TJSONNull.Create;
end;


function XMLToJSONFromString(const XMLContent: string): string;
var
  Doc: TXMLDocument;
  SS: TStringStream;
  JSONData: TJSONData;
begin
  SS := TStringStream.Create(XMLContent);
  try
    ReadXMLFile(Doc, SS);
    try
      JSONData := XMLNodeToJSON(Doc.DocumentElement);
      try
        Result := JSONData.AsJSON;
      finally
        JSONData.Free;
      end;
    finally
      Doc.Free;
    end;
  finally
    SS.Free;
  end;
end;

function ErroJson(AMenssagem: String): String;
begin
  Format('{"error": "%s"}', [AMenssagem])
end;

end.
