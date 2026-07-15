{
  frmConfigDB.pas - Tela de Configuração de Conexão com o Banco Firebird & Dados PIX
}
unit frmConfigDB;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  uLicenseManager, uConfigCrypt;

type

  { TfrmConfigDB }

  TfrmConfigDB = class(TForm)
    pnlHeader   : TPanel;
    lblTitle    : TLabel;
    pgcConfig   : TPageControl;
    tabDBConfig : TTabSheet;
    tabPIXConfig: TTabSheet;

    // Campos Banco
    lblHost     : TLabel;
    edtHost     : TEdit;
    lblPort     : TLabel;
    edtPort     : TEdit;
    lblDBPath   : TLabel;
    edtDBPath   : TEdit;
    lblUser     : TLabel;
    edtUser     : TEdit;
    lblPassword : TLabel;
    edtPassword : TEdit;
    lblCharset  : TLabel;
    cboCharset  : TComboBox;
    lblClientLib: TLabel;
    edtClientLib: TEdit;
    btnTest     : TButton;
    btnSave     : TButton;
    btnCancel   : TButton;

    // Campos PIX
    lblPixKey   : TLabel;
    edtPixKey   : TEdit;
    lblPixType  : TLabel;
    cboPixType  : TComboBox;
    lblPixHolder: TLabel;
    edtPixHolder: TEdit;
    lblPixBank  : TLabel;
    edtPixBank  : TEdit;
    lblPixAmount: TLabel;
    edtPixAmount: TEdit;
    lblPixInst  : TLabel;
    memoPixInst : TMemo;
    btnSavePix  : TButton;

    procedure FormCreate(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnSavePixClick(Sender: TObject);
  private
    FConfigDir: string;
    procedure LoadConfig;
    procedure SaveConfig;
    procedure LoadPIXConfig;
  public
  end;

var
  FormConfigDB: TfrmConfigDB;

implementation

{$R *.lfm}

procedure TfrmConfigDB.FormCreate(Sender: TObject);
begin
  FConfigDir := IncludeTrailingPathDelimiter(ExtractFileDir(Application.ExeName)) + 'LazarusConfig' + PathDelim;
  LoadConfig;
  LoadPIXConfig;
end;

procedure TfrmConfigDB.LoadConfig;
var
  ConfigFile: string;
begin
  ConfigFile := FConfigDir + 'vps_config.ini';
  TConfigCrypt.MigrateAndEncrypt(ConfigFile);
  edtHost.Text      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Host', 'localhost');
  edtPort.Text      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Port', '3050');
  edtDBPath.Text    := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Path', 'C:\Fontes\Componentes\TLazarusBakcup\Database\LazarusBackup.fdb');
  edtUser.Text      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'User', 'SYSDBA');
  edtPassword.Text  := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Password', 'masterkey');
  cboCharset.Text   := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Charset', 'UTF8');
  edtClientLib.Text := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'ClientLib', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');
end;

procedure TfrmConfigDB.LoadPIXConfig;
var
  LicMgr: TLicenseManager;
  Conf: TPIXConfigInfo;
begin
  LicMgr := TLicenseManager.Create(FConfigDir);
  try
    Conf := LicMgr.GetPIXConfig;
    edtPixKey.Text    := Conf.ChavePIX;
    cboPixType.Text   := Conf.TipoChave;
    edtPixHolder.Text := Conf.Titular;
    edtPixBank.Text   := Conf.Banco;
    edtPixAmount.Text := FloatToStrF(Conf.ValorLicenca, ffFixed, 15, 2);
    memoPixInst.Text  := Conf.Instrucoes;
  finally
    LicMgr.Free;
  end;
end;

procedure TfrmConfigDB.SaveConfig;
var
  ConfigFile: string;
begin
  ConfigFile := FConfigDir + 'vps_config.ini';
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'Host',      edtHost.Text);
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'Port',      edtPort.Text);
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'Path',      edtDBPath.Text);
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'User',      edtUser.Text);
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'Password',  edtPassword.Text);
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'Charset',   cboCharset.Text);
  TConfigCrypt.WriteEncrypted(ConfigFile, 'Database', 'ClientLib', edtClientLib.Text);
end;

procedure TfrmConfigDB.btnTestClick(Sender: TObject);
var
  LicMgr: TLicenseManager;
  ErrMsg: string;
begin
  SaveConfig;

  LicMgr := TLicenseManager.Create(FConfigDir);
  try
    if LicMgr.TestConnection(ErrMsg) then
      ShowMessage('Conexão estabelecida com sucesso no banco Firebird!')
    else
      MessageDlg('Erro de Conexão', 'Falha ao conectar:' + #13#10 + ErrMsg, mtError, [mbOK], 0);
  finally
    LicMgr.Free;
  end;
end;

procedure TfrmConfigDB.btnSaveClick(Sender: TObject);
begin
  SaveConfig;
  ShowMessage('Configurações de conexão salvas com sucesso!');
  ModalResult := mrOK;
end;

procedure TfrmConfigDB.btnSavePixClick(Sender: TObject);
var
  LicMgr: TLicenseManager;
  Conf: TPIXConfigInfo;
  ValStr: string;
  Val: Double;
begin
  ValStr := StringReplace(edtPixAmount.Text, ',', '.', [rfReplaceAll]);
  Val    := StrToFloatDef(ValStr, 49.90);

  Conf.ChavePIX     := Trim(edtPixKey.Text);
  Conf.TipoChave    := cboPixType.Text;
  Conf.Titular      := Trim(edtPixHolder.Text);
  Conf.Banco        := Trim(edtPixBank.Text);
  Conf.ValorLicenca := Val;
  Conf.Instrucoes   := Trim(memoPixInst.Text);

  LicMgr := TLicenseManager.Create(FConfigDir);
  try
    if LicMgr.SavePIXConfig(Conf) then
      ShowMessage('Configurações do PIX salvas no Banco de Dados com sucesso!')
    else
      MessageDlg('Erro', 'Falha ao salvar a Chave PIX no Banco de Dados.' + #13#10 +
        'Verifique a conexão de rede ou a aba Conexão Firebird.', mtError, [mbOK], 0);
  finally
    LicMgr.Free;
  end;
end;

procedure TfrmConfigDB.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
