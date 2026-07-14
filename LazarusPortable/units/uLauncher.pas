{
  uLauncher.pas - Lançamento do Lazarus em modo portável
  ======================================================
  Orquestra todo o processo de inicialização:
  1. Backup das configs
  2. Patch dos XMLs
  3. Lança o Lazarus com --primary-config-path
  4. Aguarda fechamento (opcional)
  5. Restaura (opcional)
}
unit uLauncher;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, Windows,
  uPortableCore;

type
  TLaunchEvent   = procedure(const AMsg: string) of object;
  TLaunchOptions = record
    WaitForClose  : Boolean;  // Aguarda Lazarus fechar
    RestoreOnClose: Boolean;  // Restaura backup ao fechar
    DoBackup      : Boolean;  // Faz backup antes de patchear
    ExtraArgs     : string;   // Args adicionais para o lazarus.exe
  end;

  TLaunchResult = record
    Success   : Boolean;
    ExitCode  : Integer;
    ErrorMsg  : string;
    PatchCount: Integer;
  end;

  { TLauncher }
  TLauncher = class
  private
    FConfig  : TPortableConfig;
    FOnLog   : TLaunchEvent;
    FProcess : TProcess;

    procedure Log(const AMsg: string);
  public
    constructor Create(AConfig: TPortableConfig);
    destructor  Destroy; override;

    function  Launch(const AOpts: TLaunchOptions): TLaunchResult;
    procedure Terminate;

    property OnLog   : TLaunchEvent  read FOnLog   write FOnLog;
  end;

function DefaultLaunchOptions: TLaunchOptions;

implementation

function DefaultLaunchOptions: TLaunchOptions;
begin
  Result.WaitForClose   := False;
  Result.RestoreOnClose := False;
  Result.DoBackup       := True;
  Result.ExtraArgs      := '';
end;

constructor TLauncher.Create(AConfig: TPortableConfig);
begin
  inherited Create;
  FConfig  := AConfig;
  FProcess := nil;
end;

destructor TLauncher.Destroy;
begin
  FProcess.Free;
  inherited Destroy;
end;

procedure TLauncher.Log(const AMsg: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMsg);
end;

function TLauncher.Launch(const AOpts: TLaunchOptions): TLaunchResult;
var
  PatchResults : TPatchResultArray;
  Pr           : TPatchResult;
  PatchErrors  : Integer;
  LazArgs      : string;
  Parts        : TStringArray;
  P            : string;
begin
  Result.Success    := False;
  Result.ExitCode   := -1;
  Result.ErrorMsg   := '';
  Result.PatchCount := 0;
  PatchErrors       := 0;

  // 1. Valida instalação
  Log('Verificando instalação...');
  if not FConfig.IsValid then
  begin
    Result.ErrorMsg := 'Instalação inválida. Execute o Diagnóstico para mais detalhes.';
    Log('ERRO: ' + Result.ErrorMsg);
    Exit;
  end;
  Log('OK - Instalação válida.');

  // 2. Backup
  if AOpts.DoBackup then
  begin
    Log('Fazendo backup das configurações...');
    if not FConfig.BackupConfigs then
      Log('AVISO: Não foi possível fazer backup. Continuando...')
    else
      Log('Backup concluído.');
  end;

  // 3. Patch de todos os XMLs
  Log('Aplicando patches nas configurações...');
  PatchResults := FConfig.PatchAll;

  for Pr in PatchResults do
  begin
    Inc(Result.PatchCount, Pr.PatchCount);
    if not Pr.Success then
    begin
      Inc(PatchErrors);
      Log('AVISO: Erro ao patchear ' + Pr.FileName + ': ' + Pr.Error);
    end;
  end;

  Log(Format('Patches aplicados: %d substituições em %d arquivos (%d erros)',
    [Result.PatchCount, Length(PatchResults), PatchErrors]));

  // 4. Monta o comando do Lazarus
  // Usa --primary-config-path para apontar a config portável
  LazArgs := '--primary-config-path="' + FConfig.ConfigDir + '"';
  if AOpts.ExtraArgs <> '' then
    LazArgs := LazArgs + ' ' + AOpts.ExtraArgs;

  Log('Lançando: ' + FConfig.LazarusExe);
  Log('Argumentos: ' + LazArgs);

  // 5. Inicia o processo
  FreeAndNil(FProcess);
  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := FConfig.LazarusExe;
    FProcess.Parameters.Add('--primary-config-path=' + FConfig.ConfigDir);

    if AOpts.ExtraArgs <> '' then
    begin
      // Divide os argumentos extras
      Parts := AOpts.ExtraArgs.Split([' ']);
      for P in Parts do
        if Trim(P) <> '' then
          FProcess.Parameters.Add(Trim(P));
    end;

    FProcess.Options := [poNoConsole];
    if AOpts.WaitForClose then
      FProcess.Options := FProcess.Options + [poWaitOnExit];

    FProcess.CurrentDirectory := FConfig.PortableDir;
    FProcess.Execute;

    Log('Lazarus iniciado com PID: ' + IntToStr(FProcess.ProcessID));
    Result.Success := True;

    // 6. Aguarda fechamento se solicitado
    if AOpts.WaitForClose then
    begin
      Log('Aguardando fechamento do Lazarus...');
      Result.ExitCode := FProcess.ExitCode;
      Log('Lazarus encerrado com código: ' + IntToStr(Result.ExitCode));

      // 7. Restaura backup se configurado
      if AOpts.RestoreOnClose then
      begin
        Log('Restaurando backup das configurações...');
        FConfig.RestoreBackup;
        Log('Restauração concluída.');
      end;
    end;

  except
    on E: Exception do
    begin
      Result.Success  := False;
      Result.ErrorMsg := E.Message;
      Log('ERRO ao lançar Lazarus: ' + E.Message);
    end;
  end;
end;

procedure TLauncher.Terminate;
begin
  if Assigned(FProcess) and FProcess.Running then
    FProcess.Terminate(0);
end;

end.
