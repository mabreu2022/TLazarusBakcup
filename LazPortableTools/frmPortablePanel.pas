{
  frmPortablePanel.pas - Painel dockado da IDE do Lazarus para Portable Tools
}
unit frmPortablePanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Buttons,
  uSharedPatcher;

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
  frmPortablePanel: TfrmPortablePanel;

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
begin
  BkpDir := FPortableDir + 'Backup' + PathDelim + FormatDateTime('YYYYMMDD_HHNNSS', Now) + PathDelim;
  if ForceDirectories(BkpDir) then
  begin
    LogMsg('Backup das configs criado em: ' + BkpDir);
    ShowMessage('Backup realizado em: ' + BkpDir);
  end
  else
    ShowMessage('Erro ao criar pasta de backup.');
end;

end.
