program LazarusPortable;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // LCL
  Forms, SysUtils, Controls,
  frmMain          in 'forms\frmMain.pas' {frmMain},
  frmLogin         in 'forms\frmLogin.pas' {frmLogin},
  frmPayment       in 'forms\frmPayment.pas' {frmPayment},
  uLicenseManager  in 'units\uLicenseManager.pas',
  uPortableCore    in 'units\uPortableCore.pas',
  uPackageManager  in 'units\uPackageManager.pas',
  uProfileManager  in 'units\uProfileManager.pas',
  uDiagnostics     in 'units\uDiagnostics.pas',
  uLauncher        in 'units\uLauncher.pas';

{$R *.res}

var
  FormLogin       : TfrmLogin;
  FormPayment     : TfrmPayment;
  SavedLicenseMgr : TLicenseManager;
  AllowRun        : Boolean;

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'Lazarus Portable Manager';

  AllowRun        := False;
  SavedLicenseMgr := nil;

  FormLogin := TfrmLogin.Create(nil);
  try
    if FormLogin.ShowModal = mrOK then
    begin
      SavedLicenseMgr := FormLogin.LicenseManager; // salva referência antes do Free

      if FormLogin.LicenseInfo.Status in [lsTrialActive, lsLicensed] then
        AllowRun := True
      else
      begin
        // Trial ou Licença expirados -> abre tela de pagamento PIX
        FormPayment := TfrmPayment.Create(nil);
        try
          FormPayment.LicenseManager := SavedLicenseMgr;
          FormPayment.UserID         := FormLogin.LicenseInfo.UserID;
          FormPayment.ShowModal;
        finally
          FormPayment.Free;
        end;
      end;
    end;
  finally
    FormLogin.Free; // libera o formulário mas NÃO o LicenseManager (SavedLicenseMgr ainda aponta para ele)
  end;

  if AllowRun then
  begin
    Application.CreateForm(TfrmMain, FormMain);
    FormMain.LicenseManager := SavedLicenseMgr; // passa para o FormMain controlar
    Application.Run;
    // SavedLicenseMgr será liberado quando o App fechar (está em FormMain)
  end
  else
    FreeAndNil(SavedLicenseMgr);
end.
