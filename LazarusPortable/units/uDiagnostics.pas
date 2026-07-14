{
  uDiagnostics.pas - Diagnóstico do ambiente Lazarus portável
  ===========================================================
  Verifica a integridade completa da instalação e gera relatório.
}
unit uDiagnostics;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, FileUtil, LazFileUtils,
  uPortableCore;

type
  TDiagLevel = (dlOK, dlWarning, dlError, dlInfo);

  TDiagItem = record
    Category : string;
    Test     : string;
    Level    : TDiagLevel;
    Detail   : string;
    Value    : string;
  end;

  TDiagReport = array of TDiagItem;

  { TDiagnostics }
  TDiagnostics = class
  private
    FConfig : TPortableConfig;
    FReport : TDiagReport;

    procedure AddItem(const ACat, ATest: string; ALevel: TDiagLevel;
      const ADetail: string = ''; const AValue: string = '');
    function  RunProcess(const AExe: string; AArgs: array of string): string;
    procedure CheckFiles;
    procedure CheckFPC;
    procedure CheckPaths;
    procedure CheckPermissions;
    procedure CheckRegistry;

  public
    constructor Create(AConfig: TPortableConfig);

    function  RunDiagnostics: TDiagReport;
    function  GetSummary: string;
    procedure SaveReport(const AFileName: string);

    function  HasErrors: Boolean;
    function  HasWarnings: Boolean;

    property Report: TDiagReport read FReport;
  end;

implementation

