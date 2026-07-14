program LazarusPortable;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // LCL
  Forms, SysUtils,
  frmMain in 'forms\frmMain.pas' {frmMain},
  uPortableCore    in 'units\uPortableCore.pas',
  uPackageManager  in 'units\uPackageManager.pas',
  uProfileManager  in 'units\uProfileManager.pas',
  uDiagnostics     in 'units\uDiagnostics.pas',
  uLauncher        in 'units\uLauncher.pas';

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, FormMain);
  Application.Title := 'Lazarus Portable Manager';
  Application.Run;
end.
