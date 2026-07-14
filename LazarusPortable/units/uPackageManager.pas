{
  uPackageManager.pas - Gerenciador de pacotes do Lazarus portável
  ================================================================
  Responsável por:
    - Varrer e listar todos os pacotes .lpk instalados
    - Verificar integridade de caminhos de pacotes
    - Integração com OPM (Online Package Manager) do Lazarus
    - Download e instalação de pacotes remotos

  Lazarus 4.8 / FPC 3.2.4+ / Windows
}
unit uPackageManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl,
  Laz2_DOM, Laz2_XMLRead,
  FileUtil, LazFileUtils,
  fpjson, jsonparser,
  fphttpclient, opensslsockets, HTTPDefs;

const
  OPM_API_URL         = 'https://packages.lazarus-ide.org';
  OPM_PACKAGELIST_URL = 'https://packages.lazarus-ide.org/packagelist.json';

type
  TPackageState = (
    psOK,           // Pacote OK e caminhos válidos
    psPathBroken,   // Diretório do pacote não encontrado
    psNotCompiled,  // Compilado mas sem lib
    psUnknown       // Estado desconhecido
  );

  { TPackageInfo - Informações de um pacote instalado }
  TPackageInfo = class
  public
    Name        : string;    // Nome do pacote
    Version     : string;    // Versão
    Author      : string;    // Autor
    Description : string;   // Descrição
    LPKFile     : string;    // Caminho completo do .lpk
    PackageDir  : string;    // Diretório do pacote
    State       : TPackageState;
    StateDetail : string;   // Detalhes sobre o estado
    IsInstalled : Boolean;  // Instalado na IDE
    Dependencies: TStringList;  // Dependências

    constructor Create;
    destructor  Destroy; override;
    function    StateText: string;
  end;

  TPackageList = specialize TFPGObjectList<TPackageInfo>;

  { TOPMPackageInfo - Informação de pacote do Online Package Manager }
  TOPMPackageInfo = record
    Name         : string;
    Version      : string;
    Author       : string;
    Description  : string;
    LicenseType  : string;
    Category     : string;
    DownloadURL  : string;
    OPMFileCount : Integer;
  end;

  TOPMPackageArray = array of TOPMPackageInfo;

  TDownloadProgressEvent = procedure(const APackage, AStatus: string;
    APercent: Integer) of object;

  { TPackageManager - Gerenciador completo de pacotes }
  TPackageManager = class
  private
    FPortableDir  : string;
    FConfigDir    : string;
    FPackageList  : TPackageList;
    FOnProgress   : TDownloadProgressEvent;

    function  ParseLPKFile(const ALPKPath: string): TPackageInfo;
    function  CheckPackageIntegrity(APkg: TPackageInfo): TPackageState;
    procedure ScanDirectory(const ADir: string; ADepth: Integer = 0);
    function  HTTPGet(const AURL: string): string;
    function  ParseOPMResponse(const AJSON: string): TOPMPackageArray;

  public
    constructor Create(const APortableDir, AConfigDir: string);
    destructor  Destroy; override;

    { Varredura local de pacotes }
    procedure ScanInstalledPackages;
    procedure ScanFromPackageFilesXML;

    { Verificação de integridade }
    procedure CheckAllIntegrity;
    function  GetBrokenPackages: TPackageList;

    { OPM - Online Package Manager }
    function  OPMSearch(const ATerm: string; ACount: Integer = 30): TOPMPackageArray;
    function  OPMGetPackage(const AName: string): TOPMPackageInfo;
    function  OPMDownload(const APkg: TOPMPackageInfo;
                const ADestDir: string): Boolean;

    { Exportar/importar lista }
    procedure ExportToFile(const AFileName: string);
    procedure ImportFromFile(const AFileName: string);

    property PackageList : TPackageList          read FPackageList;
    property OnProgress  : TDownloadProgressEvent read FOnProgress write FOnProgress;
  end;

implementation

{ TPackageInfo }

constructor TPackageInfo.Create;
begin
  inherited Create;
  Dependencies := TStringList.Create;
  State        := psUnknown;
end;

destructor TPackageInfo.Destroy;
begin
  Dependencies.Free;
  inherited Destroy;
end;

function TPackageInfo.StateText: string;
begin
  case State of
    psOK:          Result := 'OK';
    psPathBroken:  Result := 'Caminho inválido';
    psNotCompiled: Result := 'Não compilado';
    else           Result := 'Desconhecido';
  end;
end;

{ TPackageManager }

constructor TPackageManager.Create(const APortableDir, AConfigDir: string);
begin
  inherited Create;
  FPortableDir := IncludeTrailingPathDelimiter(APortableDir);
  FConfigDir   := IncludeTrailingPathDelimiter(AConfigDir);
  FPackageList := TPackageList.Create(True); // owns objects