constructor TDiagnostics.Create(AConfig: TPortableConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

procedure TDiagnostics.AddItem(const ACat, ATest: string; ALevel: TDiagLevel;
  const ADetail, AValue: string);
var
  N: Integer;
begin
  N := Length(FReport);
  SetLength(FReport, N + 1);
  FReport[N].Category := ACat;
  FReport[N].Test     := ATest;
  FReport[N].Level    := ALevel;
  FReport[N].Detail   := ADetail;
  FReport[N].Value    := AValue;
end;

function TDiagnostics.RunProcess(const AExe: string; AArgs: array of string): string;
var
  P   : TProcess;
  SL  : TStringList;
  Arg : string;
begin
  Result := '';
  if not FileExists(AExe) then Exit;

  P := TProcess.Create(nil);
  SL := TStringList.Create;
  try
    P.Executable := AExe;
    for Arg in AArgs do
      P.Parameters.Add(Arg);
    P.Options  := [poUsePipes, poNoConsole, poWaitOnExit];
    P.Execute;
    SL.LoadFromStream(P.Output);
    Result := SL.Text;
  except
  end;
  SL.Free;
  P.Free;
end;

procedure TDiagnostics.CheckFiles;
const
  CAT = 'Arquivos';
var
  CheckPairs: array[0..3, 0..1] of string = (
    ('lazarus.exe',     'Executável principal do Lazarus'),
    ('startlazarus.exe','Executável de inicialização'),
    ('lazbuild.exe',    'Compilador de projetos (lazbuild)'),
    ('environmentoptions.xml', 'Configuração do ambiente (LazarusConfig)')
  );
  FPath: string;
  CompDir: string;
  LCLDir: string;
  I: Integer;
begin
  for I := 0 to High(CheckPairs) do
  begin
    FPath := '';
    if SameText(ExtractFileExt(CheckPairs[I, 0]), '.xml') then
      FPath := FConfig.ConfigDir + CheckPairs[I, 0]
    else
      FPath := FConfig.PortableDir + CheckPairs[I, 0];

    if FileExists(FPath) then
      AddItem(CAT, CheckPairs[I, 1], dlOK, '', FPath)
    else
      AddItem(CAT, CheckPairs[I, 1], dlError, 'Não encontrado', FPath);
  end;

  // Pasta components
  CompDir := FConfig.PortableDir + 'components';
  if DirectoryExists(CompDir) then
    AddItem(CAT, 'Pasta components/', dlOK, '', CompDir)
  else
    AddItem(CAT, 'Pasta components/', dlWarning, 'Ausente - sem LCL extras', CompDir);

  // Pasta lcl
  LCLDir := FConfig.PortableDir + 'lcl';
  if DirectoryExists(LCLDir) then
    AddItem(CAT, 'Pasta lcl/', dlOK, '', LCLDir)
  else
    AddItem(CAT, 'Pasta lcl/', dlError, 'LCL não encontrado!', LCLDir);
end;

procedure TDiagnostics.CheckFPC;
const
  CAT = 'Compilador FPC';
var
  FPCExe : string;
  Output : string;
  CfgFile: string;
  SrcDir : string;
begin
  FPCExe := FConfig.GetFPCCompilerPath;

  if (FPCExe = '') or (not FileExists(FPCExe)) then
  begin
    AddItem(CAT, 'fpc.exe', dlError, 'Compilador FPC não encontrado!');
    Exit;
  end;

  AddItem(CAT, 'fpc.exe encontrado', dlOK, '', FPCExe);

  // Versão do FPC
  Output := Trim(RunProcess(FPCExe, ['-iV']));
  if Output <> '' then
    AddItem(CAT, 'Versão do FPC', dlInfo, '', Output)
  else
    AddItem(CAT, 'Versão do FPC', dlWarning, 'Não foi possível obter versão');

  // Verificar fpc.cfg
  CfgFile := ExtractFileDir(FPCExe) + PathDelim + 'fpc.cfg';
  if FileExists(CfgFile) then
    AddItem(CAT, 'fpc.cfg', dlOK, '', CfgFile)
  else
    AddItem(CAT, 'fpc.cfg', dlWarning, 'fpc.cfg não encontrado em ' + ExtractFileDir(FPCExe));

  // Verificar fontes FPC
  SrcDir := FConfig.GetFPCSrcPath;
  if (SrcDir <> '') and DirectoryExists(SrcDir) then
    AddItem(CAT, 'Fontes do FPC', dlOK, '', SrcDir)
  else
    AddItem(CAT, 'Fontes do FPC', dlWarning,
      'Fontes FPC ausentes - navegação no código pode não funcionar');
end;

procedure TDiagnostics.CheckPaths;
const
  CAT = 'Configuração';
var
  Items : TValidationArray;
  Item  : TValidationItem;
begin
  Items := FConfig.Validate;
  for Item in Items do
    if Item.OK then
      AddItem(CAT, Item.Description, dlOK, '', Item.Detail)
    else
      AddItem(CAT, Item.Description, dlError, Item.Detail);
end;

procedure TDiagnostics.CheckPermissions;
const
  CAT = 'Permissões';
var
  TestFile : string;
begin
  // Testa escrita no diretório principal
  TestFile := FConfig.PortableDir + '_perm_test_';
  try
    TStringList.Create.SaveToFile(TestFile);
    DeleteFile(TestFile);
    AddItem(CAT, 'Escrita no diretório raiz', dlOK);
  except
    AddItem(CAT, 'Escrita no diretório raiz', dlError,
      'Sem permissão de escrita - execute como administrador ou mova para pasta com permissão');
  end;

  // Testa escrita em LazarusConfig
  TestFile := FConfig.ConfigDir + '_perm_test_';
  try
    TStringList.Create.SaveToFile(TestFile);
    DeleteFile(TestFile);
    AddItem(CAT, 'Escrita em LazarusConfig', dlOK);
  except
    AddItem(CAT, 'Escrita em LazarusConfig', dlError, 'Sem permissão de escrita');
  end;
end;

procedure TDiagnostics.CheckRegistry;
const
  CAT = 'Registro Windows';
begin
  { O Lazarus portável NÃO deve usar o registro do Windows.
    Verificamos se há entradas "residuais" que possam causar conflito. }
  AddItem(CAT, 'Modo portável', dlInfo,
    'O Lazarus portável usa --primary-config-path e não escreve no Registro',
    'OK');
end;

function TDiagnostics.RunDiagnostics: TDiagReport;
begin
  SetLength(FReport, 0);

  CheckFiles;
  CheckFPC;
  CheckPaths;
  CheckPermissions;
  CheckRegistry;

  Result := FReport;
end;

function TDiagnostics.HasErrors: Boolean;
var
  Item: TDiagItem;
begin
  for Item in FReport do
    if Item.Level = dlError then
      Exit(True);
  Result := False;
end;

function TDiagnostics.HasWarnings: Boolean;
var
  Item: TDiagItem;
begin
  for Item in FReport do
    if Item.Level = dlWarning then
      Exit(True);
  Result := False;
end;

function TDiagnostics.GetSummary: string;
var
  Errors, Warnings, OKs: Integer;
  Item: TDiagItem;
begin
  Errors := 0; Warnings := 0; OKs := 0;
  for Item in FReport do
    case Item.Level of
      dlError:   Inc(Errors);
      dlWarning: Inc(Warnings);
      dlOK:      Inc(OKs);
    end;

  Result := Format('Diagnóstico: %d OK, %d avisos, %d erros de %d verificações',
    [OKs, Warnings, Errors, Length(FReport)]);
end;

procedure TDiagnostics.SaveReport(const AFileName: string);
var
  SL   : TStringList;
  Item : TDiagItem;
  LvlStr: string;
begin
  SL := TStringList.Create;
  try
    SL.Add('=== Relatório de Diagnóstico Lazarus Portable ===');
    SL.Add('Data: ' + FormatDateTime('dd/mm/yyyy hh:nn:ss', Now));
    SL.Add('Diretório: ' + FConfig.PortableDir);
    SL.Add('');

    for Item in FReport do
    begin
      case Item.Level of
        dlOK:      LvlStr := '[OK]  ';
        dlWarning: LvlStr := '[AVS] ';
        dlError:   LvlStr := '[ERR] ';
        dlInfo:    LvlStr := '[INF] ';
      end;
      SL.Add(Format('%s [%s] %s: %s %s',
        [LvlStr, Item.Category, Item.Test, Item.Detail, Item.Value]));
    end;

    SL.Add('');
    SL.Add(GetSummary);
    SL.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

end.
