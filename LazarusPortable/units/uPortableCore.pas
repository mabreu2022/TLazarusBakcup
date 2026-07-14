{
  uPortableCore.pas - Núcleo do sistema de portabilidade do Lazarus
  ===================================================================
  Responsável por:
    - Detectar e validar a instalação portável
    - Fazer patch de todos os arquivos XML de configuração
    - Substituir caminhos absolutos por relativos/variáveis
    - Gerenciar backup e restauração de configurações
    - Gerenciar pasta Temp e config portável

  Autor: Gerado para TLazarusBakcup
  Lazarus 4.8 / FPC 3.2.4+ / Windows
}
unit uPortableCore;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles,
  Laz2_DOM, Laz2_XMLRead, Laz2_XMLWrite,
  FileUtil, LazFileUtils;

const
  { Diretórios padrão dentro da instalação portável }
  DIR_LAZARUS_CONFIG = 'LazarusConfig';
  DIR_TEMP           = 'Temp';
  DIR_BACKUP         = 'Backup';
  DIR_FPC            = 'fpc';

  { Arquivos de configuração que precisam de patch }
  FILE_ENV_OPTIONS    = 'environmentoptions.xml';
  FILE_PKG_FILES      = 'packagefiles.xml';
  FILE_FPC_DEFINES    = 'fpcdefines.xml';
  FILE_CODE_TEMPLATES = 'codetemplates.xml';
  FILE_PORTABLE_INI   = 'LazarusPortable.ini';

  { Variável de substituição de caminho }
  VAR_PORTABLE_DIR   = '$(PortableDir)';
  VAR_LAZARUS_DIR    = '$(LazarusDir)';
  VAR_FPC_COMPILER   = '$(FPCCompilerFilename)';
  VAR_FPC_SRC        = '$(FPCSrcDir)';

type
  TLogEvent = procedure(const AMsg: string; ALevel: Integer) of object;

  TPatchResult = record
    FileName   : string;
    Success    : Boolean;
    PatchCount : Integer;
    Error      : string;
  end;

  TPatchResultArray = array of TPatchResult;

  TValidationItem = record
    Description : string;
    OK          : Boolean;
    Detail      : string;
  end;

  TValidationArray = array of TValidationItem;

  { TPortableConfig - Configuração e estado da instalação portável }
  TPortableConfig = class
  private
    FPortableDir : string;  // Raiz da instalação portável (onde está o .exe)
    FConfigDir   : string;  // Subpasta LazarusConfig
    FTempDir     : string;  // Subpasta Temp
    FBackupDir   : string;  // Subpasta Backup
    FLazarusExe  : string;  // caminho para lazarus.exe
    FFPCDir      : string;  // caminho para pasta fpc/
    FOnLog       : TLogEvent;

    procedure Log(const AMsg: string; ALevel: Integer = 0);
    procedure PatchXMLNode(ANode: TDOMNode; const AOldBase: string);
    function  FixPath(const APath, AOldBase: string): string;
    function  IsSubPath(const APath, ABase: string): Boolean;
    procedure EnsureDirectories;
  public
    constructor Create(const APortableDir: string);

    function  GetFPCCompilerPath: string;
    function  GetFPCSrcPath: string;

    { Carrega configurações do INI portável }
    procedure LoadFromINI;
    { Salva configurações no INI portável }
    procedure SaveToINI;

    { Verificação de integridade }
    function Validate: TValidationArray;
    function IsValid: Boolean;

    { Preparação do ambiente antes de lançar }
    function BackupConfigs: Boolean;
    function RestoreBackup: Boolean;

    { Patch de todos os arquivos de configuração }
    function PatchAll: TPatchResultArray;
    function PatchEnvironmentOptions: TPatchResult;
    function PatchPackageFiles: TPatchResult;
    function PatchFPCCfg: TPatchResult;
    function PatchGenericXML(const AFileName: string): TPatchResult;

    { Helpers }
    function RelativeToPortable(const AAbsPath: string): string;
    function AbsoluteFromPortable(const ARelPath: string): string;
    function ConfigFileExists(const AFileName: string): Boolean;
    function GetConfigFilePath(const AFileName: string): string;

    { Propriedades }
    property PortableDir : string     read FPortableDir;
    property ConfigDir   : string     read FConfigDir;
    property TempDir     : string     read FTempDir;
    property BackupDir   : string     read FBackupDir;
    property LazarusExe  : string     read FLazarusExe;
    property FPCDir      : string     read FFPCDir;
    property OnLog       : TLogEvent  read FOnLog write FOnLog;
  end;