end;

destructor TPackageManager.Destroy;
begin
  FPackageList.Free;
  inherited Destroy;
end;

{ Faz parse de um arquivo .lpk e retorna as informações do pacote }
function TPackageManager.ParseLPKFile(const ALPKPath: string): TPackageInfo;
var
  XMLDoc  : TXMLDocument;
  Root    : TDOMNode;
  PkgNode : TDOMNode;
  Node    : TDOMNode;
  Attr    : TDOMNode;
  Child   : TDOMNode;
begin
  Result := TPackageInfo.Create;
  Result.LPKFile    := ALPKPath;
  Result.PackageDir := ExtractFileDir(ALPKPath);
  Result.Name       := ChangeFileExt(ExtractFileName(ALPKPath), '');

  if not FileExists(ALPKPath) then
  begin
    Result.State       := psPathBroken;
    Result.StateDetail := 'Arquivo .lpk não encontrado';
    Exit;
  end;

  XMLDoc := nil;
  try
    ReadXMLFile(XMLDoc, ALPKPath);

    Root    := XMLDoc.DocumentElement;
    // Estrutura: <CONFIG><Package Name="..." Version="..."><Author Value="..."/>...
    PkgNode := Root.FindNode('Package');
    if PkgNode = nil then
      PkgNode := Root;

    Attr := PkgNode.Attributes.GetNamedItem('Name');
    if Attr <> nil then Result.Name := Attr.TextContent;

    Attr := PkgNode.Attributes.GetNamedItem('Version');
    if Attr <> nil then Result.Version := Attr.TextContent;

    Node := PkgNode.FindNode('Author');
    if Node <> nil then
    begin
      Attr := Node.Attributes.GetNamedItem('Value');
      if Attr <> nil then Result.Author := Attr.TextContent;
    end;

    Node := PkgNode.FindNode('Description');
    if Node <> nil then
    begin
      Attr := Node.Attributes.GetNamedItem('Value');
      if Attr <> nil then Result.Description := Attr.TextContent;
    end;

    // Coleta dependências
    Node := PkgNode.FindNode('RequiredPkgs');
    if Node <> nil then
    begin
      Child := Node.FirstChild;
      while Child <> nil do
      begin
        Attr := Child.Attributes.GetNamedItem('Name');
        if Attr <> nil then
          Result.Dependencies.Add(Attr.TextContent);
        Child := Child.NextSibling;
      end;
    end;

  except
    on E: Exception do
    begin
      Result.State       := psUnknown;
      Result.StateDetail := 'Erro ao parsear LPK: ' + E.Message;
    end;
  end;

  if Assigned(XMLDoc) then
    XMLDoc.Free;
end;

{ Verifica se o pacote tem todos os arquivos necessários }
function TPackageManager.CheckPackageIntegrity(APkg: TPackageInfo): TPackageState;
begin
  if not FileExists(APkg.LPKFile) then
  begin
    APkg.StateDetail := 'Arquivo .lpk não encontrado: ' + APkg.LPKFile;
    Result := psPathBroken;
    Exit;
  end;

  if not DirectoryExists(APkg.PackageDir) then
  begin
    APkg.StateDetail := 'Diretório do pacote não encontrado: ' + APkg.PackageDir;
    Result := psPathBroken;
    Exit;
  end;

  Result := psOK;
  APkg.StateDetail := '';
end;

{ Varre um diretório recursivamente procurando arquivos .lpk }
procedure TPackageManager.ScanDirectory(const ADir: string; ADepth: Integer);
var
  SR  : TSearchRec;
  Pkg : TPackageInfo;
