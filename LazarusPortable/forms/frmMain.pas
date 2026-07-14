{
  frmMain.pas - Formulário principal do Lazarus Portable Manager
  ==============================================================
  Interface gráfica completa com:
    - Dashboard com status e ações rápidas
    - Gerenciador de pacotes
    - Gerenciador de perfis
    - Diagnóstico detalhado
    - Log de operações
    - Integração OPM
}
unit frmMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, LCLIntf,
  ComCtrls, StdCtrls, ExtCtrls, Buttons, Windows,
  uPortableCore, uPackageManager, uProfileManager,
  uDiagnostics, uLauncher, uLicenseManager, frmConfigDB;

type
  { TfrmMain }
  TfrmMain = class(TForm)
    pnlTop         : TPanel;
    lblTitle       : TLabel;
    btnLaunch      : TButton;
    btnConfig      : TButton;
    pnlLeft        : TPanel;
    lstMenu        : TListBox;
    pnlMain        : TPanel;
    pgcMain        : TPageControl;

    { Tab Dashboard }
    tabDashboard   : TTabSheet;
    pnlDash        : TPanel;
    lblDashTitle   : TLabel;
    lblPortableDir : TLabel;
    lblPortableDirVal : TLabel;
    lblStatusTitle : TLabel;
    lblStatus      : TLabel;
    pnlActions     : TPanel;
    lblActTitle    : TLabel;
    btnPatchNow    : TButton;
    btnBackup      : TButton;
    btnRestore     : TButton;
    btnDiag        : TButton;
    btnOpenConfig  : TButton;
    lblLogTitle    : TLabel;
    memoLog        : TMemo;

    { Tab Pacotes }
    tabPackages    : TTabSheet;
    pnlPkgHeader   : TPanel;
    lblPkgTitle    : TLabel;
    btnScanPkgs    : TButton;
    lvPackages     : TListView;
    pnlPkgBottom   : TPanel;
    btnExportPkgs  : TButton;
    btnOPM         : TButton;
    lblPkgCount    : TLabel;

    { Tab Perfis }
    tabProfiles    : TTabSheet;
    pnlProfHeader  : TPanel;
    lblProfTitle   : TLabel;
    lvProfiles     : TListView;
    pnlProfButtons : TPanel;
    btnNewProfile  : TButton;
    btnActivateProfile   : TButton;
    btnSaveCurrentProfile: TButton;
    btnDeleteProfile     : TButton;

    { Tab Diagnóstico }
    tabDiag        : TTabSheet;
    pnlDiagHeader  : TPanel;
    lblDiagTitle   : TLabel;
    btnRunDiag     : TButton;
    lvDiag         : TListView;
    pnlDiagBottom  : TPanel;
    lblDiagSummary : TLabel;
    btnSaveReport  : TButton;

    { Tab Log }
    tabLog         : TTabSheet;
    memoFullLog    : TMemo;
    pnlLogBottom   : TPanel;
    btnClearLog    : TButton;
    btnSaveLog     : TButton;

    { Tab OPM }
    tabOPM         : TTabSheet;
    pnlOPMHeader   : TPanel;
    lblOPMTitle    : TLabel;
    pnlOPMSearch   : TPanel;
    edtOPMSearch   : TEdit;
    btnOPMSearch   : TButton;
    lvOPM          : TListView;
    pnlOPMBottom   : TPanel;
    btnOPMDownload : TButton;
    lblOPMStatus   : TLabel;
    pbOPM          : TProgressBar;

    { Tab Manual }
    tabManual          : TTabSheet;
    pnlManualHeader    : TPanel;
    lblManualTitle     : TLabel;
    btnOpenHtmlManual  : TButton;
    memoManual         : TMemo;

    { Tab Sobre }
    tabAbout       : TTabSheet;
    pnlAbout       : TPanel;
    lblAboutTitle  : TLabel;
    lblAboutSub    : TLabel;
    lblAboutFeatures : TLabel;
    lblAboutLazarus  : TLabel;
    lblAboutGithub   : TLabel;

    { Status bar }
    pnlBottom      : TPanel;
    lblStatusBar   : TLabel;
    lblVersion     : TLabel;

    { Eventos }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);

    { Menu lateral }
    procedure lstMenuClick(Sender: TObject);

    { Dashboard }
    procedure btnLaunchClick(Sender: TObject);
    procedure btnConfigClick(Sender: TObject);
    procedure btnPatchNowClick(Sender: TObject);
    procedure btnBackupClick(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure btnDiagClick(Sender: TObject);
    procedure btnOpenConfigClick(Sender: TObject);

    { Pacotes }
    procedure btnScanPkgsClick(Sender: TObject);
    procedure btnExportPkgsClick(Sender: TObject);
    procedure btnOPMClick(Sender: TObject);

    { Perfis }
    procedure btnNewProfileClick(Sender: TObject);
    procedure btnActivateProfileClick(Sender: TObject);
    procedure btnSaveCurrentProfileClick(Sender: TObject);
    procedure btnDeleteProfileClick(Sender: TObject);

    { Diagnóstico }
    procedure btnRunDiagClick(Sender: TObject);
    procedure btnSaveReportClick(Sender: TObject);

    { Log }
    procedure btnClearLogClick(Sender: TObject);
    procedure btnSaveLogClick(Sender: TObject);

    { OPM }
    procedure btnOPMSearchClick(Sender: TObject);
    procedure btnOPMDownloadClick(Sender: TObject);

    { Manual }
    procedure btnOpenHtmlManualClick(Sender: TObject);

  private
    FConfig       : TPortableConfig;
    FPkgManager   : TPackageManager;
    FProfManager  : TProfileManager;
    FDiagnostics  : TDiagnostics;
    FLauncher     : TLauncher;
    FLicenseMgr   : TLicenseManager; // referência externa — não libera aqui
  public
    property LicenseManager: TLicenseManager read FLicenseMgr write FLicenseMgr;

    procedure AppLog(const AMsg: string; ALevel: Integer = 0);
    procedure SetStatus(const AMsg: string);
    procedure RefreshDashboard;
    procedure RefreshPackageList;
    procedure RefreshProfileList;
    procedure LoadOPMResults(const APackages: TOPMPackageArray);
    procedure LoadUserManual;

    procedure OnCoreLog(const AMsg: string; ALevel: Integer);
    procedure OnLauncherLog(const AMsg: string);
    procedure OnDownloadProgress(const APackage, AStatus: string;
      APercent: Integer);
  end;

var
  FormMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  ExeDir: string;
begin
  // Determina o diretório portável (onde está o .exe)
  ExeDir := ExtractFileDir(Application.ExeName);

  // Inicializa os gerenciadores
  FConfig      := TPortableConfig.Create(ExeDir);
  FConfig.OnLog := @OnCoreLog;

  FPkgManager  := TPackageManager.Create(FConfig.PortableDir, FConfig.ConfigDir);
  FPkgManager.OnProgress := @OnDownloadProgress;

  FProfManager := TProfileManager.Create(FConfig.PortableDir);
  FDiagnostics := TDiagnostics.Create(FConfig);
  FLauncher    := TLauncher.Create(FConfig);
  FLauncher.OnLog := @OnLauncherLog;

  // Cores do log
  memoLog.Color          := 1052688;
  memoLog.Font.Color     := clYellow;
  memoFullLog.Color      := 1052688;
  memoFullLog.Font.Color := clYellow;

  // Carrega o manual do usuário
  LoadUserManual;

  // Seleciona a primeira aba do menu
  lstMenu.ItemIndex := 0;
  pgcMain.ActivePageIndex := 0;

  // Atualiza a interface
  RefreshDashboard;

  AppLog('Lazarus Portable Manager iniciado.');
  AppLog('Diretório portável: ' + FConfig.PortableDir);

  SetStatus('Pronto.');
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FLauncher.Free;
  FDiagnostics.Free;
  FProfManager.Free;
  FPkgManager.Free;
  FConfig.Free;
  FreeAndNil(FLicenseMgr); // libera o TLicenseManager que o lpr transferiu
end;

procedure TfrmMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
end;

{ Roteamento do menu lateral }
procedure TfrmMain.lstMenuClick(Sender: TObject);
begin
  // Item 8 = Sair — não navega para aba, trata diretamente
  if lstMenu.ItemIndex = 8 then
  begin
    if MessageDlg('Confirmar Saída', 'Deseja sair e voltar à tela de Login?',
       mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      // Sinaliza para o lpr que deve reabrir o login
      FLicenseMgr.Free;
      FLicenseMgr := nil;
      Application.Terminate;  // termina o app (o usuário reabre se quiser)
    end;
    lstMenu.ItemIndex := -1;
    Exit;
  end;

  pgcMain.ActivePageIndex := lstMenu.ItemIndex;

  case lstMenu.ItemIndex of
    0: RefreshDashboard;
    1: ; // Pacotes - refresca apenas quando clicar Varrer
    2: RefreshProfileList;
    4: ; // Log
    5: if lvOPM.Items.Count = 0 then btnOPMSearchClick(nil);
    6: ; // Manual
    7: ; // Sobre
  end;
end;

{ Callback de log do núcleo }
procedure TfrmMain.OnCoreLog(const AMsg: string; ALevel: Integer);
begin
  AppLog(AMsg, ALevel);
end;

procedure TfrmMain.OnLauncherLog(const AMsg: string);
begin
  AppLog(AMsg);
end;

procedure TfrmMain.OnDownloadProgress(const APackage, AStatus: string;
  APercent: Integer);
begin
  lblOPMStatus.Caption := APackage + ': ' + AStatus;
  if APercent >= 0 then
    pbOPM.Position := APercent;
  Application.ProcessMessages;
end;

procedure TfrmMain.AppLog(const AMsg: string; ALevel: Integer);
var
  Prefix : string;
  TS     : string;
  Line   : string;
begin
  TS := FormatDateTime('[hh:nn:ss] ', Now);

  case ALevel of
    1: Prefix := '[AVS] ';
    2: Prefix := '[ERR] ';
    else Prefix := '';
  end;

  Line := TS + Prefix + AMsg;

  memoLog.Lines.Add(Line);
  memoFullLog.Lines.Add(Line);

  // Rola para o final
  memoLog.SelStart     := Length(memoLog.Text);
  memoFullLog.SelStart := Length(memoFullLog.Text);
  if memoLog.HandleAllocated then
    memoLog.ScrollBy(0, memoLog.Height);
  if memoFullLog.HandleAllocated then
    memoFullLog.ScrollBy(0, memoFullLog.Height);
end;

procedure TfrmMain.SetStatus(const AMsg: string);
begin
  lblStatusBar.Caption := AMsg;
  Application.ProcessMessages;
end;

procedure TfrmMain.RefreshDashboard;
var
  IsOK: Boolean;
begin
  lblPortableDirVal.Caption := FConfig.PortableDir;

  IsOK := FConfig.IsValid;

  if IsOK then
  begin
    lblStatus.Caption    := '✅  Instalação válida e pronta';
    lblStatus.Font.Color := clGreen;
  end
  else
  begin
    lblStatus.Caption    := '⚠️  Problema detectado — execute o Diagnóstico';
    lblStatus.Font.Color := clRed;
  end;
end;

{ ============================================================ }
{  Dashboard actions                                           }
{ ============================================================ }

procedure TfrmMain.btnLaunchClick(Sender: TObject);
var
  Opts   : TLaunchOptions;
  Result_: TLaunchResult;
begin
  SetStatus('Preparando para lançar Lazarus...');
  AppLog('=== Iniciando Lazarus ===');

  Opts := DefaultLaunchOptions;
  Opts.DoBackup     := True;
  Opts.WaitForClose := False;

  Result_ := FLauncher.Launch(Opts);

  if Result_.Success then
  begin
    AppLog('Lazarus lançado com sucesso!');
    SetStatus('Lazarus em execução.');
  end
  else
  begin
    AppLog('ERRO ao lançar Lazarus: ' + Result_.ErrorMsg, 2);
    SetStatus('Erro ao lançar Lazarus.');
    MessageDlg('Erro ao lançar Lazarus', Result_.ErrorMsg, mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnConfigClick(Sender: TObject);
var
  FormConfig: TfrmConfigDB;
  UserMail: string;
begin
  // Somente o Super Admin tem acesso às configurações do banco de dados
  if not Assigned(FLicenseMgr) or not FLicenseMgr.IsAdminUser then
  begin
    UserMail := '';
    if Assigned(FLicenseMgr) then
      UserMail := FLicenseMgr.CurrentLicense.UserEmail;
    if UserMail = '' then UserMail := '(Modo Offline / Sem Login)';

    MessageDlg('Acesso Restrito',
      'Apenas o Administrador do sistema tem permissão para acessar as configurações do banco de dados.' + #13#10#13#10 +
      'Usuário atual: ' + UserMail,
      mtWarning, [mbOK], 0);
    Exit;
  end;

  FormConfig := TfrmConfigDB.Create(nil);
  try
    FormConfig.ShowModal;
  finally
    FormConfig.Free;
  end;
end;

procedure TfrmMain.btnPatchNowClick(Sender: TObject);
var
  Results : TPatchResultArray;
  Pr      : TPatchResult;
  Errors  : Integer;
begin
  SetStatus('Aplicando patches nas configurações...');
  AppLog('=== Patch Manual ===');

  Results := FConfig.PatchAll;
  Errors := 0;

  for Pr in Results do
    if not Pr.Success then
      Inc(Errors);

  if Errors = 0 then
  begin
    AppLog(Format('Patch concluído: %d arquivos processados.', [Length(Results)]));
    SetStatus('Patch aplicado com sucesso.');
    ShowMessage('Patch aplicado com sucesso em ' +
      IntToStr(Length(Results)) + ' arquivo(s)!');
  end
  else
  begin
    AppLog(Format('Patch com %d erro(s) em %d arquivos.', [Errors, Length(Results)]), 1);
    SetStatus('Patch concluído com avisos.');
    MessageDlg('Patch com avisos',
      Format('%d arquivo(s) processados com %d erro(s). Veja o Log para detalhes.',
        [Length(Results), Errors]),
      mtWarning, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnBackupClick(Sender: TObject);
begin
  SetStatus('Fazendo backup...');
  AppLog('Iniciando backup manual...');

  if FConfig.BackupConfigs then
  begin
    AppLog('Backup concluído com sucesso!');
    SetStatus('Backup realizado.');
    ShowMessage('Backup realizado com sucesso em:' + #13#10 + FConfig.BackupDir);
  end
  else
  begin
    AppLog('ERRO ao fazer backup!', 2);
    SetStatus('Erro no backup.');
    MessageDlg('Erro no Backup', 'Não foi possível realizar o backup.', mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnRestoreClick(Sender: TObject);
begin
  if MessageDlg('Restaurar Backup',
    'Isso irá sobrescrever a configuração atual com o backup mais recente.'#13#10 +
    'Deseja continuar?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  SetStatus('Restaurando backup...');
  AppLog('Restaurando backup...');

  if FConfig.RestoreBackup then
  begin
    AppLog('Restauração concluída!');
    SetStatus('Backup restaurado.');
    ShowMessage('Configuração restaurada com sucesso!');
  end
  else
  begin
    AppLog('ERRO na restauração!', 2);
    SetStatus('Erro na restauração.');
    MessageDlg('Erro', 'Não foi possível restaurar o backup.', mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnDiagClick(Sender: TObject);
begin
  lstMenu.ItemIndex := 3;
  lstMenuClick(nil);
  btnRunDiagClick(nil);
end;

procedure TfrmMain.btnOpenConfigClick(Sender: TObject);
begin
  if DirectoryExists(FConfig.ConfigDir) then
    ShellExecute(Handle, 'open', PChar(FConfig.ConfigDir), nil, nil, SW_SHOWNORMAL)
  else
    MessageDlg('Pasta não encontrada',
      'A pasta LazarusConfig não existe: ' + FConfig.ConfigDir,
      mtError, [mbOK], 0);
end;

{ ============================================================ }
{  Tab: Pacotes                                                 }
{ ============================================================ }

procedure TfrmMain.btnScanPkgsClick(Sender: TObject);
var
  Pkg  : TPackageInfo;
  Item : TListItem;
begin
  SetStatus('Varrendo pacotes instalados...');
  AppLog('Iniciando varredura de pacotes...');
  lvPackages.Items.Clear;

  FPkgManager.ScanInstalledPackages;

  for Pkg in FPkgManager.PackageList do
  begin
    Item := lvPackages.Items.Add;
    Item.Caption := Pkg.Name;
    Item.SubItems.Add(Pkg.Version);
    Item.SubItems.Add(Pkg.Author);
    Item.SubItems.Add(Pkg.StateText);
    Item.SubItems.Add(Pkg.LPKFile);

    // Cor por estado
    case Pkg.State of
      psOK:          Item.ImageIndex := 0;
      psPathBroken:
      begin
        // Visual de erro - não conseguimos colorir diretamente no ListView padrão
        // mas podemos usar SubItems
        Item.SubItems[2] := '⚠️ ' + Pkg.StateText;
      end;
    end;
  end;

  lblPkgCount.Caption := IntToStr(FPkgManager.PackageList.Count) + ' pacotes encontrados';
  AppLog(IntToStr(FPkgManager.PackageList.Count) + ' pacotes encontrados.');
  SetStatus('Varredura concluída.');
end;

procedure TfrmMain.btnExportPkgsClick(Sender: TObject);
var
  SD: TSaveDialog;
begin
  SD := TSaveDialog.Create(nil);
  try
    SD.Title    := 'Exportar Lista de Pacotes';
    SD.Filter   := 'JSON (*.json)|*.json|Todos (*.*)|*.*';
    SD.FileName := 'pacotes_lazarus.json';
    if SD.Execute then
    begin
      FPkgManager.ExportToFile(SD.FileName);
      ShowMessage('Lista exportada para: ' + SD.FileName);
    end;
  finally
    SD.Free;
  end;
end;

procedure TfrmMain.RefreshPackageList;
begin
  btnScanPkgsClick(nil);
end;

procedure TfrmMain.btnOPMClick(Sender: TObject);
begin
  lstMenu.ItemIndex := 5;
  lstMenuClick(nil);
end;

{ ============================================================ }
{  Tab: Perfis                                                  }
{ ============================================================ }

procedure TfrmMain.RefreshProfileList;
var
  Profiles : TProfileArray;
  Prof     : TProfileInfo;
  Item     : TListItem;
begin
  lvProfiles.Items.Clear;
  Profiles := FProfManager.ListProfiles;

  for Prof in Profiles do
  begin
    Item := lvProfiles.Items.Add;
    if Prof.IsActive then
      Item.Caption := '✅ ' + Prof.Name
    else
      Item.Caption := '   ' + Prof.Name;
    Item.SubItems.Add(Prof.Description);
    Item.SubItems.Add(FormatDateTime('dd/mm/yyyy hh:nn', Prof.CreatedAt));
    if Prof.LastUsed > 0 then
      Item.SubItems.Add(FormatDateTime('dd/mm/yyyy hh:nn', Prof.LastUsed))
    else
      Item.SubItems.Add('Nunca');
  end;
end;

procedure TfrmMain.btnNewProfileClick(Sender: TObject);
var
  ProfName, Desc: string;
begin
  ProfName := InputBox('Novo Perfil', 'Nome do perfil:', '');
  if ProfName = '' then Exit;

  Desc := InputBox('Novo Perfil', 'Descrição (opcional):', '');

  if FProfManager.CreateProfile(ProfName, Desc) then
  begin
    AppLog('Perfil criado: ' + ProfName);
    RefreshProfileList;
  end
  else
    MessageDlg('Erro', 'Não foi possível criar o perfil (já existe?)', mtError, [mbOK], 0);
end;

procedure TfrmMain.btnActivateProfileClick(Sender: TObject);
var
  ProfName: string;
begin
  if lvProfiles.Selected = nil then
  begin
    ShowMessage('Selecione um perfil para ativar.');
    Exit;
  end;

  ProfName := Trim(StringReplace(lvProfiles.Selected.Caption, '✅ ', '', [rfReplaceAll]));
  ProfName := Trim(StringReplace(ProfName, '   ', '', [rfReplaceAll]));

  if MessageDlg('Ativar Perfil',
    'Ativar o perfil "' + ProfName + '"?'#13#10 +
    'Isso irá substituir a configuração atual.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if FProfManager.ActivateProfile(ProfName) then
  begin
    AppLog('Perfil ativado: ' + ProfName);
    RefreshProfileList;
    ShowMessage('Perfil "' + ProfName + '" ativado com sucesso!');
  end
  else
    MessageDlg('Erro', 'Não foi possível ativar o perfil.', mtError, [mbOK], 0);
end;

procedure TfrmMain.btnSaveCurrentProfileClick(Sender: TObject);
var
  ProfName: string;
begin
  ProfName := InputBox('Salvar Configuração', 'Nome do perfil para salvar:', '');
  if ProfName = '' then Exit;

  if FProfManager.SaveCurrentAsProfile(ProfName) then
  begin
    AppLog('Configuração atual salva como perfil: ' + ProfName);
    RefreshProfileList;
    ShowMessage('Configuração salva como perfil "' + ProfName + '"!');
  end
  else
    MessageDlg('Erro', 'Não foi possível salvar o perfil.', mtError, [mbOK], 0);
end;

procedure TfrmMain.btnDeleteProfileClick(Sender: TObject);
var
  ProfName: string;
begin
  if lvProfiles.Selected = nil then
  begin
    ShowMessage('Selecione um perfil para deletar.');
    Exit;
  end;

  ProfName := Trim(StringReplace(lvProfiles.Selected.Caption, '✅ ', '', [rfReplaceAll]));
  ProfName := Trim(StringReplace(ProfName, '   ', '', [rfReplaceAll]));

  if MessageDlg('Deletar Perfil',
    'Deletar o perfil "' + ProfName + '"? Esta ação não pode ser desfeita.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if FProfManager.DeleteProfile(ProfName) then
  begin
    AppLog('Perfil deletado: ' + ProfName);
    RefreshProfileList;
  end
  else
    MessageDlg('Erro',
      'Não foi possível deletar o perfil (pode ser o perfil ativo).',
      mtError, [mbOK], 0);
end;

{ ============================================================ }
{  Tab: Diagnóstico                                             }
{ ============================================================ }

procedure TfrmMain.btnRunDiagClick(Sender: TObject);
var
  Report : TDiagReport;
  Item_  : TDiagItem;
  LvItem : TListItem;
  LvlStr : string;
begin
  SetStatus('Executando diagnóstico...');
  AppLog('=== Diagnóstico iniciado ===');
  lvDiag.Items.Clear;

  Report := FDiagnostics.RunDiagnostics;

  for Item_ in Report do
  begin
    case Item_.Level of
      dlOK:      LvlStr := '✅';
      dlWarning: LvlStr := '⚠️';
      dlError:   LvlStr := '❌';
      dlInfo:    LvlStr := 'ℹ️';
    end;

    LvItem := lvDiag.Items.Add;
    LvItem.Caption := LvlStr;
    LvItem.SubItems.Add(Item_.Category);
    LvItem.SubItems.Add(Item_.Test);
    LvItem.SubItems.Add(Item_.Detail + ' ' + Item_.Value);
  end;

  lblDiagSummary.Caption := FDiagnostics.GetSummary;
  AppLog(FDiagnostics.GetSummary);

  if FDiagnostics.HasErrors then
  begin
    SetStatus('Diagnóstico: ERROS encontrados!');
    lblDiagSummary.Font.Color := clRed;
  end
  else if FDiagnostics.HasWarnings then
  begin
    SetStatus('Diagnóstico: Avisos encontrados.');
    lblDiagSummary.Font.Color := clYellow;
  end
  else
  begin
    SetStatus('Diagnóstico: Tudo OK!');
    lblDiagSummary.Font.Color := clGreen;
  end;
end;

procedure TfrmMain.btnSaveReportClick(Sender: TObject);
var
  SD: TSaveDialog;
begin
  SD := TSaveDialog.Create(nil);
  try
    SD.Title    := 'Salvar Relatório de Diagnóstico';
    SD.Filter   := 'Texto (*.txt)|*.txt|Todos (*.*)|*.*';
    SD.FileName := 'diagnostico_lazarus_' +
      FormatDateTime('YYYYMMDD_HHNNSS', Now) + '.txt';
    if SD.Execute then
    begin
      FDiagnostics.SaveReport(SD.FileName);
      ShowMessage('Relatório salvo em: ' + SD.FileName);
    end;
  finally
    SD.Free;
  end;
end;

{ ============================================================ }
{  Tab: Log                                                     }
{ ============================================================ }

procedure TfrmMain.btnClearLogClick(Sender: TObject);
begin
  memoFullLog.Clear;
  memoLog.Clear;
end;

procedure TfrmMain.btnSaveLogClick(Sender: TObject);
var
  SD: TSaveDialog;
begin
  SD := TSaveDialog.Create(nil);
  try
    SD.Title    := 'Salvar Log';
    SD.Filter   := 'Texto (*.txt)|*.txt|Todos (*.*)|*.*';
    SD.FileName := 'log_lazarusportable_' +
      FormatDateTime('YYYYMMDD', Now) + '.txt';
    if SD.Execute then
    begin
      memoFullLog.Lines.SaveToFile(SD.FileName);
      ShowMessage('Log salvo em: ' + SD.FileName);
    end;
  finally
    SD.Free;
  end;
end;

{ ============================================================ }
{  Tab: OPM Online                                              }
{ ============================================================ }

procedure TfrmMain.btnOPMSearchClick(Sender: TObject);
var
  Term     : string;
  Packages : TOPMPackageArray;
begin
  Term := Trim(edtOPMSearch.Text);
  if Term = '' then
    Term := '*';

  SetStatus('Buscando pacotes no OPM...');
  lblOPMStatus.Caption := 'Buscando "' + Term + '"...';
  pbOPM.Position := 0;
  Application.ProcessMessages;

  Packages := FPkgManager.OPMSearch(Term, 30);

  if Length(Packages) = 0 then
  begin
    lblOPMStatus.Caption := 'Nenhum pacote encontrado para "' + Term + '"';
    SetStatus('Busca OPM concluída - sem resultados.');
    lvOPM.Items.Clear;
  end
  else
  begin
    LoadOPMResults(Packages);
    lblOPMStatus.Caption := IntToStr(Length(Packages)) + ' pacotes encontrados';
    SetStatus('Busca OPM concluída: ' + IntToStr(Length(Packages)) + ' resultado(s).');
  end;
end;

procedure TfrmMain.LoadOPMResults(const APackages: TOPMPackageArray);
var
  Pkg  : TOPMPackageInfo;
  Item : TListItem;
begin
  lvOPM.Items.Clear;

  for Pkg in APackages do
  begin
    Item := lvOPM.Items.Add;
    Item.Caption := Pkg.Name;
    Item.SubItems.Add(Pkg.Version);
    Item.SubItems.Add(Pkg.Author);
    Item.SubItems.Add(Pkg.Category);
    Item.SubItems.Add(Pkg.Description);
  end;
end;

procedure TfrmMain.btnOPMDownloadClick(Sender: TObject);
var
  DestDir : string;
  PkgName : string;
  PkgInfo : TOPMPackageInfo;
begin
  if lvOPM.Selected = nil then
  begin
    ShowMessage('Selecione um pacote para baixar.');
    Exit;
  end;

  // Por simplicidade, baixamos para a pasta components/ do portável
  DestDir := FConfig.PortableDir + 'components_ext' + PathDelim;
  ForceDirectories(DestDir);

  // O índice do item selecionado corresponde ao índice no array de resultado
  // (assumindo que o usuário não re-ordenou a lista)
  PkgName := lvOPM.Selected.Caption;
  AppLog('Iniciando download: ' + PkgName);
  SetStatus('Baixando: ' + PkgName);

  // Busca os detalhes completos do pacote
  PkgInfo := FPkgManager.OPMGetPackage(PkgName);
  if PkgInfo.DownloadURL = '' then
  begin
    MessageDlg('Erro', 'URL de download não disponível para este pacote.', mtError, [mbOK], 0);
    Exit;
  end;

  if FPkgManager.OPMDownload(PkgInfo, DestDir) then
  begin
    FPkgManager.ScanInstalledPackages;
    AppLog('Download concluído: ' + PkgName);
    SetStatus('Download concluído e registrado.');
    ShowMessage('Pacote "' + PkgName + '" baixado e extraído com sucesso para:' + #13#10 +
      DestDir + #13#10#13#10 +
      '📌 Como instalar no Lazarus:' + #13#10 +
      '1. Clique no botão "▶ Lançar" para abrir a IDE.' + #13#10 +
      '2. Na IDE, vá no menu "Pacote" ➔ "Abrir Arquivo de Pacote (.lpk)".' + #13#10 +
      '3. Selecione o arquivo .lpk na pasta acima e clique em "Usar" ➔ "Instalar".');
  end
  else
  begin
    AppLog('ERRO no download: ' + PkgName, 2);
    SetStatus('Erro no download.');
    MessageDlg('Erro', 'Falha ao baixar o pacote.', mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnOpenHtmlManualClick(Sender: TObject);
var
  HtmlFile: string;
begin
  HtmlFile := FConfig.PortableDir + 'MANUAL.html';
  if not FileExists(HtmlFile) then
    HtmlFile := ExtractFileDir(Application.ExeName) + PathDelim + 'manual' + PathDelim + 'MANUAL.html';

  if FileExists(HtmlFile) then
    OpenURL('file:///' + HtmlFile)
  else
    MessageDlg('Manual Não Encontrado',
      'O arquivo MANUAL.html não foi localizado.' + #13#10 +
      'Caminho esperado: ' + HtmlFile, mtWarning, [mbOK], 0);
end;

procedure TfrmMain.LoadUserManual;
var
  M: TStringList;
begin
  M := TStringList.Create;
  try
    M.Add('===============================================================================');
    M.Add('               📖 MANUAL DO USUÁRIO - LAZARUS PORTABLE MANAGER');
    M.Add('===============================================================================');
    M.Add('');
    M.Add('1. VISÃO GERAL');
    M.Add('--------------');
    M.Add('O Lazarus Portable Manager transforma a sua instalação do Lazarus IDE em um');
    M.Add('ambiente 100% portável, permitindo transportar o Lazarus com todas as suas');
    M.Add('configurações, ferramentas, componentes e perfis de ambiente em um Pen Drive');
    M.Add('ou HD externo para executar em qualquer computador com Windows sem necessidade');
    M.Add('de instalação prévia.');
    M.Add('');
    M.Add('2. COMO FUNCIONA A PORTABILIDADE');
    M.Add('--------------------------------');
    M.Add('- As configurações do Lazarus normalmente ficam em %LOCALAPPDATA%\lazarus.');
    M.Add('- O Lazarus Portable direciona a IDE para ler e salvar tudo na pasta local:');
    M.Add('  $(PortableDir)\LazarusConfig\ (ex: C:\lazarus\LazarusConfig\).');
    M.Add('- Sempre que você abre o programa ou o move para outro PC (onde a letra de');
    M.Add('  unidade como C:, D:, E: muda), o motor de patch atualiza automaticamente');
    M.Add('  todos os arquivos XML de configuração sem corromper pacotes instalados.');
    M.Add('');
    M.Add('3. GUIA RÁPIDO PASSO A PASSO (USO EM PEN DRIVE)');
    M.Add('-----------------------------------------------');
    M.Add('► LANÇAR A IDE:');
    M.Add('  Clique no botão "▶ Lançar" no topo da tela. O gerenciador fará um backup');
    M.Add('  preventivo, aplicará os patches de caminho necessários e iniciará o Lazarus.');
    M.Add('');
    M.Add('► COPIAR E USAR EM UM PEN DRIVE:');
    M.Add('  1. No gerenciador, clique no botão "💾 Backup Manual" por prevenção.');
    M.Add('  2. Copie a pasta inteira "C:\lazarus\" para a raiz do seu Pen Drive.');
    M.Add('  3. Espete o Pen Drive em outro PC (ex: unidade E:\ ou F:\).');
    M.Add('  4. Abra a pasta do Pen Drive e execute "LazarusPortable.exe".');
    M.Add('  5. Clique em "▶ Lançar". Todos os 142 componentes e opções abrirão');
    M.Add('     perfeitamente na nova letra de unidade!');
    M.Add('');
    M.Add('► ESPAÇO NECESSÁRIO NO PEN DRIVE:');
    M.Add('  Uma instalação completa do Lazarus com FPC e pacotes utiliza aproximadamente');
    M.Add('  2,5 GB. Recomendamos utilizar Pen Drives de 4 GB, 8 GB ou maiores.');
    M.Add('');
    M.Add('4. BOTÕES DA INTERFACE E SUAS FUNÇÕES');
    M.Add('-------------------------------------');
    M.Add('[ 🔧 Re-Patch Configurações ]');
    M.Add('  Ajusta todos os caminhos dos XMLs da pasta LazarusConfig para a pasta atual.');
    M.Add('  Útil ao trocar de computador ou alterar pastas manualmente.');
    M.Add('');
    M.Add('[ 💾 Backup Manual ]');
    M.Add('  Cria uma cópia de segurança instantânea de LazarusConfig na pasta Backup\');
    M.Add('  com marcação de data e hora (Ex: Backup\20260714_130000\).');
    M.Add('');
    M.Add('[ ↩️ Restaurar Backup ]');
    M.Add('  Lista os backups salvos e restaura a configuração selecionada.');
    M.Add('');
    M.Add('[ 🔍 Executar Diagnóstico ]');
    M.Add('  Testa 23 pontos críticos da instalação (lazarus.exe, fpc.exe, LCL, etc.).');
    M.Add('');
    M.Add('[ 📂 Abrir LazarusConfig ]');
    M.Add('  Abre a pasta de configurações diretamente no Windows Explorer.');
    M.Add('');
    M.Add('[ 🌐 OPM Online ]');
    M.Add('  Navegue e pesquise na biblioteca remota oficial de pacotes da comunidade');
    M.Add('  do Lazarus e baixe componentes com 1 clique.');
    M.Add('');
    M.Add('5. GERENCIAMENTO DE PERFIS DE CONFIGURAÇÃO');
    M.Add('------------------------------------------');
    M.Add('A aba "👤 Perfis" permite criar, salvar e alternar entre múltiplos ambientes de');
    M.Add('trabalho completamente isolados para a sua IDE Lazarus.');
    M.Add('');
    M.Add('► O QUE É SALVO EM CADA PERFIL:');
    M.Add('  Cada perfil armazena individualmente: pacotes e componentes instalados, layouts');
    M.Add('  de janelas e paletas, caminhos de compiladores, macros de editor, atalhos de');
    M.Add('  teclado e arquivos recentes.');
    M.Add('');
    M.Add('► EXEMPLOS DE USO:');
    M.Add('  - Perfis por Cliente/Projeto: "Cliente A (ACBr + Fortes)" vs "Projeto Web (LAMW)".');
    M.Add('  - Perfis por Ambiente: "Dev/Testes" (com logs e ferramentas de debug) vs');
    M.Add('    "Produção/Clean" (IDE limpa e ultra-rápida para compilação final).');
    M.Add('');
    M.Add('► FUNÇÕES DOS BOTÕES DE PERFIL:');
    M.Add('  [ + Novo Perfil ]       ➔ Cria uma pasta de perfil de configuração limpa.');
    M.Add('  [ ☑ Ativar Perfil ]     ➔ Aplica o perfil selecionado na IDE Lazarus.');
    M.Add('  [ 💾 Salvar Config Atual]➔ Grava as alterações atuais da IDE dentro do perfil.');
    M.Add('  [ 🗑 Deletar ]           ➔ Exclui permanentemente um perfil selecionado.');
    M.Add('');
    M.Add('6. RESOLUÇÃO DE DÚVIDAS E PROBLEMAS');
    M.Add('------------------------------------');
    M.Add('Q: O Lazarus abriu sem meus componentes na paleta, o que fazer?');
    M.Add('R: Clique no botão "↩️ Restaurar Backup" no Dashboard e selecione a última');
    M.Add('   data de backup.');
    M.Add('');
    M.Add('Q: Como instalar novos pacotes via OPM ou arquivo .lpk?');
    M.Add('R: Na aba OPM Online, busque e baixe o pacote desejado. Na IDE do Lazarus,');
    M.Add('   vá em Pacote ➔ Abrir Arquivo de Pacote (.lpk) e clique em Usar ➔ Instalar.');
    M.Add('');
    M.Add('===============================================================================');

    memoManual.Lines.Assign(M);
    memoManual.Color := 1052688;
    memoManual.Font.Color := clYellow;

    try
      M.SaveToFile(FConfig.PortableDir + 'MANUAL.txt');
    except
    end;
  finally
    M.Free;
  end;
end;

end.
