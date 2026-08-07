{
  frmPortablePanel.pas - Painel dockado da IDE do Lazarus para Portable Tools
}
unit frmPortablePanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Buttons,
  uSharedPatcher, FileUtil;

type
  { TfrmPortablePanel }
  TfrmPortablePanel = class(TForm)
    pnlHeader: TPanel;
    lblTitle: TLabel;
    lblDirInfo: TLabel;
    btnRePatch: TButton;
    btnBackup: TButton;
    memoLog: TMemo;
    lblLog: TLabel;
    procedure btnBackupClick(Sender: TObject);
    procedure btnRePatchClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FPortableDir: string;
    FConfigDir: string;
    procedure LogMsg(const AMsg: string);
  public
  end;

var
  frmPortablePanelVar: TfrmPortablePanel;

implementation

{$R *.lfm}

procedure TfrmPortablePanel.FormCreate(Sender: TObject);
begin
  memoLog.Color := 1052688;
  memoLog.Font.Color := clYellow;
  FPortableDir := IncludeTrailingPathDelimiter(ExtractFileDir(Application.ExeName));
  FConfigDir := FPortableDir + 'LazarusConfig' + PathDelim;
  lblDirInfo.Caption := 'Portable Dir: ' + FPortableDir;
  LogMsg('Painel Lazarus Portable Tools carregado.');
end;

procedure TfrmPortablePanel.LogMsg(const AMsg: string);
begin
  memoLog.Lines.Add(FormatDateTime('[hh:nn:ss] ', Now) + AMsg);
end;

procedure TfrmPortablePanel.btnRePatchClick(Sender: TObject);
begin
  LogMsg('Iniciando Re-Patch a partir da IDE...');
  if PerformPortablePatch(FPortableDir, FConfigDir, @LogMsg) then
    ShowMessage('Re-patch de configurações portáveis realizado com sucesso!')
  else
    ShowMessage('Falha ao realizar o re-patch.');
end;

procedure TfrmPortablePanel.btnBackupClick(Sender: TObject);
var
  BkpDir: string;
  ExtBkpBaseDir: string;
  TimeStamp: string;
  LocalAppDir: string;
  RoamingAppDir: string;
  LocalBackupOk, ExtBackupOk: Boolean;
begin
  TimeStamp := FormatDateTime('YYYYMMDD_HHNNSS', Now);
  BkpDir := FPortableDir + 'Backup' + PathDelim + TimeStamp + PathDelim;
  
  LogMsg('Iniciando backups das configurações...');
  
  // 1. Backup local (copia LazarusConfig)
  LocalBackupOk := False;
  if ForceDirectories(BkpDir) then
  begin
    if CopyDirTree(FConfigDir, BkpDir, [cffOverwriteFile, cffCreateDestDirectory]) then
    begin
      LogMsg('Backup local criado em: ' + BkpDir);
      LocalBackupOk := True;
    end
    else
      LogMsg('Erro ao copiar arquivos no backup local.');
  end
  else
    LogMsg('Erro ao criar pasta do backup local.');

  // 2. Backup externo (salvo fora do Lazarus, na pasta do usuário Windows)
  ExtBackupOk := False;
  ExtBkpBaseDir := IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('USERPROFILE')) + 'LazarusBackup' + PathDelim + 'Backup_' + TimeStamp + PathDelim;
  if ForceDirectories(ExtBkpBaseDir) then
  begin
    LogMsg('Criando backup externo em: ' + ExtBkpBaseDir);
    
    // Copia LazarusConfig Portável
    if DirectoryExists(FConfigDir) then
    begin
      LogMsg('  Copiando configuração portável...');
      CopyDirTree(FConfigDir, ExtBkpBaseDir + 'LazarusConfig' + PathDelim, [cffOverwriteFile, cffCreateDestDirectory]);
    end;

    // Copia LOCALAPPDATA lazarus
    LocalAppDir := IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('LOCALAPPDATA')) + 'lazarus' + PathDelim;
    if DirectoryExists(LocalAppDir) then
    begin
      LogMsg('  Copiando Lazarus de LOCALAPPDATA...');
      CopyDirTree(LocalAppDir, ExtBkpBaseDir + 'AppData_Local_Lazarus' + PathDelim, [cffOverwriteFile, cffCreateDestDirectory]);
    end;

    // Copia APPDATA lazarus (Roaming)
    RoamingAppDir := IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('APPDATA')) + 'lazarus' + PathDelim;
    if DirectoryExists(RoamingAppDir) then
    begin
      LogMsg('  Copiando Lazarus de APPDATA (Roaming)...');
      CopyDirTree(RoamingAppDir, ExtBkpBaseDir + 'AppData_Roaming_Lazarus' + PathDelim, [cffOverwriteFile, cffCreateDestDirectory]);
    end;
    
    ExtBackupOk := True;
    LogMsg('Backup externo concluído com sucesso.');
  end
  else
    LogMsg('Erro ao criar pasta do backup externo.');

  // Exibe mensagem final
  if LocalBackupOk and ExtBackupOk then
    ShowMessage('Backups realizados com sucesso!' + #13#10 +
                'Local: ' + BkpDir + #13#10 +
                'Externo: ' + ExtBkpBaseDir)
  else if LocalBackupOk then
    ShowMessage('Backup local realizado com sucesso, mas ocorreu um erro no backup externo.' + #13#10 +
                'Local: ' + BkpDir)
  else
    ShowMessage('Ocorreu um erro ao realizar os backups. Verifique o log do painel.');
end;

end.
