{
  frmLogin.pas - Tela de Autenticação, Cadastro e Validação de Licenças
}
unit frmLogin;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  IniFiles, uLicenseManager, uConfigCrypt;

type

  { TfrmLogin }

  TfrmLogin = class(TForm)
    pnlHeader       : TPanel;
    lblTitle        : TLabel;
    pnlBody         : TPanel;
    lblName         : TLabel;
    edtName         : TEdit;
    lblEmail        : TLabel;
    edtEmail        : TEdit;
    lblPassword     : TLabel;
    edtPassword     : TEdit;
    lblTrialInfo    : TLabel;
    btnAction       : TButton;
    btnToggleMode   : TButton;
    btnContinueTrial: TButton;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnActionClick(Sender: TObject);
    procedure btnToggleModeClick(Sender: TObject);
    procedure btnContinueTrialClick(Sender: TObject);
  private
    FLicenseMgr : TLicenseManager;
    FIsRegister : Boolean;
    FConfigDir  : string;
    FAuthSuccess: Boolean;
    FInfo       : TLicenseInfo;

    procedure UpdateLayout;
    procedure LoadVPSConfig;
  public
    property LicenseManager : TLicenseManager read FLicenseMgr;
    property AuthSuccess    : Boolean         read FAuthSuccess;
    property LicenseInfo    : TLicenseInfo    read FInfo;
  end;

var
  FormLogin: TfrmLogin;

implementation

{$R *.lfm}

procedure TfrmLogin.FormCreate(Sender: TObject);
begin
  FConfigDir   := IncludeTrailingPathDelimiter(ExtractFileDir(Application.ExeName)) + 'LazarusConfig' + PathDelim;
  ForceDirectories(FConfigDir);
  FLicenseMgr  := TLicenseManager.Create(FConfigDir);
  FIsRegister  := False;
  FAuthSuccess := False;

  LoadVPSConfig;
  UpdateLayout;

  // Checa status do trial local
  FInfo := FLicenseMgr.CheckLocalTrial;
  lblTrialInfo.Caption := FInfo.Message;
end;
procedure TfrmLogin.FormDestroy(Sender: TObject);
begin
  // Se o usuário autenticou com sucesso, o LicenseManager será
  // controlado pelo FormMain. Caso contrário, libera aqui.
  if not FAuthSuccess then
    FreeAndNil(FLicenseMgr);
end;

procedure TfrmLogin.LoadVPSConfig;
var
  ConfigFile: string;
  Host, DBPath, User, Pass, Charset, ClientLib: string;
  Port: Integer;
begin
  ConfigFile := FConfigDir + 'vps_config.ini';
  TConfigCrypt.MigrateAndEncrypt(ConfigFile);

  Host      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Host', 'localhost');
  Port      := StrToIntDef(TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Port', '3050'), 3050);
  DBPath    := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Path', 'C:\Fontes\Componentes\TLazarusBakcup\Database\LazarusBackup.fdb');
  User      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'User', 'SYSDBA');
  Pass      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Password', 'masterkey');
  Charset   := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Charset', 'UTF8');
  ClientLib := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'ClientLib', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');

  FLicenseMgr.SetServerConfig(Host, DBPath, Port, User, Pass, Charset, ClientLib);
end;

procedure TfrmLogin.UpdateLayout;
begin
  if FIsRegister then
  begin
    lblTitle.Caption      := '📝 Criar Conta & Ativar Trial (10 Dias)';
    lblName.Visible       := True;
    edtName.Visible       := True;
    lblName.Top           := 10;
    edtName.Top           := 30;
    lblEmail.Top          := 68;
    edtEmail.Top          := 88;
    lblPassword.Top       := 126;
    edtPassword.Top       := 146;
    lblTrialInfo.Top      := 188;
    btnAction.Top         := 230;
    btnAction.Caption     := '✨ Cadastrar e Ganhar 10 Dias Grátis';
    btnToggleMode.Top     := 282;
    btnToggleMode.Caption := 'Já possui uma conta? Clique aqui para entrar';
    btnContinueTrial.Top  := 326;
  end
  else
  begin
    lblTitle.Caption      := '🔑 Entrar no Lazarus Portable';
    lblName.Visible       := False;
    edtName.Visible       := False;
    lblEmail.Top          := 15;
    edtEmail.Top          := 35;
    lblPassword.Top       := 75;
    edtPassword.Top       := 95;
    lblTrialInfo.Top      := 142;
    btnAction.Top         := 188;
    btnAction.Caption     := '🔑 Entrar com E-mail e Senha';
    btnToggleMode.Top     := 242;
    btnToggleMode.Caption := 'Não tem conta? Cadastre-se e ganhe 10 dias grátis';
    btnContinueTrial.Top  := 286;
  end;
end;

procedure TfrmLogin.btnToggleModeClick(Sender: TObject);
begin
  FIsRegister := not FIsRegister;
  UpdateLayout;
end;

procedure TfrmLogin.btnContinueTrialClick(Sender: TObject);
begin
  FInfo := FLicenseMgr.CheckLocalTrial;
  if FInfo.Status = lsTrialExpired then
  begin
    ShowMessage('Seu período de testes de 10 dias expirou!' + #13#10 +
      'Para continuar, realize o pagamento via PIX.');
    FAuthSuccess := False;
    ModalResult := mrCancel;
  end
  else
  begin
    FAuthSuccess := True;
    ModalResult := mrOK;
  end;
end;

procedure TfrmLogin.btnActionClick(Sender: TObject);
var
  ErrMsg: string;
begin
  if Trim(edtEmail.Text) = '' then
  begin
    ShowMessage('Por favor, informe seu e-mail.');
    Exit;
  end;

  if Trim(edtPassword.Text) = '' then
  begin
    ShowMessage('Por favor, informe sua senha.');
    Exit;
  end;

  if FIsRegister then
  begin
    if Trim(edtName.Text) = '' then
    begin
      ShowMessage('Por favor, informe seu nome completo.');
      Exit;
    end;

    if FLicenseMgr.RegisterUser(edtName.Text, edtEmail.Text, edtPassword.Text, FInfo, ErrMsg) then
    begin
      ShowMessage('Conta cadastrada! Seu período de testes de 10 dias foi iniciado.');
      FAuthSuccess := True;
      ModalResult := mrOK;
    end
    else
      MessageDlg('Erro no Cadastro', ErrMsg, mtError, [mbOK], 0);
  end
  else
  begin
    if FLicenseMgr.Authenticate(edtEmail.Text, edtPassword.Text, FInfo) then
    begin
      FAuthSuccess := True;
      ModalResult := mrOK;
    end
    else
    begin
      lblTrialInfo.Caption := FInfo.Message;
      MessageDlg('Acesso Negado', FInfo.Message, mtWarning, [mbOK], 0);
    end;
  end;
end;

end.
