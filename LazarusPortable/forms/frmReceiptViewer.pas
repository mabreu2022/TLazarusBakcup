{
  frmReceiptViewer.pas - Visualizador Modal de Comprovantes PIX (com Zoom e Suporte a PDF/Imagens)
}
unit frmReceiptViewer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LCLIntf, uLicenseManager;

type

  { TfrmReceiptViewer }

  TfrmReceiptViewer = class(TForm)
    pnlHeader   : TPanel;
    lblFileName : TLabel;
    btnZoomIn   : TButton;
    btnZoomOut  : TButton;
    btnResetZoom: TButton;
    lblZoomLevel: TLabel;
    btnSave     : TButton;
    btnClose    : TButton;
    pnlBody     : TPanel;
    pnlPDFNotice: TPanel;
    lblPDFMsg   : TLabel;
    btnOpenPDF  : TButton;
    ScrollBox   : TScrollBox;
    imgReceipt  : TImage;
    SaveDialog  : TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);
    procedure btnResetZoomClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnOpenPDFClick(Sender: TObject);
  private
    FLicenseMgr     : TLicenseManager;
    FReceiptID      : Integer;
    FFileName       : string;
    FFileData       : TMemoryStream;
    FOriginalWidth  : Integer;
    FOriginalHeight : Integer;
    FZoomPercent    : Integer;
    FIsPDF          : Boolean;
    FOriginalLoaded : Boolean;

    procedure LoadReceiptData;
    procedure ApplyZoom;
  public
    property LicenseManager : TLicenseManager read FLicenseMgr write FLicenseMgr;
    property ReceiptID      : Integer         read FReceiptID  write FReceiptID;
  end;

var
  FormReceiptViewer: TfrmReceiptViewer;

implementation

{$R *.lfm}

procedure TfrmReceiptViewer.FormCreate(Sender: TObject);
begin
  FReceiptID      := 0;
  FZoomPercent    := 100;
  FOriginalLoaded := False;
  FIsPDF          := False;
  FFileData       := TMemoryStream.Create;
end;

procedure TfrmReceiptViewer.FormDestroy(Sender: TObject);
begin
  FFileData.Free;
end;

procedure TfrmReceiptViewer.FormShow(Sender: TObject);
begin
  LoadReceiptData;
end;

procedure TfrmReceiptViewer.LoadReceiptData;
var
  Ext: string;
begin
  if (FReceiptID <= 0) or not Assigned(FLicenseMgr) then Exit;

  FFileData.Clear;
  if not FLicenseMgr.GetReceiptBLOB(FReceiptID, FFileName, FFileData) then
  begin
    ShowMessage('Não foi possível carregar a imagem do comprovante selecionado.');
    ModalResult := mrCancel;
    Exit;
  end;

  lblFileName.Caption := Format('📜 Comprovante #%d - %s', [FReceiptID, FFileName]);
  Ext := LowerCase(ExtractFileExt(FFileName));
  FIsPDF := (Ext = '.pdf');

  if FIsPDF then
  begin
    ScrollBox.Visible := False;
    pnlPDFNotice.Visible := True;
    pnlPDFNotice.Left := (pnlBody.Width - pnlPDFNotice.Width) div 2;
    pnlPDFNotice.Top  := (pnlBody.Height - pnlPDFNotice.Height) div 2;
    btnZoomIn.Enabled  := False;
    btnZoomOut.Enabled := False;
    btnResetZoom.Enabled := False;
  end
  else
  begin
    pnlPDFNotice.Visible := False;
    ScrollBox.Visible := True;
    FFileData.Position := 0;
    try
      imgReceipt.Picture.LoadFromStream(FFileData);
      FOriginalWidth  := imgReceipt.Picture.Width;
      FOriginalHeight := imgReceipt.Picture.Height;

      if FOriginalWidth = 0 then FOriginalWidth := 600;
      if FOriginalHeight = 0 then FOriginalHeight := 800;

      FOriginalLoaded := True;
      FZoomPercent := 100;
      ApplyZoom;
    except
      on E: Exception do
        ShowMessage('Erro ao renderizar imagem do comprovante: ' + E.Message);
    end;
  end;
end;

procedure TfrmReceiptViewer.ApplyZoom;
var
  NewW, NewH: Integer;
begin
  if not FOriginalLoaded or FIsPDF then Exit;

  NewW := Round(FOriginalWidth * (FZoomPercent / 100));
  NewH := Round(FOriginalHeight * (FZoomPercent / 100));

  imgReceipt.Width := NewW;
  imgReceipt.Height := NewH;
  lblZoomLevel.Caption := Format('%d%%', [FZoomPercent]);
end;

procedure TfrmReceiptViewer.btnZoomInClick(Sender: TObject);
begin
  if FZoomPercent < 500 then
  begin
    Inc(FZoomPercent, 25);
    ApplyZoom;
  end;
end;

procedure TfrmReceiptViewer.btnZoomOutClick(Sender: TObject);
begin
  if FZoomPercent > 25 then
  begin
    Dec(FZoomPercent, 25);
    ApplyZoom;
  end;
end;

procedure TfrmReceiptViewer.btnResetZoomClick(Sender: TObject);
begin
  FZoomPercent := 100;
  ApplyZoom;
end;

procedure TfrmReceiptViewer.btnSaveClick(Sender: TObject);
begin
  SaveDialog.FileName := FFileName;
  SaveDialog.Filter := Format('%s (*%s)|*%s|Todos os arquivos (*.*)|*.*',
    [Uppercase(ExtractFileExt(FFileName)), ExtractFileExt(FFileName), ExtractFileExt(FFileName)]);

  if SaveDialog.Execute then
  begin
    try
      FFileData.SaveToFile(SaveDialog.FileName);
      ShowMessage('Comprovante salvo com sucesso em:' + #13#10 + SaveDialog.FileName);
    except
      on E: Exception do
        ShowMessage('Erro ao salvar arquivo: ' + E.Message);
    end;
  end;
end;

procedure TfrmReceiptViewer.btnOpenPDFClick(Sender: TObject);
var
  TempPath: string;
begin
  TempPath := GetTempDir + FFileName;
  try
    FFileData.SaveToFile(TempPath);
    OpenURL('file:///' + StringReplace(TempPath, '\', '/', [rfReplaceAll]));
  except
    on E: Exception do
      ShowMessage('Erro ao abrir o arquivo PDF: ' + E.Message);
  end;
end;

procedure TfrmReceiptViewer.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
