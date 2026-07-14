{
  frmConfigDB.pas - Tela de Configuração de Conexão com o Banco de Dados Firebird
}
unit frmConfigDB;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  IniFiles, uLicenseManager, uConfigCrypt;

type

  { TfrmConfigDB }

  TfrmConfigDB = class(TForm)
    pnlHeader   : TPanel;
    lblTitle    : TLabel;
    pnlBody     : TPanel;
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

    procedure FormCreate(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FConfigDir: string;
    procedure LoadConfig;
    procedure SaveConfig;
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
end;

procedure TfrmConfigDB.LoadConfig;
var
  Ini: TIniFile;
  ConfigFile: string;
begin
  ConfigFile := FConfigDir + 'vps_config.ini';
  Ini := TIniFile.Create(ConfigFile);
  try
    edtHost.Text      := Ini.ReadString('VPS', 'Host', 'localhost');
    edtPort.Text      := Ini.ReadString('VPS', 'Port', '3050');
    edtDBPath.Text    := Ini.ReadString('VPS', 'DatabasePath',
                           'C:\Fontes\Componentes\TLazarusBakcup\Database\LazarusBackup.fdb');
    cboCharset.Text   := Ini.ReadString('VPS', 'Charset', 'UTF8');
    edtClientLib.Text := Ini.ReadString('VPS', 'ClientLib',
                           'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');
  finally
    Ini.Free;
  end;

  edtUser.Text     := TConfigCrypt.ReadEncrypted(ConfigFile, 'VPS', 'User', 'SYSDBA');
  edtPassword.Text := TConfigCrypt.ReadEncrypted(ConfigFile, 'VPS', 'Password', 'masterkey');

  if cboCharset.ItemIndex < 0 then
    cboCharset.ItemIndex := 0;
end;

procedure TfrmConfigDB.SaveConfig;
var
  Ini: TIniFile;
  ConfigFile: string;
begin
  ConfigFile := FConfigDir + 'vps_config.ini';
  Ini := TIniFile.Create(ConfigFile);
  try
    Ini.WriteString('VPS', 'Host', Trim(edtHost.Text));
    Ini.WriteString('VPS', 'Port', Trim(edtPort.Text));
    Ini.WriteString('VPS', 'DatabasePath', Trim(edtDBPath.Text));
    Ini.WriteString('VPS', 'Charset', Trim(cboCharset.Text));
    Ini.WriteString('VPS', 'ClientLib', Trim(edtClientLib.Text));
  finally
    Ini.Free;
  end;

  TConfigCrypt.WriteEncrypted(ConfigFile, 'VPS', 'User', Trim(edtUser.Text));
  TConfigCrypt.WriteEncrypted(ConfigFile, 'VPS', 'Password', Trim(edtPassword.Text));
end;

procedure TfrmConfigDB.btnTestClick(Sender: TObject);
var
  LicenseMgr: TLicenseManager;
  ErrMsg: string;
  PortNum: Integer;
begin
  LicenseMgr := TLicenseManager.Create(FConfigDir);
  try
    PortNum := StrToIntDef(Trim(edtPort.Text), 3050);
    LicenseMgr.SetServerConfig(
      Trim(edtHost.Text),
      Trim(edtDBPath.Text),
      PortNum,
      Trim(edtUser.Text),
      Trim(edtPassword.Text),
      Trim(cboCharset.Text),
      Trim(edtClientLib.Text)
    );

    if LicenseMgr.TestConnection(ErrMsg) then
      ShowMessage('Conexão com o Banco de Dados Firebird realizada com SUCESSO!')
    else
      MessageDlg('Erro na Conexão', 'Falha ao conectar com o banco Firebird:' + #13#10#13#10 + ErrMsg, mtError, [mbOK], 0);
  finally
    LicenseMgr.Free;
  end;
end;

procedure TfrmConfigDB.btnSaveClick(Sender: TObject);
begin
  SaveConfig;
  ShowMessage('Configurações do banco de dados salvas com sucesso!');
  ModalResult := mrOK;
end;

procedure TfrmConfigDB.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
