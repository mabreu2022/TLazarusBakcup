{
  uSharedPatcher.pas - Lógica de patch compartilhada entre a aplicação Standalone e o Pacote IDE
}
unit uSharedPatcher;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  Laz2_DOM, Laz2_XMLRead, Laz2_XMLWrite,
  FileUtil, LazFileUtils;

type
  TSharedLogProc = procedure(const AMsg: string) of object;

function PerformPortablePatch(const APortableDir, AConfigDir: string; ALogProc: TSharedLogProc = nil): Boolean;

implementation

procedure DoLog(ALogProc: TSharedLogProc; const AMsg: string);
begin
  if Assigned(ALogProc) then
    ALogProc(AMsg);
end;

function FixPathString(const APath, APortableDir: string): string;
var
  RelativePart: string;
begin
  Result := APath;
  if APath = '' then Exit;

  if Pos('$(PortableDir)', APath) = 1 then
  begin
    RelativePart := Copy(APath, Length('$(PortableDir)') + 1, Length(APath));
    if (RelativePart <> '') and (RelativePart[1] in ['\', '/']) then
      Delete(RelativePart, 1, 1);
    Result := IncludeTrailingPathDelimiter(APortableDir) + RelativePart;
    Exit;
  end;
end;

procedure PatchNode(ANode: TDOMNode; const APortableDir: string; ALogProc: TSharedLogProc);
var
  I: Integer;
  Child: TDOMNode;
  Attr: TDOMNode;
  Keys: array[0..8] of string = (
    'Value', 'Directory', 'Filename', 'Path',
    'LazarusDirectory', 'CompilerFilename', 'FPCSourceDir',
    'FileName', 'Dir'
  );
  NewVal: string;
begin
  if ANode.HasAttributes then
  begin
    for I := 0 to High(Keys) do
    begin
      Attr := ANode.Attributes.GetNamedItem(Keys[I]);
      if Attr <> nil then
      begin
        NewVal := FixPathString(Attr.TextContent, APortableDir);
        if NewVal <> Attr.TextContent then
        begin
          DoLog(ALogProc, '  Patch: ' + Attr.TextContent + ' -> ' + NewVal);
          Attr.TextContent := NewVal;
        end;
      end;
    end;
  end;

  Child := ANode.FirstChild;
  while Child <> nil do
  begin
    PatchNode(Child, APortableDir, ALogProc);
    Child := Child.NextSibling;
  end;
end;

function PerformPortablePatch(const APortableDir, AConfigDir: string; ALogProc: TSharedLogProc): Boolean;
var
  XMLDoc: TXMLDocument;
  EnvFile: string;
  RootNode, EnvNode, Node: TDOMNode;
  Attr: TDOMAttr;
begin
  Result := False;
  EnvFile := IncludeTrailingPathDelimiter(AConfigDir) + 'environmentoptions.xml';

  if not FileExists(EnvFile) then
  begin
    DoLog(ALogProc, 'environmentoptions.xml não encontrado: ' + EnvFile);
    Exit;
  end;

  XMLDoc := nil;
  try
    DoLog(ALogProc, 'Aplicando patch em environmentoptions.xml...');
    ReadXMLFile(XMLDoc, EnvFile);

    RootNode := XMLDoc.DocumentElement;
    EnvNode := RootNode.FindNode('EnvironmentOptions');
    if EnvNode = nil then EnvNode := RootNode;

    Node := EnvNode.FindNode('LazarusDirectory');
    if Node <> nil then
    begin
      Attr := TDOMAttr(Node.Attributes.GetNamedItem('Value'));
      if Attr <> nil then Attr.Value := APortableDir;
    end;

    PatchNode(RootNode, APortableDir, ALogProc);
    WriteXMLFile(XMLDoc, EnvFile);
    DoLog(ALogProc, 'Patch de ambiente concluído com sucesso.');
    Result := True;
  except
    on E: Exception do
      DoLog(ALogProc, 'Erro ao patchear: ' + E.Message);
  end;

  if Assigned(XMLDoc) then XMLDoc.Free;
end;

end.
