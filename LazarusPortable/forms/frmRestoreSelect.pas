unit frmRestoreSelect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  uPortableCore;

type
  TBackupItem = class
  public
    Path: string;
    IsExternal: Boolean;
    DisplayName: string;
  end;

  { TfrmRestoreSelect }

  TfrmRestoreSelect = class(TForm)
    lstBackups: TListBox;
    pnlBottom: TPanel;
    btnRestore: TButton;
    btnCancel: TButton;
    lblTitle: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FConfig: TPortableConfig;
    FSelectedPath: string;
    FSelectedIsExternal: Boolean;
    procedure SetConfig(Value: TPortableConfig);
    procedure LoadBackups;
  public
    property Config: TPortableConfig read FConfig write SetConfig;
    property SelectedPath: string read FSelectedPath;
    property SelectedIsExternal: Boolean read FSelectedIsExternal;
  end;

implementation

{$R *.lfm}

{ TfrmRestoreSelect }

procedure TfrmRestoreSelect.FormCreate(Sender: TObject);
begin
  FConfig := nil;
  FSelectedPath := '';
  FSelectedIsExternal := False;
end;

procedure TfrmRestoreSelect.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to lstBackups.Items.Count - 1 do
    lstBackups.Items.Objects[I].Free;
end;

procedure TfrmRestoreSelect.SetConfig(Value: TPortableConfig);
begin
  FConfig := Value;
  LoadBackups;
end;

procedure TfrmRestoreSelect.LoadBackups;
var
  SR: TSearchRec;
  LocalPath, ExtPath: string;
  Item: TBackupItem;
begin
  lstBackups.Clear;
  if FConfig = nil then Exit;

  // 1. Busca backups locais
  LocalPath := FConfig.BackupDir;
  if DirectoryExists(LocalPath) then
  begin
    if FindFirst(LocalPath + '*', faDirectory, SR) = 0 then
    try
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
        begin
          Item := TBackupItem.Create;
          Item.Path := LocalPath + SR.Name + PathDelim;
          Item.IsExternal := False;
          Item.DisplayName := '[Local] ' + SR.Name;
          lstBackups.Items.AddObject(Item.DisplayName, Item);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;

  // 2. Busca backups externos
  ExtPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('USERPROFILE')) + 'LazarusBackup' + PathDelim;
  if DirectoryExists(ExtPath) then
  begin
    if FindFirst(ExtPath + '*', faDirectory, SR) = 0 then
    try
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
        begin
          Item := TBackupItem.Create;
          Item.Path := ExtPath + SR.Name + PathDelim;
          Item.IsExternal := True;
          Item.DisplayName := '[Externo] ' + SR.Name;
          lstBackups.Items.AddObject(Item.DisplayName, Item);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure TfrmRestoreSelect.btnRestoreClick(Sender: TObject);
var
  Idx: Integer;
  Item: TBackupItem;
begin
  Idx := lstBackups.ItemIndex;
  if Idx < 0 then
  begin
    ShowMessage('Por favor, selecione um backup para restaurar.');
    Exit;
  end;

  Item := TBackupItem(lstBackups.Items.Objects[Idx]);
  FSelectedPath := Item.Path;
  FSelectedIsExternal := Item.IsExternal;
  ModalResult := mrOK;
end;

procedure TfrmRestoreSelect.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
