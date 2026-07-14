{
  frmPayment.pas - Tela de Registro, Pagamento PIX e Envio de Comprovante
}
unit frmPayment;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Clipbrd,
  uLicenseManager;

type

  { TfrmPayment }

  TfrmPayment = class(TForm)
    pnlHeader       : TPanel;
    lblTitle        : TLabel;
    pnlBody         : TPanel;
    lblInstruction  : TLabel;
    pnlPIXBox       : TPanel;
    lblPIXTitle     : TLabel;
    edtPIXKey       : TEdit;
    btnCopyPIX      : TButton;
    lblPIXDesc      : TLabel;
    lblFileTitle    : TLabel;
    edtFilePath     : TEdit;
    btnSelectFile   : TButton;
    lblObs          : TLabel;
    edtObs          : TEdit;
    btnUploadReceipt: TButton;
    lblStatusMsg    : TLabel;
    OpenDialog      : TOpenDialog;

    procedure FormCreate(Sender: TObject);
    procedure btnCopyPIXClick(Sender: TObject);
    procedure btnSelectFileClick(Sender: TObject);
    procedure btnUploadReceiptClick(Sender: TObject);
  private
    FLicenseMgr : TLicenseManager;
    FUserID     : Integer;
  public
    property LicenseManager : TLicenseManager read FLicenseMgr write FLicenseMgr;
    property UserID         : Integer         read FUserID      write FUserID;
  end;

var
  FormPayment: TfrmPayment;

implementation

{$R *.lfm}

procedure TfrmPayment.FormCreate(Sender: TObject);
begin
  FUserID := 0;
end;

procedure TfrmPayment.btnCopyPIXClick(Sender: TObject);
begin
  Clipboard.AsText := edtPIXKey.Text;
  ShowMessage('Chave PIX copiada para a área de transferência com sucesso!');
end;

procedure TfrmPayment.btnSelectFileClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    edtFilePath.Text := OpenDialog.FileName;
end;

procedure TfrmPayment.btnUploadReceiptClick(Sender: TObject);
var
  ErrMsg: string;
begin
  if Trim(edtFilePath.Text) = '' then
  begin
    ShowMessage('Por favor, selecione o arquivo do comprovante PIX (PDF ou Imagem).');
    Exit;
  end;

  if FUserID = 0 then
  begin
    ShowMessage('ID de usuário não identificado. Efetue login novamente.');
    Exit;
  end;

  lblStatusMsg.Caption := 'Enviando comprovante para o servidor VPS...';
  Application.ProcessMessages;

  if Assigned(FLicenseMgr) and FLicenseMgr.SubmitPIXReceipt(FUserID, edtFilePath.Text, edtPIXKey.Text, edtObs.Text, ErrMsg) then
  begin
    ShowMessage('Comprovante enviado com sucesso!' + #13#10 +
      'Seu pagamento foi registrado e está na fila de análise.' + #13#10 +
      'Assim que aprovado pela nossa equipe, o acesso será liberado automaticamente.');
    ModalResult := mrOK;
  end
  else
  begin
    lblStatusMsg.Caption := 'Falha no envio.';
    MessageDlg('Erro', ErrMsg, mtError, [mbOK], 0);
  end;
end;

end.