implementation

{ TPortableConfig }

constructor TPortableConfig.Create(const APortableDir: string);
begin
  inherited Create;
  FPortableDir := IncludeTrailingPathDelimiter(ExpandFileName(APortableDir));
  FConfigDir   := FPortableDir + DIR_LAZARUS_CONFIG + PathDelim;
  FTempDir     := FPortableDir + DIR_TEMP + PathDelim;
  FBackupDir   := FPortableDir + DIR_BACKUP + PathDelim;
  FFPCDir      := FPortableDir + DIR_FPC + PathDelim;
  FLazarusExe  := FPortableDir + 'lazarus.exe';
  EnsureDirectories;
end;

procedure TPortableConfig.Log(const AMsg: string; ALevel: Integer);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg, ALevel);
end;

procedure TPortableConfig.EnsureDirectories;
var
  DefaultConfigDir: string;
begin
  if not DirectoryExists(FConfigDir) then
    ForceDirectories(FConfigDir);
  if not DirectoryExists(FTempDir) then
    ForceDirectories(FTempDir);
  if not DirectoryExists(FBackupDir) then
    ForceDirectories(FBackupDir);

  // Se o environmentoptions.xml ainda não existe em LazarusConfig, importa a estrutura COMPLETA de %LOCALAPPDATA%\lazarus
  if not ConfigFileExists(FILE_ENV_OPTIONS) then
  begin
    DefaultConfigDir := GetEnvironmentVariable('LOCALAPPDATA') + PathDelim + 'lazarus' + PathDelim;
    if DirectoryExists(DefaultConfigDir) and FileExists(DefaultConfigDir + FILE_ENV_OPTIONS) then
    begin
      Log('Importando estrutura de configuração completa de ' + DefaultConfigDir + ' para ' + FConfigDir, 0);
      CopyDirTree(DefaultConfigDir, FConfigDir, [cffOverwriteFile]);
    end;
  end;
end;

function TPortableConfig.GetFPCCompilerPath: string;
var
  SR: TSearchRec;
  VerDir, BinDir: string;
