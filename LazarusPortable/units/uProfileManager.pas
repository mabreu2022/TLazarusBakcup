{
  uProfileManager.pas - Gerenciamento de perfis do Lazarus portável
  =================================================================
  Permite múltiplos perfis de configuração (ex: Dev, Produção, Cliente A)
  Cada perfil é uma pasta separada dentro do diretório portável.
}
unit uProfileManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, FileUtil, LazFileUtils;

const
  PROFILES_DIR    = 'Profiles';
  PROFILE_INI     = 'profile.ini';
  ACTIVE_PROFILE  = 'active_profile.ini';

type
  TProfileInfo = record
    Name        : string;
    Description : string;
    ConfigDir   : string;   // Pasta completa de configuração deste perfil
    CreatedAt   : TDateTime;
    LastUsed    : TDateTime;
    IsActive    : Boolean;
  end;

  TProfileArray = array of TProfileInfo;

  { TProfileManager }
  TProfileManager = class
  private
    FPortableDir  : string;
    FProfilesDir  : string;
    FActiveProfile: string;

    function  GetProfileDir(const AName: string): string;
    function  LoadProfileINI(const AName: string): TProfileInfo;
    procedure SaveProfileINI(const AProfile: TProfileInfo);
  public
    constructor Create(const APortableDir: string);

    { Lista todos os perfis disponíveis }
    function  ListProfiles: TProfileArray;

    { Operações de perfil }
    function  CreateProfile(const AName, ADescription: string): Boolean;
    function  DeleteProfile(const AName: string): Boolean;
    function  RenameProfile(const AOldName, ANewName: string): Boolean;
    function  DuplicateProfile(const ASourceName, ANewName: string): Boolean;

    { Ativar perfil (copia config para LazarusConfig) }
    function  ActivateProfile(const AName: string): Boolean;

    { Salvar estado atual como perfil }
    function  SaveCurrentAsProfile(const AName: string): Boolean;

    { Perfil ativo }
    function  GetActiveProfileName: string;
    function  GetActiveProfile: TProfileInfo;
    procedure SetActiveProfile(const AName: string);

    property PortableDir  : string read FPortableDir;
    property ProfilesDir  : string read FProfilesDir;
    property ActiveProfile: string read FActiveProfile write SetActiveProfile;
  end;

implementation

constructor TProfileManager.Create(const APortableDir: string);
var
  INI: TIniFile;
begin
  inherited Create;
  FPortableDir := IncludeTrailingPathDelimiter(APortableDir);
  FProfilesDir := FPortableDir + PROFILES_DIR + PathDelim;

  if not DirectoryExists(FProfilesDir) then
    ForceDirectories(FProfilesDir);

  // Lê o perfil ativo do INI raiz
  INI := TIniFile.Create(FPortableDir + ACTIVE_PROFILE);
  try
    FActiveProfile := INI.ReadString('Profile', 'Active', 'Padrão');
  finally
    INI.Free;
  end;
end;

function TProfileManager.GetProfileDir(const AName: string): string;
begin
  Result := FProfilesDir + AName + PathDelim;
end;

function TProfileManager.LoadProfileINI(const AName: string): TProfileInfo;
var
  INI     : TIniFile;
  ProfDir : string;
begin
  ProfDir := GetProfileDir(AName);
  Result.Name      := AName;
  Result.ConfigDir := ProfDir;
  Result.IsActive  := SameText(AName, FActiveProfile);

  if FileExists(ProfDir + PROFILE_INI) then
  begin
    INI := TIniFile.Create(ProfDir + PROFILE_INI);
    try
      Result.Description := INI.ReadString('Profile', 'Description', '');
      Result.CreatedAt   := INI.ReadDateTime('Profile', 'CreatedAt', Now);
      Result.LastUsed    := INI.ReadDateTime('Profile', 'LastUsed', 0);
    finally
      INI.Free;
    end;
  end
  else
  begin
    Result.Description := '';
    Result.CreatedAt   := Now;
    Result.LastUsed    := 0;
  end;
end;

procedure TProfileManager.SaveProfileINI(const AProfile: TProfileInfo);
var
  INI: TIniFile;
begin
  ForceDirectories(AProfile.ConfigDir);
  INI := TIniFile.Create(AProfile.ConfigDir + PROFILE_INI);
  try
    INI.WriteString  ('Profile', 'Name',        AProfile.Name);
    INI.WriteString  ('Profile', 'Description', AProfile.Description);
    INI.WriteDateTime('Profile', 'CreatedAt',   AProfile.CreatedAt);
    INI.WriteDateTime('Profile', 'LastUsed',    AProfile.LastUsed);
  finally
    INI.Free;
  end;
end;