begin
  if ADepth > 5 then Exit; // Limita profundidade

  if FindFirst(ADir + '*.lpk', faAnyFile - faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        Pkg := ParseLPKFile(ADir + SR.Name);
        Pkg.State := CheckPackageIntegrity(Pkg);
        FPackageList.Add(Pkg);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  // Subdiretórios
  if FindFirst(ADir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and
         (SR.Attr and faDirectory <> 0) then
        ScanDirectory(ADir + SR.Name + PathDelim, ADepth + 1);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

{ Varre todos os pacotes instalados a partir do packagefiles.xml }
procedure TPackageManager.ScanFromPackageFilesXML;
var
  XMLDoc   : TXMLDocument;
  FilePath : string;
  Node     : TDOMNode;
  Child    : TDOMNode;
  Attr     : TDOMNode;
  LPKPath  : string;
  Pkg      : TPackageInfo;
begin
  FilePath := FConfigDir + 'packagefiles.xml';
  if not FileExists(FilePath) then Exit;

  XMLDoc := nil;
  try
    ReadXMLFile(XMLDoc, FilePath);

    // Navega: UserPkgLinks > Item > Filename
    Node := XMLDoc.DocumentElement;
    Node := Node.FindNode('UserPkgLinks');
    if Node = nil then
      Node := XMLDoc.DocumentElement;

    Child := Node.FirstChild;
    while Child <> nil do
    begin
      if SameText(Child.NodeName, 'Item') then
      begin
        Attr := Child.Attributes.GetNamedItem('Filename');
        if Attr <> nil then
        begin
          LPKPath := Attr.TextContent;

          // Resolve variáveis de caminho
          LPKPath := StringReplace(LPKPath, '$(LazarusDir)', FPortableDir,
            [rfReplaceAll, rfIgnoreCase]);
          LPKPath := StringReplace(LPKPath, '$(PortableDir)', FPortableDir,
            [rfReplaceAll, rfIgnoreCase]);

          Pkg := ParseLPKFile(LPKPath);
          Pkg.IsInstalled := True;
          Pkg.State := CheckPackageIntegrity(Pkg);
          FPackageList.Add(Pkg);
        end;
      end;
      Child := Child.NextSibling;
    end;
  except
  end;

  if Assigned(XMLDoc) then
    XMLDoc.Free;
end;

{ Varre toda a instalação portável em busca de pacotes }
procedure TPackageManager.ScanInstalledPackages;
var
  ComponentsDir: string;
  LclDir: string;
begin
  FPackageList.Clear;

  // Primeiro lê do packagefiles.xml (pacotes explicitamente instalados)
  ScanFromPackageFilesXML;

  // Depois varre componentes da própria instalação do Lazarus
  ComponentsDir := FPortableDir + 'components' + PathDelim;
  if DirectoryExists(ComponentsDir) then
    ScanDirectory(ComponentsDir);

  LclDir := FPortableDir + 'lcl' + PathDelim;
  if DirectoryExists(LclDir) then
    ScanDirectory(LclDir, 0);
end;

{ Verifica integridade de todos os pacotes carregados }
procedure TPackageManager.CheckAllIntegrity;
var
  Pkg: TPackageInfo;
begin
  for Pkg in FPackageList do
    Pkg.State := CheckPackageIntegrity(Pkg);
end;

{ Retorna apenas os pacotes com problemas }
function TPackageManager.GetBrokenPackages: TPackageList;
var
  Pkg: TPackageInfo;
begin
  Result := TPackageList.Create(False); // Não é dono dos objetos
  for Pkg in FPackageList do
    if Pkg.State <> psOK then
      Result.Add(Pkg);
end;

{ HTTP GET simples usando fphttpclient }
function TPackageManager.HTTPGet(const AURL: string): string;
var
  HTTP: TFPHTTPClient;
  Resp: TStringStream;
begin
  Result := '';
  HTTP := TFPHTTPClient.Create(nil);
  Resp := TStringStream.Create('');
  try
    HTTP.AllowRedirect := True;
    HTTP.ConnectTimeout := 10000;
    HTTP.IOTimeout      := 15000;
    HTTP.Get(AURL, Resp);
    Result := Resp.DataString;
  except
    on E: Exception do
      Result := '';
  end;
  Resp.Free;
  HTTP.Free;
end;

{ Faz parse da resposta JSON oficial do OPM (packagelist.json) }
function TPackageManager.ParseOPMResponse(const AJSON: string): TOPMPackageArray;
var
  JData     : TJSONData;
  JObj      : TJSONObject;
  PkgData   : TJSONObject;
  PkgFiles  : TJSONArray;
  FirstFile : TJSONObject;
  I         : Integer;
  DataKey   : string;
  FilesKey  : string;
  Count     : Integer;
  RepoFile  : string;
begin
  Result := nil;
  SetLength(Result, 0);
  if AJSON = '' then Exit;

  try
    JData := GetJSON(AJSON);
    try
      if JData.JSONType = jtObject then
      begin
        JObj := TJSONObject(JData);
        Count := 0;
        I := 0;

        while True do
        begin
          DataKey := 'PackageData' + IntToStr(I);
          if JObj.IndexOfName(DataKey) < 0 then Break;

          PkgData  := TJSONObject(JObj.Find(DataKey));
          FilesKey := 'PackageFiles' + IntToStr(I);
          PkgFiles := TJSONArray(JObj.Find(FilesKey));

          SetLength(Result, Count + 1);

          if Assigned(PkgData) then
          begin
            Result[Count].Name        := PkgData.Get('DisplayName', PkgData.Get('Name', ''));
            Result[Count].Category    := PkgData.Get('Category', '');
            Result[Count].Description := PkgData.Get('CommunityDescription', '');

            RepoFile := PkgData.Get('RepositoryFileName', '');
            if RepoFile <> '' then
            begin
              if Pos('http', LowerCase(RepoFile)) = 1 then
                Result[Count].DownloadURL := RepoFile
              else
                Result[Count].DownloadURL := OPM_API_URL + '/' + RepoFile;
            end;
          end;

          if Assigned(PkgFiles) and (PkgFiles.Count > 0) then
          begin
            FirstFile := TJSONObject(PkgFiles.Items[0]);
            Result[Count].Version := FirstFile.Get('VersionAsString', '');
            Result[Count].Author  := FirstFile.Get('Author', '');
            Result[Count].LicenseType := FirstFile.Get('License', '');
            if Result[Count].Description = '' then
              Result[Count].Description := FirstFile.Get('Description', '');
          end;

          Inc(Count);
          Inc(I);
        end;
      end;
    finally
      JData.Free;
    end;
  except
  end;
end;

{ Busca pacotes no OPM por termo }
function TPackageManager.OPMSearch(const ATerm: string; ACount: Integer): TOPMPackageArray;
var
  JSON       : string;
  AllPkgs    : TOPMPackageArray;
  Pkg        : TOPMPackageInfo;
  SearchTerm : string;
  Filtered   : TOPMPackageArray;
  Match      : Boolean;
  C          : Integer;
begin
  SetLength(Result, 0);
  JSON := HTTPGet(OPM_PACKAGELIST_URL);
  AllPkgs := ParseOPMResponse(JSON);

  SearchTerm := Trim(LowerCase(ATerm));
  if (SearchTerm = '') or (SearchTerm = '*') then
  begin
    Result := AllPkgs;
    Exit;
  end;

  C := 0;
  SetLength(Filtered, 0);
  for Pkg in AllPkgs do
  begin
    Match := (Pos(SearchTerm, LowerCase(Pkg.Name)) > 0) or
             (Pos(SearchTerm, LowerCase(Pkg.Category)) > 0) or
             (Pos(SearchTerm, LowerCase(Pkg.Author)) > 0) or
             (Pos(SearchTerm, LowerCase(Pkg.Description)) > 0);

    if Match then
    begin
      SetLength(Filtered, C + 1);
      Filtered[C] := Pkg;
      Inc(C);
      if (ACount > 0) and (C >= ACount) then Break;
    end;
  end;

  Result := Filtered;
end;

{ Obtém informações de um pacote específico do OPM }
function TPackageManager.OPMGetPackage(const AName: string): TOPMPackageInfo;
var
  Arr: TOPMPackageArray;
begin
  Result := Default(TOPMPackageInfo);
  Arr := OPMSearch(AName, 1);
  if Length(Arr) > 0 then
    Result := Arr[0];
end;

{ Faz download de um pacote do OPM para o diretório destino }
function TPackageManager.OPMDownload(const APkg: TOPMPackageInfo;
  const ADestDir: string): Boolean;
var
  HTTP     : TFPHTTPClient;
  OutFile  : string;
  FS       : TFileStream;
begin
  Result := False;
  if APkg.DownloadURL = '' then Exit;

  if Assigned(FOnProgress) then
    FOnProgress(APkg.Name, 'Iniciando download...', 0);

  OutFile := IncludeTrailingPathDelimiter(ADestDir) +
    ExtractFileName(APkg.DownloadURL);

  HTTP := TFPHTTPClient.Create(nil);
  FS   := TFileStream.Create(OutFile, fmCreate);
  try
    HTTP.AllowRedirect := True;
    HTTP.ConnectTimeout := 15000;
    HTTP.IOTimeout := 30000;

    if Assigned(FOnProgress) then
      FOnProgress(APkg.Name, 'Baixando...', 50);

    HTTP.Get(APkg.DownloadURL, FS);
    Result := True;

    if Assigned(FOnProgress) then
      FOnProgress(APkg.Name, 'Download concluído', 100);
  except
    on E: Exception do
    begin
      if Assigned(FOnProgress) then
        FOnProgress(APkg.Name, 'ERRO: ' + E.Message, -1);
    end;
  end;
  FS.Free;
  HTTP.Free;
end;

{ Exporta a lista de pacotes para um arquivo de texto/JSON }
procedure TPackageManager.ExportToFile(const AFileName: string);
var
  SL  : TStringList;
  Pkg : TPackageInfo;
begin
  SL := TStringList.Create;
  try
    SL.Add('[');
    for Pkg in FPackageList do
    begin
      SL.Add('  {');
      SL.Add('    "name": "' + Pkg.Name + '",');
      SL.Add('    "version": "' + Pkg.Version + '",');
      SL.Add('    "author": "' + Pkg.Author + '",');
      SL.Add('    "lpkfile": "' + Pkg.LPKFile + '",');
      SL.Add('    "state": "' + Pkg.StateText + '"');
      SL.Add('  },');
    end;
    SL.Add(']');
    SL.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

procedure TPackageManager.ImportFromFile(const AFileName: string);
begin
  // Expansão futura: importar e reinstalar pacotes de uma lista salva
end;

end.
