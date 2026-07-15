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
  UserWantsLogout : Boolean;

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := 'Lazarus Portable Manager';

  {$IFDEF MSWINDOWS}
  // Configura a janela principal no Windows Taskbar para evitar erros de renderização no Explorer ao minimizar
  Application.MainFormOnTaskbar := True;
  {$ENDIF}

  // Instancia FormMain via CreateForm para definir Application.MainForm
  Application.CreateForm(TfrmMain, FormMain);
  FormMain.Hide;

  repeat
    AllowRun        := False;
    UserWantsLogout := False;
    SavedLicenseMgr := nil;

    FormLogin := TfrmLogin.Create(nil);
    try
      if FormLogin.ShowModal = mrOK then
      begin
        SavedLicenseMgr := FormLogin.LicenseManager;

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
      FormLogin.Free;
    end;

    if AllowRun then
    begin
      FormMain.LicenseManager := SavedLicenseMgr;
      FormMain.ShowModal;
      UserWantsLogout := FormMain.UserLoggedOut;
    end
    else
      FreeAndNil(SavedLicenseMgr);

  until not UserWantsLogout;

  Application.Terminate;
end.