begin
  Result := '';

  // 1. Diretórios diretos padrão
  BinDir := FFPCDir + 'bin' + PathDelim + 'x86_64-win64' + PathDelim + 'fpc.exe';
  if FileExists(BinDir) then Exit(BinDir);

  BinDir := FFPCDir + 'bin' + PathDelim + 'i386-win32' + PathDelim + 'fpc.exe';
  if FileExists(BinDir) then Exit(BinDir);

  // 2. Subdiretórios de versão no formato fpc\<versao>\bin\<arquitetura>\fpc.exe
  if FindFirst(FFPCDir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
      begin
        VerDir := FFPCDir + SR.Name + PathDelim;

        BinDir := VerDir + 'bin' + PathDelim + 'i386-win32' + PathDelim + 'fpc.exe';
        if FileExists(BinDir) then Exit(BinDir);

        BinDir := VerDir + 'bin' + PathDelim + 'x86_64-win64' + PathDelim + 'fpc.exe';
        if FileExists(BinDir) then Exit(BinDir);

        BinDir := VerDir + 'bin' + PathDelim + 'fpc.exe';
        if FileExists(BinDir) then Exit(BinDir);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  // 3. Fallback para PATH do sistema
  Result := FindDefaultExecutablePath('fpc.exe');
end;

function TPortableConfig.GetFPCSrcPath: string;
var
  SR: TSearchRec;
  VerDir: string;
begin
  Result := FFPCDir + 'src' + PathDelim;
  if DirectoryExists(Result) then Exit;

  Result := FFPCDir + 'source' + PathDelim;
  if DirectoryExists(Result) then Exit;

  // Procura em subdiretórios de versão (ex: fpc\3.2.2\src\ ou fpc\3.2.2\source\)
  if FindFirst(FFPCDir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
      begin
        VerDir := FFPCDir + SR.Name + PathDelim;
        if DirectoryExists(VerDir + 'src' + PathDelim) then
          Exit(VerDir + 'src' + PathDelim);
        if DirectoryExists(VerDir + 'fpcsrc' + PathDelim) then
          Exit(VerDir + 'fpcsrc' + PathDelim);
        if DirectoryExists(VerDir + 'source' + PathDelim) then
          Exit(VerDir + 'source' + PathDelim);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  Result := '';
end;

function TPortableConfig.IsSubPath(const APath, ABase: string): Boolean;
var
  P, B: string;
begin
  P := IncludeTrailingPathDelimiter(LowerCase(ExpandFileName(APath)));
  B := IncludeTrailingPathDelimiter(LowerCase(ExpandFileName(ABase)));
  Result := Copy(P, 1, Length(B)) = B;
end;

function TPortableConfig.FixPath(const APath, AOldBase: string): string;
var
  CleanOldBase, CleanPortableDir, CleanPath, Rel: string;
begin
  Result := APath;
  if APath = '' then Exit;

  CleanPortableDir := IncludeTrailingPathDelimiter(ExpandFileName(FPortableDir));

  // Se o caminho contém a variável $(PortableDir), expande para o diretório atual
  if Pos(VAR_PORTABLE_DIR, APath) = 1 then
  begin
    Rel := Copy(APath, Length(VAR_PORTABLE_DIR) + 1, Length(APath));
    if (Rel <> '') and (Rel[1] in ['\', '/']) then Delete(Rel, 1, 1);
    Result := CleanPortableDir + Rel;
    Log('  Patch (macro->dir): ' + APath + ' → ' + Result, 0);
    Exit;
  end;

  // Apenas processa se for um caminho absoluto real (ex: C:\... ou D:\...)
  if not FilenameIsAbsolute(APath) then Exit;

  CleanPath := ExpandFileName(APath);

  // Se o caminho já está no diretório portável atual, não mexe
  if IsSubPath(CleanPath, CleanPortableDir) then Exit;

  // Se apontava para um diretório antigo de instalação (diferente da pasta atual)
  if AOldBase <> '' then
  begin
    CleanOldBase := IncludeTrailingPathDelimiter(ExpandFileName(AOldBase));
    if (CleanOldBase <> CleanPortableDir) and IsSubPath(CleanPath, CleanOldBase) then
    begin
      Rel := ExtractRelativePath(CleanOldBase, CleanPath);
      Result := CleanPortableDir + Rel;
      Log('  Patch (oldbase->actual): ' + APath + ' → ' + Result, 0);
      Exit;
    end;
  end;
end;

procedure TPortableConfig.PatchXMLNode(ANode: TDOMNode; const AOldBase: string);
var
  I       : Integer;
  Child   : TDOMNode;
  Attr    : TDOMNode;
  NewVal  : string;
  PathKeys: array of string;
  Key     : string;
begin
  // Atributos que contêm caminhos de arquivo/diretório
  PathKeys := ['Value', 'Directory', 'Filename', 'Path',
               'LazarusDirectory', 'CompilerFilename', 'FPCSourceDir',
               'FileName', 'Dir'];

  if ANode.HasAttributes then
    for I := 0 to Length(PathKeys) - 1 do
    begin
      Key  := PathKeys[I];
      Attr := ANode.Attributes.GetNamedItem(Key);
      if Attr <> nil then
      begin
        NewVal := FixPath(Attr.TextContent, AOldBase);
        if NewVal <> Attr.TextContent then
          Attr.TextContent := NewVal;
      end;
    end;

  // Processa filhos recursivamente
  Child := ANode.FirstChild;
  while Child <> nil do
  begin
    PatchXMLNode(Child, AOldBase);
    Child := Child.NextSibling;
  end;
end;

{ Verifica se a instalação portável está íntegra }
function TPortableConfig.Validate: TValidationArray;
var
  TestFile: string;

  procedure AddItem(var Arr: TValidationArray; const ADesc: string;
    AOK: Boolean; const ADetail: string = '');
  var
    N: Integer;
  begin
    N := Length(Arr);
    SetLength(Arr, N + 1);
    Arr[N].Description := ADesc;
    Arr[N].OK          := AOK;
    Arr[N].Detail      := ADetail;
  end;

begin
  Result := nil;
  SetLength(Result, 0);

  AddItem(Result, 'Diretório portável encontrado',
    DirectoryExists(FPortableDir), FPortableDir);

  AddItem(Result, 'lazarus.exe encontrado',
    FileExists(FLazarusExe), FLazarusExe);

  AddItem(Result, 'startlazarus.exe encontrado',
    FileExists(FPortableDir + 'startlazarus.exe'));

  AddItem(Result, 'Pasta FPC encontrada',
    DirectoryExists(FFPCDir), FFPCDir);

  AddItem(Result, 'Compilador FPC encontrado',
    FileExists(GetFPCCompilerPath), GetFPCCompilerPath);

  AddItem(Result, 'Pasta LazarusConfig encontrada',
    DirectoryExists(FConfigDir), FConfigDir);

  AddItem(Result, 'environmentoptions.xml presente',
    ConfigFileExists(FILE_ENV_OPTIONS));

  AddItem(Result, 'packagefiles.xml presente',
    ConfigFileExists(FILE_PKG_FILES));

  AddItem(Result, 'Pasta Temp criada',
    DirectoryExists(FTempDir), FTempDir);

  { Verifica permissão de escrita no diretório de config }
  try
    TestFile := FConfigDir + '_write_test_';
    TStringList.Create.SaveToFile(TestFile);
    DeleteFile(TestFile);
    AddItem(Result, 'Permissão de escrita em LazarusConfig', True);
  except
    AddItem(Result, 'Permissão de escrita em LazarusConfig', False,
      'Sem permissão de escrita!');
  end;
end;

function TPortableConfig.IsValid: Boolean;
var
  Items: TValidationArray;
  Item : TValidationItem;
begin
  Items  := Validate;
  Result := True;
  for Item in Items do
    if not Item.OK then
    begin
      Result := False;
      Break;
    end;
end;

{ Faz backup de todos os arquivos de config antes de patchear }
function TPortableConfig.BackupConfigs: Boolean;
var
  TimeStamp  : string;
  BkpSubDir  : string;
  SR         : TSearchRec;
  SrcFile    : string;
  DstFile    : string;
begin
  Result    := False;
  TimeStamp := FormatDateTime('YYYYMMDD_HHMMSS', Now);
  BkpSubDir := FBackupDir + TimeStamp + PathDelim;

  if not ForceDirectories(BkpSubDir) then
  begin
    Log('ERRO: Não foi possível criar diretório de backup: ' + BkpSubDir, 2);
    Exit;
  end;

  Log('Iniciando backup em: ' + BkpSubDir, 0);

  // Copia todos os arquivos XML e CFG da pasta de config
  if FindFirst(FConfigDir + '*.*', faAnyFile - faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        SrcFile := FConfigDir + SR.Name;
        DstFile := BkpSubDir + SR.Name;
        if not CopyFile(SrcFile, DstFile) then
          Log('  Aviso: Não copiou ' + SR.Name, 1)
        else
          Log('  Backup: ' + SR.Name, 0);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  Result := True;
  Log('Backup concluído.', 0);
end;

{ Restaura o backup mais recente }
function TPortableConfig.RestoreBackup: Boolean;
var
  SR        : TSearchRec;
  LastDir   : string;
  SrcFile   : string;
  DstFile   : string;
begin
  Result  := False;
  LastDir := '';

  // Encontra o backup mais recente (ordenado por nome = timestamp)
  if FindFirst(FBackupDir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and
         (SR.Attr and faDirectory <> 0) then
        if SR.Name > LastDir then
          LastDir := SR.Name;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  if LastDir = '' then
  begin
    Log('Nenhum backup encontrado.', 1);
    Exit;
  end;

  LastDir := FBackupDir + LastDir + PathDelim;
  Log('Restaurando backup de: ' + LastDir, 0);

  if FindFirst(LastDir + '*.*', faAnyFile - faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        SrcFile := LastDir + SR.Name;
        DstFile := FConfigDir + SR.Name;
        if CopyFile(SrcFile, DstFile) then
          Log('  Restaurado: ' + SR.Name, 0)
        else
          Log('  ERRO ao restaurar: ' + SR.Name, 2);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  Result := True;
  Log('Restauração concluída.', 0);
end;

{ Patch do environmentoptions.xml — arquivo principal de configuração }
function TPortableConfig.PatchEnvironmentOptions: TPatchResult;
var
  XMLDoc    : TXMLDocument;
  RootNode  : TDOMNode;
  EnvNode   : TDOMNode;
  Node      : TDOMNode;
  Attr      : TDOMAttr;
  FilePath  : string;
  OldLazDir : string;
  NewPath   : string;
  SrcPath   : string;
begin
  Result.FileName   := FILE_ENV_OPTIONS;
  Result.Success    := False;
  Result.PatchCount := 0;
  Result.Error      := '';

  FilePath := GetConfigFilePath(FILE_ENV_OPTIONS);
  if not FileExists(FilePath) then
  begin
    Result.Error := 'Arquivo não encontrado: ' + FilePath;
    Log('ERRO: ' + Result.Error, 2);
    Exit;
  end;

  XMLDoc := nil;
  try
    Log('Patchando ' + FILE_ENV_OPTIONS + '...', 0);
    ReadXMLFile(XMLDoc, FilePath);

    RootNode := XMLDoc.DocumentElement;
    EnvNode  := RootNode.FindNode('EnvironmentOptions');
    if EnvNode = nil then
      EnvNode := RootNode; // Alguns layouts têm EnvironmentOptions como raiz

    // --- LazarusDirectory ---
    Node := EnvNode.FindNode('LazarusDirectory');
    if Node <> nil then
    begin
      Attr := TDOMAttr(Node.Attributes.GetNamedItem('Value'));
      if Attr <> nil then
      begin
        OldLazDir := IncludeTrailingPathDelimiter(Attr.Value); // guarda o diretório antigo para FixPath
        Attr.Value := FPortableDir;
        Inc(Result.PatchCount);
        Log('  LazarusDirectory → ' + FPortableDir, 0);
      end;
    end;

    // --- CompilerFilename ---
    Node := EnvNode.FindNode('CompilerFilename');
    if Node <> nil then
    begin
      Attr := TDOMAttr(Node.Attributes.GetNamedItem('Value'));
      if (Attr <> nil) and (Attr.Value <> '') then
      begin
        NewPath := GetFPCCompilerPath;
        if NewPath <> '' then
        begin
          Attr.Value := NewPath;
          Inc(Result.PatchCount);
          Log('  CompilerFilename → ' + NewPath, 0);
        end;
      end;
    end;

    // --- FPCSourceDir ---
    Node := EnvNode.FindNode('FPCSourceDir');
    if Node <> nil then
    begin
      Attr := TDOMAttr(Node.Attributes.GetNamedItem('Value'));
      if Attr <> nil then
      begin
        SrcPath := GetFPCSrcPath;
        if SrcPath <> '' then
        begin
          Attr.Value := SrcPath;
          Inc(Result.PatchCount);
          Log('  FPCSourceDir → ' + SrcPath, 0);
        end;
      end;
    end;

    // --- TestBuildDir (pasta de compilação temp) ---
    Node := EnvNode.FindNode('TestBuildDir');
    if Node <> nil then
    begin
      Attr := TDOMAttr(Node.Attributes.GetNamedItem('Value'));
      if Attr <> nil then
      begin
        Attr.Value := FTempDir;
        Inc(Result.PatchCount);
        Log('  TestBuildDir → ' + FTempDir, 0);
      end;
    end;

    // --- Patch genérico em nós restantes ---
    PatchXMLNode(RootNode, OldLazDir);

    WriteXMLFile(XMLDoc, FilePath);
    Result.Success := True;
    Log(FILE_ENV_OPTIONS + ' OK (' + IntToStr(Result.PatchCount) + ' patches)', 0);

  except
    on E: Exception do
    begin
      Result.Error := E.Message;
      Log('ERRO em ' + FILE_ENV_OPTIONS + ': ' + E.Message, 2);
    end;
  end;

  if Assigned(XMLDoc) then
    XMLDoc.Free;
end;

{ Patch do packagefiles.xml — lista de pacotes instalados }
function TPortableConfig.PatchPackageFiles: TPatchResult;
begin
  Result := PatchGenericXML(FILE_PKG_FILES);
end;

{ Patch genérico para qualquer XML da pasta de config }
function TPortableConfig.PatchGenericXML(const AFileName: string): TPatchResult;
var
  XMLDoc   : TXMLDocument;
  FilePath : string;
begin
  Result.FileName   := AFileName;
  Result.Success    := False;
  Result.PatchCount := 0;
  Result.Error      := '';

  FilePath := GetConfigFilePath(AFileName);
  if not FileExists(FilePath) then
  begin
    Result.Error := 'Arquivo não encontrado (ignorado): ' + FilePath;
    Result.Success := True; // Não é erro crítico
    Exit;
  end;

  XMLDoc := nil;
  try
    Log('Patchando ' + AFileName + '...', 0);
    ReadXMLFile(XMLDoc, FilePath);
    PatchXMLNode(XMLDoc.DocumentElement, '');
    WriteXMLFile(XMLDoc, FilePath);
    Result.Success := True;
    Log(AFileName + ' OK', 0);
  except
    on E: Exception do
    begin
      Result.Error := E.Message;
      Log('ERRO em ' + AFileName + ': ' + E.Message, 2);
    end;
  end;

  if Assigned(XMLDoc) then
    XMLDoc.Free;
end;

{ Patch do fpc.cfg — configuração do compilador FPC }
function TPortableConfig.PatchFPCCfg: TPatchResult;
var
  CfgFile   : string;
  Lines     : TStringList;
  I         : Integer;
  Line      : string;
  NewLine   : string;
  FPCBinDir : string;
begin
  Result.FileName   := 'fpc.cfg';
  Result.Success    := False;
  Result.PatchCount := 0;
  Result.Error      := '';

  // fpc.cfg fica dentro da pasta do compilador FPC, não no LazarusConfig
  FPCBinDir := ExtractFileDir(GetFPCCompilerPath);
  CfgFile := FPCBinDir + PathDelim + 'fpc.cfg';

  if not FileExists(CfgFile) then
  begin
    // Tenta a localização alternativa
    CfgFile := FFPCDir + 'bin' + PathDelim + 'fpc.cfg';
    if not FileExists(CfgFile) then
    begin
      Result.Error   := 'fpc.cfg não encontrado';
      Result.Success := True; // Não crítico
      Exit;
    end;
  end;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(CfgFile);
    for I := 0 to Lines.Count - 1 do
    begin
      Line    := Lines[I];
      NewLine := StringReplace(Line, '%LAZARUSDIR%', FPortableDir,
        [rfReplaceAll, rfIgnoreCase]);
      NewLine := StringReplace(NewLine, '%PORTABLEDIR%', FPortableDir,
        [rfReplaceAll, rfIgnoreCase]);
      if NewLine <> Line then
      begin
        Lines[I] := NewLine;
        Inc(Result.PatchCount);
      end;
    end;
    Lines.SaveToFile(CfgFile);
    Result.Success := True;
    Log('fpc.cfg OK (' + IntToStr(Result.PatchCount) + ' patches)', 0);
  except
    on E: Exception do
    begin
      Result.Error := E.Message;
      Log('ERRO em fpc.cfg: ' + E.Message, 2);
    end;
  end;
  Lines.Free;
end;

{ Executa patch em todos os arquivos de configuração }
function TPortableConfig.PatchAll: TPatchResultArray;
var
  SR     : TSearchRec;
  I      : Integer;
  XF     : string;
  Res    : TPatchResult;
  AlreadyPatched: Boolean;
  XmlFiles: array[0..5] of string = (
    FILE_FPC_DEFINES, FILE_CODE_TEMPLATES,
    'editoroptions.xml', 'codetools.xml',
    'projectsessionoptions.xml', 'lazarusbuild.xml'
  );
begin
  Result := nil;
  SetLength(Result, 0);

  Log('=== Iniciando PatchAll ===', 0);

  // 1. Patch principal do environmentoptions.xml
  I := Length(Result);
  SetLength(Result, I + 1);
  Result[I] := PatchEnvironmentOptions;

  // 2. Patch de packagefiles.xml
  I := Length(Result);
  SetLength(Result, I + 1);
  Result[I] := PatchPackageFiles;

  // 3. Patch genérico de todos os outros XMLs
  for XF in XmlFiles do
    if ConfigFileExists(XF) then
    begin
      I := Length(Result);
      SetLength(Result, I + 1);
      Result[I] := PatchGenericXML(XF);
    end;

  // 4. Procura qualquer XML adicional na pasta de config
  if FindFirst(FConfigDir + '*.xml', faAnyFile - faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> FILE_ENV_OPTIONS) and
         (SR.Name <> FILE_PKG_FILES) and
         (SR.Name <> FILE_FPC_DEFINES) and
         (SR.Name <> FILE_CODE_TEMPLATES) then
      begin
        AlreadyPatched := False;
        for Res in Result do
          if SameText(Res.FileName, SR.Name) then
          begin
            AlreadyPatched := True;
            Break;
          end;
        if not AlreadyPatched then
        begin
          I := Length(Result);
          SetLength(Result, I + 1);
          Result[I] := PatchGenericXML(SR.Name);
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  // 5. Patch do fpc.cfg
  I := Length(Result);
  SetLength(Result, I + 1);
  Result[I] := PatchFPCCfg;

  Log('=== PatchAll concluído: ' + IntToStr(Length(Result)) + ' arquivos ===', 0);
end;

{ Converte caminho absoluto em relativo ao diretório portável }
function TPortableConfig.RelativeToPortable(const AAbsPath: string): string;
begin
  if IsSubPath(AAbsPath, FPortableDir) then
    Result := ExtractRelativePath(FPortableDir, AAbsPath)
  else
    Result := AAbsPath;
end;

function TPortableConfig.AbsoluteFromPortable(const ARelPath: string): string;
begin
  if not FilenameIsAbsolute(ARelPath) then
    Result := FPortableDir + ARelPath
  else
    Result := ARelPath;
end;

function TPortableConfig.ConfigFileExists(const AFileName: string): Boolean;
begin
  Result := FileExists(FConfigDir + AFileName);
end;

function TPortableConfig.GetConfigFilePath(const AFileName: string): string;
begin
  Result := FConfigDir + AFileName;
end;

procedure TPortableConfig.LoadFromINI;
var
  INI: TIniFile;
begin
  INI := TIniFile.Create(FPortableDir + FILE_PORTABLE_INI);
  try
    // Nada ainda — expansão futura para persistência de configurações do launcher
  finally
    INI.Free;
  end;
end;

procedure TPortableConfig.SaveToINI;
var
  INI: TIniFile;
begin
  INI := TIniFile.Create(FPortableDir + FILE_PORTABLE_INI);
  try
    INI.WriteString('Launcher', 'PortableDir', FPortableDir);
    INI.WriteString('Launcher', 'Version', '2.0');
  finally
    INI.Free;
  end;
end;

end.
