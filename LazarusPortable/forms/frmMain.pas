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
  ComCtrls, StdCtrls, ExtCtrls, Buttons, Windows, fpreadjpeg,
  uPortableCore, uPackageManager, uProfileManager,
  uDiagnostics, uLauncher, uLicenseManager, frmConfigDB, frmPayment,
  frmReceiptViewer, frmRestoreSelect;

type
  { TfrmMain }
  TfrmMain = class(TForm)
    pnlTop         : TPanel;
    lblTitle       : TLabel;
    imgMainLogo    : TImage;
    btnLaunch      : TButton;
    btnConfig      : TButton;
    pnlLeft        : TPanel;
    lstMenu        : TListBox;
    pnlMain        : TPanel;
    pgcMain        : TPageControl;

    { Tab Dashboard }
    tabDashboard        : TTabSheet;
    pnlDash             : TPanel;
    pnlLicBanner        : TPanel;
    lblLicBannerMsg     : TLabel;
    btnLicBannerAction  : TButton;
    pnlStatCards        : TPanel;
    pnlStatLic          : TPanel;
    lblStatLicTitle     : TLabel;
    lblStatLicVal       : TLabel;
    pbLicDays           : TProgressBar;
    lblStatLicSub       : TLabel;
    btnStatLicAction    : TButton;
    pnlStatPkgs         : TPanel;
    lblStatPkgsTitle    : TLabel;
    lblStatPkgsVal      : TLabel;
    lblStatPkgsSub      : TLabel;
    btnStatPkgsAction   : TButton;
    pnlStatProfiles     : TPanel;
    lblStatProfTitle    : TLabel;
    lblStatProfVal      : TLabel;
    lblStatProfSub      : TLabel;
    btnStatProfAction   : TButton;
    pnlStatBackup       : TPanel;
    lblStatBackupTitle  : TLabel;
    lblStatBackupVal    : TLabel;
    lblStatBackupSub    : TLabel;
    btnStatBackupAction : TButton;
    pnlActions          : TPanel;
    lblActTitle         : TLabel;
    btnLaunchMain       : TButton;
    btnOpenConfigDir    : TButton;
    btnOpenCMD          : TButton;
    btnCleanCache       : TButton;
    btnPatchNow         : TButton;
    btnDiag             : TButton;
    btnExportProfile    : TButton;
    btnImportProfile    : TButton;
    memoLog             : TMemo;

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
    tabProfiles          : TTabSheet;
    pnlProfHeader        : TPanel;
    lblProfTitle         : TLabel;
    lvProfiles           : TListView;
    pnlProfButtons       : TPanel;
    btnNewProfile        : TButton;
    btnActivateProfile   : TButton;
    btnSaveCurrentProfile: TButton;
    btnDeleteProfile     : TButton;

    { Tab Pagamentos }
    tabPayments          : TTabSheet;
    pnlPayHeader         : TPanel;
    lblPayTitle          : TLabel;
    lblPayUserStatus     : TLabel;
    btnNewReceipt        : TButton;
    btnRefreshReceipts   : TButton;
    lvReceipts           : TListView;
    pnlPayBottom         : TPanel;
    btnApproveReceipt    : TButton;
    btnRejectReceipt     : TButton;
    btnViewReceipt       : TButton;

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
    lblDigitalClock: TLabel;
    lblVersion     : TLabel;
    tmrClock       : TTimer;

    { Eventos }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tmrClockTimer(Sender: TObject);

    { Menu lateral }
    procedure lstMenuClick(Sender: TObject);

    { Dashboard }
    procedure btnLaunchClick(Sender: TObject);
    procedure btnConfigClick(Sender: TObject);
    procedure btnPatchNowClick(Sender: TObject);
    procedure btnBackupClick(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure btnExportProfileClick(Sender: TObject);
    procedure btnImportProfileClick(Sender: TObject);
    procedure btnDiagClick(Sender: TObject);
    procedure btnOpenConfigClick(Sender: TObject);
    procedure btnOpenConfigDirClick(Sender: TObject);
    procedure btnOpenCMDClick(Sender: TObject);
    procedure btnCleanCacheClick(Sender: TObject);
    procedure btnStatLicActionClick(Sender: TObject);
    procedure btnStatPkgsActionClick(Sender: TObject);
    procedure btnStatProfActionClick(Sender: TObject);

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

    { Pagamentos }
    procedure RefreshPaymentReceipts;
    procedure btnNewReceiptClick(Sender: TObject);
    procedure btnRefreshReceiptsClick(Sender: TObject);
    procedure btnApproveReceiptClick(Sender: TObject);
    procedure btnRejectReceiptClick(Sender: TObject);
    procedure btnViewReceiptClick(Sender: TObject);
    procedure lvReceiptsDblClick(Sender: TObject);

  private
    FConfig       : TPortableConfig;
    FPkgManager   : TPackageManager;
    FProfManager  : TProfileManager;
    FDiagnostics  : TDiagnostics;
    FLauncher     : TLauncher;
    FLicenseMgr    : TLicenseManager; // referência externa — não libera aqui
    FUserLoggedOut : Boolean;
  public
    procedure SetLicenseManager(AValue: TLicenseManager);
    property LicenseManager: TLicenseManager read FLicenseMgr write SetLicenseManager;
    property UserLoggedOut: Boolean read FUserLoggedOut;

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
  ExeDir, LogoFile: string;
begin
  FUserLoggedOut := False;
  // Determina o diretório portável (onde está o .exe)
  ExeDir := ExtractFileDir(Application.ExeName);

  LogoFile := IncludeTrailingPathDelimiter(ExeDir) + 'logo_nova_conect.jpg';
  if not FileExists(LogoFile) then
    LogoFile := IncludeTrailingPathDelimiter(GetCurrentDir) + 'logo_nova_conect.jpg';
  if not FileExists(LogoFile) then
    LogoFile := 'C:\Fontes\Componentes\TLazarusBakcup\LazarusPortable\logo_nova_conect.jpg';

  if FileExists(LogoFile) then
  begin
    try
      imgMainLogo.Picture.LoadFromFile(LogoFile);
    except
    end;
  end;

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

  tmrClockTimer(nil);
end;

procedure TfrmMain.tmrClockTimer(Sender: TObject);
begin
  lblDigitalClock.Caption := FormatDateTime('"🕒 " dd/mm/yyyy hh:nn:ss', Now);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  try
    tmrClock.Enabled := False;
  except
  end;
  FLauncher.Free;
  FDiagnostics.Free;
  FProfManager.Free;
  FPkgManager.Free;
  FConfig.Free;
  FreeAndNil(FLicenseMgr); // libera o TLicenseManager que o lpr transferiu
end;

procedure TfrmMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  try
    tmrClock.Enabled := False;
  except
  end;
  CloseAction := caHide;
end;

procedure TfrmMain.FormResize(Sender: TObject);
var
  AvailWidth, CardW, BtnW, Spacing: Integer;
begin
  Spacing := 10;

  // 1. Redimensiona os 4 Cards de Estatística
  AvailWidth := pnlStatCards.ClientWidth;
  if AvailWidth > 100 then
  begin
    CardW := (AvailWidth - (3 * Spacing)) div 4;

    pnlStatLic.Left        := 0;
    pnlStatLic.Width       := CardW;
    btnStatLicAction.Width := CardW - 20;
    pbLicDays.Width        := CardW - 20;

    pnlStatPkgs.Left       := CardW + Spacing;
    pnlStatPkgs.Width      := CardW;
    btnStatPkgsAction.Width := CardW - 20;

    pnlStatProfiles.Left   := (CardW + Spacing) * 2;
    pnlStatProfiles.Width  := CardW;
    btnStatProfAction.Width := CardW - 20;

    pnlStatBackup.Left     := (CardW + Spacing) * 3;
    pnlStatBackup.Width    := CardW;
    btnStatBackupAction.Width := CardW - 20;
  end;

  // 2. Redimensiona os Botões de Ações Rápidas (3 colunas x 2 linhas)
  AvailWidth := pnlActions.ClientWidth - 24;
  if AvailWidth > 100 then
  begin
    BtnW := (AvailWidth - (2 * Spacing)) div 3;

    // Linha 1
    btnLaunchMain.Left     := 12;
    btnLaunchMain.Width    := BtnW;

    btnOpenConfigDir.Left  := 12 + BtnW + Spacing;
    btnOpenConfigDir.Width := BtnW;

    btnOpenCMD.Left        := 12 + (BtnW + Spacing) * 2;
    btnOpenCMD.Width       := BtnW;

    // Linha 2
    btnCleanCache.Left     := 12;
    btnCleanCache.Width    := BtnW;

    btnPatchNow.Left       := 12 + BtnW + Spacing;
    btnPatchNow.Width      := BtnW;

    btnDiag.Left           := 12 + (BtnW + Spacing) * 2;
    btnDiag.Width          := BtnW;

    // Linha 3
    btnExportProfile.Left  := 12;
    btnExportProfile.Width := BtnW;

    btnImportProfile.Left  := 12 + BtnW + Spacing;
    btnImportProfile.Width := BtnW;
  end;
end;

procedure TfrmMain.SetLicenseManager(AValue: TLicenseManager);
begin
  FLicenseMgr := AValue;
  RefreshDashboard;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  RefreshDashboard;
end;

procedure TfrmMain.lstMenuClick(Sender: TObject);
begin
  if (lstMenu.ItemIndex < 0) then Exit;

  // Item 9 = Sair — não navega para aba, trata diretamente
  if lstMenu.ItemIndex = 9 then
  begin
    if MessageDlg('Confirmar Saída', 'Deseja sair e voltar à tela de Login?',
       mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      FUserLoggedOut := True;
      ModalResult := mrOK;
    end;
    lstMenu.ItemIndex := -1;
    Exit;
  end;

  if (lstMenu.ItemIndex >= 0) and (lstMenu.ItemIndex < pgcMain.PageCount) then
  begin
    pgcMain.ActivePageIndex := lstMenu.ItemIndex;

    case lstMenu.ItemIndex of
      0: RefreshDashboard;
      1: ; // Pacotes - refresca apenas quando clicar Varrer
      2: RefreshProfileList;
      3: RefreshPaymentReceipts;
      4: ; // Diagnóstico
      5: ; // Log
      6: if lvOPM.Items.Count = 0 then btnOPMSearchClick(nil);
      7: ; // Manual
      8: ; // Sobre
    end;
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
  LicInfo: TLicenseInfo;
  StatusStr, ProfName, LastBackupStr: string;
  PkgCount, ProfCount: Integer;
  Profs: TProfileArray;
begin
  if Assigned(FLicenseMgr) then
  begin
    LicInfo := FLicenseMgr.CurrentLicense;

    // 1. Atualiza Card da Licença
    if LicInfo.IsAdmin then
    begin
      lblStatLicVal.Caption := 'Administrador';
      lblStatLicSub.Caption := 'Acesso Vitalício Total';
      pbLicDays.Position := 30;
      pbLicDays.Max := 30;
      pnlLicBanner.Visible := False;
    end
    else
    begin
      lblStatLicVal.Caption := Format('%d dias restantes', [LicInfo.DaysRemaining]);
      lblStatLicSub.Caption := 'Expira: ' + FormatDateTime('dd/mm/yyyy', LicInfo.ExpirationDate);

      pbLicDays.Max := 30;
      if LicInfo.DaysRemaining > 30 then
        pbLicDays.Position := 30
      else
        pbLicDays.Position := LicInfo.DaysRemaining;

      // Banner de alerta se faltar menos de 7 dias
      if LicInfo.DaysRemaining <= 7 then
      begin
        pnlLicBanner.Visible := True;
        lblLicBannerMsg.Caption := Format('⚠️ ATENÇÃO: Sua licença expira em %d dias! Renove para não perder o acesso.', [LicInfo.DaysRemaining]);
      end
      else
        pnlLicBanner.Visible := False;
    end;

    // 2. Atualiza Card de Componentes
    FPkgManager.ScanInstalledPackages;
    PkgCount := FPkgManager.PackageList.Count;
    lblStatPkgsVal.Caption := Format('%d Detectados', [PkgCount]);

    // 3. Atualiza Card de Perfis
    Profs := FProfManager.ListProfiles;
    ProfCount := Length(Profs);
    ProfName := FProfManager.GetActiveProfileName;
    if ProfName = '' then ProfName := 'Padrão';
    lblStatProfVal.Caption := ProfName;
    lblStatProfSub.Caption := Format('%d Perfil(is) configurado(s)', [ProfCount]);

    // 4. Card de Último Backup
    LastBackupStr := FormatDateTime('dd/mm/yyyy hh:nn', Now);
    lblStatBackupVal.Caption := LastBackupStr;

    if LicInfo.IsAdmin then
      StatusStr := '🏆 Licença Vitalícia Ativa (Administrador Geral)'
    else if LicInfo.Status = lsLicensed then
      StatusStr := Format('⭐ Licença Ativa (Vence em %s - %d dias restantes)',
                     [FormatDateTime('dd/mm/yyyy', LicInfo.ExpirationDate), LicInfo.DaysRemaining])
    else if LicInfo.Status = lsTrialActive then
      StatusStr := Format('⏳ Modo de Testes Gratuito (%d dias restantes)', [LicInfo.DaysRemaining])
    else
      StatusStr := Format('⚠️ Status: %s (%s)', [LicInfo.Message, LicInfo.UserEmail]);

    SetStatus(Format('Usuário: %s | %s', [LicInfo.UserEmail, StatusStr]));
  end;

  FormResize(nil);
end;

procedure TfrmMain.btnOpenConfigDirClick(Sender: TObject);
begin
  if DirectoryExists(FConfig.ConfigDir) then
  begin
    AppLog('Abrindo pasta de configurações: ' + FConfig.ConfigDir);
    OpenURL('file:///' + StringReplace(FConfig.ConfigDir, '\', '/', [rfReplaceAll]));
  end
  else
    ShowMessage('Diretório de configurações não encontrado: ' + FConfig.ConfigDir);
end;

procedure TfrmMain.btnOpenCMDClick(Sender: TObject);
begin
  AppLog('Abrindo Terminal Portável em: ' + FConfig.PortableDir);
  OpenDocument('cmd.exe');
end;

procedure TfrmMain.btnCleanCacheClick(Sender: TObject);
var
  CleanCount: Integer;

  procedure CleanDir(const ADir: string);
  var
    SR: TSearchRec;
  begin
    if FindFirst(ADir + '*.*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;

        if (SR.Attr and faDirectory) <> 0 then
          CleanDir(ADir + SR.Name + PathDelim)
        else if (SameText(ExtractFileExt(SR.Name), '.ppu') or SameText(ExtractFileExt(SR.Name), '.o')) then
        begin
          if SysUtils.DeleteFile(ADir + SR.Name) then
            Inc(CleanCount);
        end;
      until FindNext(SR) <> 0;
      SysUtils.FindClose(SR);
    end;
  end;

begin
  CleanCount := 0;
  AppLog('Iniciando limpeza de cache (.ppu / .o)...');
  CleanDir(FConfig.ConfigDir);
  CleanDir(FConfig.PortableDir + 'lib' + PathDelim);

  AppLog(Format('Limpeza concluída! %d arquivos de cache removidos.', [CleanCount]));
  ShowMessage(Format('Limpeza realizada com sucesso!' + #13#10 + '%d arquivos de cache (.ppu / .o) foram removidos.', [CleanCount]));
end;

procedure TfrmMain.btnStatLicActionClick(Sender: TObject);
var
  FormPay: TfrmPayment;
begin
  FormPay := TfrmPayment.Create(nil);
  try
    FormPay.LicenseManager := FLicenseMgr;
    if Assigned(FLicenseMgr) then
      FormPay.UserID := FLicenseMgr.CurrentLicense.UserID;
    if FormPay.ShowModal = mrOK then
    begin
      RefreshPaymentReceipts;
      RefreshDashboard;
    end;
  finally
    FormPay.Free;
  end;
end;

procedure TfrmMain.btnStatPkgsActionClick(Sender: TObject);
begin
  lstMenu.ItemIndex := 1;
  lstMenuClick(nil);
end;

procedure TfrmMain.btnStatProfActionClick(Sender: TObject);
begin
  lstMenu.ItemIndex := 2;
  lstMenuClick(nil);
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
var
  ExtBkpPath: string;
  LocalOk, ExtOk: Boolean;
begin
  SetStatus('Fazendo backup...');
  AppLog('Iniciando backup manual...');

  LocalOk := FConfig.BackupConfigs;
  if LocalOk then
    AppLog('Backup local concluído com sucesso!')
  else
    AppLog('ERRO ao realizar backup local!', 2);

  AppLog('Iniciando backup externo...');
  ExtOk := FConfig.BackupConfigsExternal(ExtBkpPath);
  if ExtOk then
    AppLog('Backup externo concluído com sucesso em: ' + ExtBkpPath)
  else
    AppLog('ERRO ao realizar backup externo!', 2);

  if LocalOk and ExtOk then
  begin
    SetStatus('Backup concluído.');
    ShowMessage('Backups realizados com sucesso!' + #13#10#13#10 +
                'Local (interno):' + #13#10 + FConfig.BackupDir + #13#10#13#10 +
                'Externo (usuário Windows):' + #13#10 + ExtBkpPath);
  end
  else if LocalOk then
  begin
    SetStatus('Parcialmente concluído.');
    ShowMessage('Backup local realizado com sucesso, mas ocorreu um erro no backup externo.' + #13#10 +
                'Verifique o log para detalhes.');
  end
  else
  begin
    SetStatus('Erro no backup.');
    MessageDlg('Erro no Backup', 'Não foi possível realizar o backup das configurações.', mtError, [mbOK], 0);
  end;
end;

procedure TfrmMain.btnExportProfileClick(Sender: TObject);
var
  SD: TSaveDialog;
  ZipFile: string;
begin
  SD := TSaveDialog.Create(nil);
  try
    SD.Title := 'Exportar Perfil de Desenvolvimento (.zip)';
    SD.Filter := 'Arquivo ZIP (*.zip)|*.zip';
    SD.DefaultExt := 'zip';
    SD.InitialDir := IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('USERPROFILE')) + 'LazarusBackup';
    SD.FileName := 'LazarusProfile_' + FormatDateTime('YYYYMMDD_HHNNSS', Now) + '.zip';
    
    if SD.Execute then
    begin
      ZipFile := SD.FileName;
      SetStatus('Exportando perfil...');
      AppLog('Iniciando exportação de perfil...');
      
      if FConfig.ExportProfile(ZipFile) then
      begin
        SetStatus('Perfil exportado.');
        ShowMessage('Perfil exportado com sucesso!' + #13#10 + 'Arquivo: ' + ZipFile);
      end
      else
      begin
        SetStatus('Erro na exportação.');
        MessageDlg('Erro ao Exportar', 'Ocorreu um erro ao exportar o perfil. Veja o log para mais detalhes.', mtError, [mbOK], 0);
      end;
    end;
  finally
    SD.Free;
  end;
end;

procedure TfrmMain.btnImportProfileClick(Sender: TObject);
var
  OD: TOpenDialog;
  ZipFile: string;
begin
  if MessageDlg('Importar Perfil',
    'ATENÇÃO: Importar um perfil irá limpar e substituir TODA a configuração portátil atual.' + #13#10 +
    'Além disso, após a descompactação, todos os caminhos do Lazarus serão corrigidos para a pasta atual.' + #13#10#13#10 +
    'Deseja realmente continuar?', mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  OD := TOpenDialog.Create(nil);
  try
    OD.Title := 'Importar Perfil de Desenvolvimento (.zip)';
    OD.Filter := 'Arquivo ZIP (*.zip)|*.zip';
    OD.InitialDir := IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('USERPROFILE')) + 'LazarusBackup';
    
    if OD.Execute then
    begin
      ZipFile := OD.FileName;
      SetStatus('Importando perfil...');
      AppLog('Iniciando importação de perfil de: ' + ZipFile);
      
      if FConfig.ImportProfile(ZipFile) then
      begin
        SetStatus('Perfil importado.');
        ShowMessage('Perfil importado e re-patcheado com sucesso!');
        RefreshDashboard; // Atualiza informações na tela principal
      end
      else
      begin
        SetStatus('Erro na importação.');
        MessageDlg('Erro ao Importar', 'Ocorreu um erro ao importar o perfil. Veja o log para mais detalhes.', mtError, [mbOK], 0);
      end;
    end;
  finally
    OD.Free;
  end;
end;

procedure TfrmMain.btnRestoreClick(Sender: TObject);
var
  FormRestore: TfrmRestoreSelect;
begin
  FormRestore := TfrmRestoreSelect.Create(nil);
  try
    FormRestore.Config := FConfig;
    if FormRestore.ShowModal = mrOK then
    begin
      if MessageDlg('Restaurar Backup',
        'Isso irá sobrescrever e restaurar os arquivos do backup selecionado.'#13#10 +
        'Deseja continuar?',
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

      SetStatus('Restaurando backup...');
      AppLog('Restaurando backup de: ' + FormRestore.SelectedPath);

      if FConfig.RestoreBackupFromPath(FormRestore.SelectedPath, FormRestore.SelectedIsExternal) then
      begin
        AppLog('Restauração concluída com sucesso!');
        SetStatus('Backup restaurado.');
        ShowMessage('Configuração restaurada com sucesso!');
      end
      else
      begin
        AppLog('ERRO na restauração!', 2);
        SetStatus('Erro na restauração.');
        MessageDlg('Erro', 'Não foi possível restaurar o backup selecionado.', mtError, [mbOK], 0);
      end;
    end;
  finally
    FormRestore.Free;
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
    HtmlFile := FConfig.PortableDir + 'manual' + PathDelim + 'MANUAL.html';
  if not FileExists(HtmlFile) then
    HtmlFile := ExtractFileDir(Application.ExeName) + PathDelim + 'manual' + PathDelim + 'MANUAL.html';
  if not FileExists(HtmlFile) then
    HtmlFile := ExtractFileDir(Application.ExeName) + PathDelim + 'MANUAL.html';

  if FileExists(HtmlFile) then
    OpenDocument(HtmlFile)
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
    M.Add('  $(PortableDir)\LazarusConfig\ (ex: E:\Lazarus\LazarusConfig\).');
    M.Add('- Ao iniciar o aplicativo pela primeira vez no Pen Drive (sem a pasta LazarusConfig),');
    M.Add('  ele importa AUTOMATICAMENTE a estrutura completa das configurações existentes');
    M.Add('  na sua máquina em %LOCALAPPDATA%\lazarus (pacotes, barras, teclas e atalhos).');
    M.Add('- Sempre que você abre o programa ou move para outro PC (onde a letra de');
    M.Add('  unidade como C:, D:, E: muda), o motor de patch atualiza automaticamente');
    M.Add('  todos os arquivos XML de configuração sem corromper pacotes instalados.');
    M.Add('');
    M.Add('3. GUIA RÁPIDO PASSO A PASSO (COPIAR LAZARUS CONFIGURADO PARA PEN DRIVE)');
    M.Add('------------------------------------------------------------------------');
    M.Add('1. Copie a pasta do Lazarus do computador (ex: C:\lazarus\) para a raiz');
    M.Add('   ou diretório do seu Pen Drive (ex: E:\Lazarus\).');
    M.Add('2. Cole o arquivo executável "LazarusPortable.exe" na raiz da pasta do Lazarus');
    M.Add('   no Pen Drive (no mesmo diretório onde está o lazarus.exe).');
    M.Add('3. Execute o "LazarusPortable.exe" a partir do Pen Drive. Na primeira execução,');
    M.Add('   ele detectará e importará automaticamente suas configurações do PC');
    M.Add('   para a pasta LazarusConfig do Pen Drive.');
    M.Add('4. Clique no botão "🔧 Re-Patch Configurações" ou "▶ Lançar". Todos os arquivos');
    M.Add('   XML serão corrigidos para a nova letra de unidade e o Lazarus abrirá');
    M.Add('   100% configurado no Pen Drive!');
    M.Add('');
    M.Add('► FERRAMENTAS DENTRO DA IDE (LazPortableTools.lpk):');
    M.Add('  Com o pacote instalado na IDE, use o menu Ferramentas ➔ Lazarus Portable Tools');
    M.Add('  para realizar Re-Patch e Backups das configurações diretamente do Lazarus.');
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
    M.Add('  Cria uma cópia de segurança instantânea do LazarusConfig, das pastas locais');
    M.Add('  do Windows (LOCALAPPDATA/APPDATA) e de toda a pasta de instalação C:\Lazarus');
    M.Add('  na pasta Backup\ local e na pasta externa C:\Users\<Usuario>\LazarusBackup\.');
    M.Add('');
    M.Add('[ ↩️ Restaurar Backup ]');
    M.Add('  Abre a janela de escolha de backups para selecionar um backup local ou externo');
    M.Add('  e restaurar a configuração e a pasta completa do Lazarus.');
    M.Add('');
    M.Add('[ 📦 Exportar Perfil (.zip) ]');
    M.Add('  Compacta as configurações, AppDatas do Windows e toda a pasta de instalação do');
    M.Add('  Lazarus em um arquivo .zip portátil para transferência facilitada.');
    M.Add('');
    M.Add('[ 📥 Importar Perfil (.zip) ]');
    M.Add('  Restaura e portabiliza um perfil completo de um arquivo .zip em nova pasta/unidade.');
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

procedure TfrmMain.RefreshPaymentReceipts;
var
  Receipts: TPaymentReceiptArray;
  Item: TListItem;
  I: Integer;
  LicInfo: TLicenseInfo;
begin
  lvReceipts.Items.Clear;
  if not Assigned(FLicenseMgr) then Exit;

  LicInfo := FLicenseMgr.CurrentLicense;
  if LicInfo.IsAdmin then
    lblPayUserStatus.Caption := Format('Usuário: %s (ADMINISTRADOR) | Gestão Geral de Todos os Comprovantes', [LicInfo.UserEmail])
  else
  begin
    lblPayUserStatus.Caption := Format('Usuário: %s | Status: %s', [LicInfo.UserEmail, LicInfo.Message]);
    if FLicenseMgr.LastError <> '' then
      lblPayUserStatus.Caption := lblPayUserStatus.Caption + ' [Erro: ' + FLicenseMgr.LastError + ']';
  end;

  btnApproveReceipt.Visible := LicInfo.IsAdmin;
  btnRejectReceipt.Visible  := LicInfo.IsAdmin;

  Receipts := FLicenseMgr.GetUserReceipts(LicInfo.UserID, LicInfo.IsAdmin);

  for I := 0 to Length(Receipts) - 1 do
  begin
    Item := lvReceipts.Items.Add;
    Item.Caption := IntToStr(Receipts[I].ID);
    Item.SubItems.Add(FormatDateTime('dd/mm/yyyy hh:nn', Receipts[I].DataEnvio));
    if LicInfo.IsAdmin then
      Item.SubItems.Add(Format('%s (%s)', [Receipts[I].UserName, Receipts[I].UserEmail]))
    else
      Item.SubItems.Add(Receipts[I].ChavePIX);

    Item.SubItems.Add(Format('R$ %.2f', [Receipts[I].ValorPago]));
    Item.SubItems.Add(Receipts[I].NomeArquivo);
    Item.SubItems.Add(Receipts[I].StatusAnalise);
    Item.SubItems.Add(Receipts[I].Observacao);
  end;
end;

procedure TfrmMain.btnNewReceiptClick(Sender: TObject);
var
  FormPay: TfrmPayment;
begin
  FormPay := TfrmPayment.Create(nil);
  try
    FormPay.LicenseManager := FLicenseMgr;
    if Assigned(FLicenseMgr) then
      FormPay.UserID := FLicenseMgr.CurrentLicense.UserID;
    if FormPay.ShowModal = mrOK then
      RefreshPaymentReceipts;
  finally
    FormPay.Free;
  end;
end;

procedure TfrmMain.btnRefreshReceiptsClick(Sender: TObject);
begin
  RefreshPaymentReceipts;
end;

procedure TfrmMain.btnApproveReceiptClick(Sender: TObject);
var
  RecID: Integer;
  Obs: string;
begin
  if lvReceipts.Selected = nil then
  begin
    ShowMessage('Selecione um comprovante na lista para aprovar.');
    Exit;
  end;

  RecID := StrToIntDef(lvReceipts.Selected.Caption, 0);
  Obs := InputBox('Aprovar Licença', 'Informe uma observação para a liberação:', 'Pagamento PIX verificado e aprovado');
  if Trim(Obs) = '' then Exit;

  if FLicenseMgr.ApproveReceipt(RecID, FLicenseMgr.CurrentLicense.UserID, 30, Obs) then
  begin
    ShowMessage('Licença APROVADA com sucesso! 30 dias adicionados ao usuário.');
    RefreshPaymentReceipts;
    RefreshDashboard;
  end
  else
    MessageDlg('Erro', 'Falha ao aprovar o comprovante.', mtError, [mbOK], 0);
end;

procedure TfrmMain.btnRejectReceiptClick(Sender: TObject);
var
  RecID: Integer;
  Obs: string;
begin
  if lvReceipts.Selected = nil then
  begin
    ShowMessage('Selecione um comprovante na lista para rejeitar.');
    Exit;
  end;

  RecID := StrToIntDef(lvReceipts.Selected.Caption, 0);
  Obs := InputBox('Rejeitar Comprovante', 'Informe o motivo da rejeição:', 'Comprovante ilegível ou valor incorreto');
  if Trim(Obs) = '' then Exit;

  if FLicenseMgr.RejectReceipt(RecID, Obs) then
  begin
    ShowMessage('Comprovante REJEITADO.');
    RefreshPaymentReceipts;
  end
  else
    MessageDlg('Erro', 'Falha ao rejeitar o comprovante.', mtError, [mbOK], 0);
end;

procedure TfrmMain.btnViewReceiptClick(Sender: TObject);
var
  RecID: Integer;
  FormViewer: TfrmReceiptViewer;
begin
  if lvReceipts.Selected = nil then
  begin
    ShowMessage('Selecione um comprovante na lista para visualizar.');
    Exit;
  end;

  RecID := StrToIntDef(lvReceipts.Selected.Caption, 0);
  if RecID <= 0 then Exit;

  FormViewer := TfrmReceiptViewer.Create(nil);
  try
    FormViewer.LicenseManager := FLicenseMgr;
    FormViewer.ReceiptID      := RecID;
    FormViewer.ShowModal;
  finally
    FormViewer.Free;
  end;
end;

procedure TfrmMain.lvReceiptsDblClick(Sender: TObject);
begin
  btnViewReceiptClick(Sender);
end;

end.
