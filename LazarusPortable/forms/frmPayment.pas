{
  frmPayment.pas - Tela de Registro, Pagamento PIX com QR Code & Copia e Cola
}
unit frmPayment;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Clipbrd,
  fphttpclient, opensslsockets, HTTPDefs, uLicenseManager, uPIXPayload;

type

  { TfrmPayment }

  TfrmPayment = class(TForm)
    pnlHeader       : TPanel;
    lblTitle        : TLabel;
    pnlBody         : TPanel;
    lblInstruction  : TLabel;
    pnlPIXBox       : TPanel;
    lblPIXTitle     : TLabel;
    imgQRCode       : TImage;
    lblCopyTitle    : TLabel;
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
    procedure FormShow(Sender: TObject);
    procedure btnCopyPIXClick(Sender: TObject);
    procedure btnSelectFileClick(Sender: TObject);
    procedure btnUploadReceiptClick(Sender: TObject);
  private
    FLicenseMgr : TLicenseManager;
    FUserID     : Integer;
    procedure LoadQRCodeImage(const APayload: string);
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

procedure TfrmPayment.FormShow(Sender: TObject);
var
  Conf: TPIXConfigInfo;
  EMVPayload: string;
begin
  if Assigned(FLicenseMgr) then
  begin
    Conf := FLicenseMgr.GetPIXConfig;
    if Trim(Conf.ChavePIX) <> '' then
    begin
      EMVPayload := TPIXPayloadGenerator.GeneratePayload(
        Conf.ChavePIX, Conf.Titular, 'SAO PAULO', Conf.ValorLicenca
      );
      edtPIXKey.Text := EMVPayload;
      lblPIXDesc.Caption := Format('Chave PIX: %s (%s)' + #13#10 + 'Valor: R$ %.2f | %s' + #13#10 + 'Titular: %s',
        [Conf.ChavePIX, Conf.TipoChave, Conf.ValorLicenca, Conf.Banco, Conf.Titular]);

      LoadQRCodeImage(EMVPayload);
    end;
  end;
end;

procedure TfrmPayment.LoadQRCodeImage(const APayload: string);
var
  HTTP: TFPHttpClient;
  Stream: TMemoryStream;
  Url: string;
begin
  Url := 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=' + HTTPEncode(APayload);
  HTTP := TFPHttpClient.Create(nil);
  Stream := TMemoryStream.Create;
  try
    try
      HTTP.Get(Url, Stream);
      Stream.Position := 0;
      imgQRCode.Picture.LoadFromStream(Stream);
    except
      // Se não houver internet ou se falhar o download do QR Code, a chave Copia e Cola continuará 100% funcional
    end;
  finally
    Stream.Free;
    HTTP.Free;
  end;
end;

procedure TfrmPayment.btnCopyPIXClick(Sender: TObject);
begin
  Clipboard.AsText := edtPIXKey.Text;
  ShowMessage('Código PIX Copia e Cola copiado para a área de transferência com sucesso!');
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