function TProfileManager.ListProfiles: TProfileArray;
var
  SR : TSearchRec;
  I  : Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  I := 0;

  if FindFirst(FProfilesDir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and
         (SR.Attr and faDirectory <> 0) then
      begin
        SetLength(Result, I + 1);
        Result[I] := LoadProfileINI(SR.Name);
        Inc(I);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  // Se não há perfis, cria o padrão
  if Length(Result) = 0 then
  begin
    CreateProfile('Padrão', 'Perfil de configuração padrão');
    SetLength(Result, 1);
    Result[0] := LoadProfileINI('Padrão');
  end;
end;

function TProfileManager.CreateProfile(const AName, ADescription: string): Boolean;
var
  Prof: TProfileInfo;
begin
  Result := False;
  if DirectoryExists(GetProfileDir(AName)) then Exit; // Já existe

  Prof.Name        := AName;
  Prof.Description := ADescription;
  Prof.ConfigDir   := GetProfileDir(AName);
  Prof.CreatedAt   := Now;
  Prof.LastUsed    := 0;
  Prof.IsActive    := False;

  ForceDirectories(Prof.ConfigDir);
  SaveProfileINI(Prof);
  Result := True;
end;

function TProfileManager.DeleteProfile(const AName: string): Boolean;
begin
  Result := False;
  if SameText(AName, FActiveProfile) then Exit; // Não deleta perfil ativo
  if not DirectoryExists(GetProfileDir(AName)) then Exit;

  Result := DeleteDirectory(GetProfileDir(AName), False);
end;

function TProfileManager.RenameProfile(const AOldName, ANewName: string): Boolean;
begin
  Result := False;
  if not DirectoryExists(GetProfileDir(AOldName)) then Exit;
  if DirectoryExists(GetProfileDir(ANewName)) then Exit;

  Result := RenameFile(GetProfileDir(AOldName), GetProfileDir(ANewName));
  if Result and SameText(AOldName, FActiveProfile) then
    SetActiveProfile(ANewName);
end;

function TProfileManager.DuplicateProfile(const ASourceName, ANewName: string): Boolean;
var
  Prof: TProfileInfo;
begin
  Result := False;
  if not DirectoryExists(GetProfileDir(ASourceName)) then Exit;
  if DirectoryExists(GetProfileDir(ANewName)) then Exit;

  Result := CopyDirTree(GetProfileDir(ASourceName),
    GetProfileDir(ANewName), [cffCreateDestDirectory]);

  if Result then
  begin
    Prof := LoadProfileINI(ANewName);
    Prof.Name     := ANewName;
    Prof.CreatedAt := Now;
    SaveProfileINI(Prof);
  end;
end;

{ Ativa um perfil: copia seus arquivos de config para LazarusConfig }
function TProfileManager.ActivateProfile(const AName: string): Boolean;
var
  SrcDir : string;
  DstDir : string;
  Prof   : TProfileInfo;
begin
  Result := False;
  SrcDir := GetProfileDir(AName);
  DstDir := FPortableDir + 'LazarusConfig' + PathDelim;

  if not DirectoryExists(SrcDir) then Exit;

  // Copia todos os arquivos de config do perfil para LazarusConfig
  Result := CopyDirTree(SrcDir, DstDir, [cffOverwriteFile]);

  if Result then
  begin
    SetActiveProfile(AName);

    // Atualiza LastUsed
    Prof := LoadProfileINI(AName);
    Prof.LastUsed := Now;
    SaveProfileINI(Prof);
  end;
end;

{ Salva a configuração atual como um perfil }
function TProfileManager.SaveCurrentAsProfile(const AName: string): Boolean;
var
  SrcDir : string;
  DstDir : string;
  Prof   : TProfileInfo;
begin
  SrcDir := FPortableDir + 'LazarusConfig' + PathDelim;
  DstDir := GetProfileDir(AName);

  if not DirectoryExists(SrcDir) then Exit(False);
  ForceDirectories(DstDir);

  Result := CopyDirTree(SrcDir, DstDir, [cffOverwriteFile]);

  if Result then
  begin
    Prof.Name        := AName;
    Prof.Description := 'Salvo em ' + FormatDateTime('dd/mm/yyyy hh:nn', Now);
    Prof.ConfigDir   := DstDir;
    Prof.CreatedAt   := Now;
    Prof.LastUsed    := Now;
    Prof.IsActive    := False;
    SaveProfileINI(Prof);
  end;
end;

function TProfileManager.GetActiveProfileName: string;
begin
  Result := FActiveProfile;
end;

function TProfileManager.GetActiveProfile: TProfileInfo;
begin
  Result := LoadProfileINI(FActiveProfile);
end;

procedure TProfileManager.SetActiveProfile(const AName: string);
var
  INI: TIniFile;
begin
  FActiveProfile := AName;
  INI := TIniFile.Create(FPortableDir + ACTIVE_PROFILE);
  try
    INI.WriteString('Profile', 'Active', AName);
  finally
    INI.Free;
  end;
end;

end.
