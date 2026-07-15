{
  uConfigCrypt.pas - Criptografia XOR para arquivos de configuração
  Protege credenciais de banco de dados no arquivo vps_config.ini
  Usa apenas AnsiString para evitar problemas de conversão Unicode no FPC.
}
unit uConfigCrypt;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, sha1;

type
  { TConfigCrypt }
  TConfigCrypt = class
  private
    class function DeriveKey: AnsiString;
    class function XORBytes(const AData, AKey: AnsiString): AnsiString;
    class function BytesToHex(const AStr: AnsiString): AnsiString;
    class function HexToBytes(const AHex: AnsiString): AnsiString;
    class function IsValidHex(const AHex: AnsiString): Boolean;
  public
    { Salva um valor criptografado em uma chave de seção do INI }
    class procedure WriteEncrypted(const AFilePath, ASection, AKey, AValue: string);
    { Lê e descriptografa um valor de uma chave de seção do INI }
    class function  ReadEncrypted(const AFilePath, ASection, AKey, ADefault: string): string;
    { Varre o arquivo INI e garante que todos os campos estejam encriptados }
    class procedure MigrateAndEncrypt(const AFilePath: string);
  end;

implementation

{ Deriva uma chave de criptografia a partir do salt fixo do app }
class function TConfigCrypt.DeriveKey: AnsiString;
const
  APP_SALT = 'LazPortableManager_2026_!@#XY';
begin
  Result := AnsiString(SHA1Print(SHA1String(APP_SALT)));
end;

{ Verifica se uma string contém apenas caracteres hexadecimais pares }
class function TConfigCrypt.IsValidHex(const AHex: AnsiString): Boolean;
var
  I: Integer;
begin
  if (Length(AHex) = 0) or (Length(AHex) mod 2 <> 0) then Exit(False);
  for I := 1 to Length(AHex) do
    if not (AHex[I] in ['0'..'9', 'A'..'F', 'a'..'f']) then
      Exit(False);
  Result := True;
end;

{ Cifra / decifra XOR de AnsiString usando a chave }
class function TConfigCrypt.XORBytes(const AData, AKey: AnsiString): AnsiString;
var
  I, KeyLen: Integer;
begin
  if AKey = '' then
  begin
    Result := AData;
    Exit;
  end;
  KeyLen := Length(AKey);
  SetLength(Result, Length(AData));
  for I := 1 to Length(AData) do
    Result[I] := AnsiChar(Ord(AData[I]) xor Ord(AKey[((I - 1) mod KeyLen) + 1]));
end;

{ Converte bytes para string hexadecimal }
class function TConfigCrypt.BytesToHex(const AStr: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AStr) do
    Result := Result + AnsiString(IntToHex(Ord(AStr[I]), 2));
end;

{ Converte string hexadecimal para bytes }
class function TConfigCrypt.HexToBytes(const AHex: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I + 1 <= Length(AHex) do
  begin
    Result := Result + AnsiChar(StrToIntDef('$' + string(AHex[I]) + string(AHex[I+1]), 0));
    Inc(I, 2);
  end;
end;

{ Grava valor criptografado no INI (apenas para campos sensíveis) }
class procedure TConfigCrypt.WriteEncrypted(const AFilePath, ASection, AKey, AValue: string);
var
  Ini      : TIniFile;
  CryptKey : AnsiString;
  Encrypted: AnsiString;
  Encoded  : AnsiString;
begin
  CryptKey  := DeriveKey;
  Encrypted := XORBytes(AnsiString(AValue), CryptKey);
  Encoded   := BytesToHex(Encrypted);

  Ini := TIniFile.Create(AFilePath);
  try
    Ini.WriteString(ASection, AKey, 'ENC:' + string(Encoded));
  finally
    Ini.Free;
  end;
end;

{ Lê e descriptografa valor do INI. Se começar com ENC:, descriptografa. Se for legadão em texto puro, retorna o valor puro. }
class function TConfigCrypt.ReadEncrypted(const AFilePath, ASection, AKey, ADefault: string): string;
var
  Ini      : TIniFile;
  CryptKey : AnsiString;
  RawVal   : string;
  Encoded  : AnsiString;
  Encrypted: AnsiString;
begin
  Ini := TIniFile.Create(AFilePath);
  try
    RawVal := Ini.ReadString(ASection, AKey, '');
  finally
    Ini.Free;
  end;

  if RawVal = '' then
  begin
    Result := ADefault;
    Exit;
  end;

  if (Length(RawVal) > 4) and (Copy(RawVal, 1, 4) = 'ENC:') then
  begin
    Encoded   := AnsiString(Copy(RawVal, 5, Length(RawVal) - 4));
    CryptKey  := DeriveKey;
    Encrypted := HexToBytes(Encoded);
    Result    := string(XORBytes(Encrypted, CryptKey));
  end
  else
    Result := RawVal; // Texto puro (legado ou não migrado)
end;

class procedure TConfigCrypt.MigrateAndEncrypt(const AFilePath: string);
var
  Ini: TIniFile;
  HostRaw, PortRaw: string;
  Host, Port, PathVal, User, Pass, Charset, ClientLib: string;
  NeedsMigration: Boolean;
begin
  if not FileExists(AFilePath) then Exit;

  Ini := TIniFile.Create(AFilePath);
  try
    HostRaw := Ini.ReadString('Database', 'Host', '');
    PortRaw := Ini.ReadString('Database', 'Port', '');

    NeedsMigration := False;

    if Ini.SectionExists('VPS') then
      NeedsMigration := True;

    if (HostRaw <> '') and (Copy(HostRaw, 1, 4) <> 'ENC:') then
      NeedsMigration := True;

    if (PortRaw <> '') and (Copy(PortRaw, 1, 4) <> 'ENC:') then
      NeedsMigration := True;

    if not NeedsMigration then Exit;
  finally
    Ini.Free;
  end;

  Host      := ReadEncrypted(AFilePath, 'Database', 'Host', '');
  if Host = '' then Host := ReadEncrypted(AFilePath, 'VPS', 'Host', '127.0.0.1');

  Port      := ReadEncrypted(AFilePath, 'Database', 'Port', '');
  if Port = '' then Port := ReadEncrypted(AFilePath, 'VPS', 'Port', '3050');

  PathVal   := ReadEncrypted(AFilePath, 'Database', 'Path', '');
  if PathVal = '' then PathVal := ReadEncrypted(AFilePath, 'VPS', 'DatabasePath', '');
  if PathVal = '' then PathVal := ReadEncrypted(AFilePath, 'VPS', 'Path', 'C:\Fontes\Componentes\TLazarusBakcup\Database\LazarusBackup.fdb');

  User      := ReadEncrypted(AFilePath, 'Database', 'User', '');
  if User = '' then User := ReadEncrypted(AFilePath, 'VPS', 'User', 'SYSDBA');

  Pass      := ReadEncrypted(AFilePath, 'Database', 'Password', '');
  if Pass = '' then Pass := ReadEncrypted(AFilePath, 'VPS', 'Password', 'masterkey');

  Charset   := ReadEncrypted(AFilePath, 'Database', 'Charset', '');
  if Charset = '' then Charset := ReadEncrypted(AFilePath, 'VPS', 'Charset', 'UTF8');

  ClientLib := ReadEncrypted(AFilePath, 'Database', 'ClientLib', '');
  if ClientLib = '' then ClientLib := ReadEncrypted(AFilePath, 'VPS', 'ClientLib', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');

  WriteEncrypted(AFilePath, 'Database', 'Host',      Host);
  WriteEncrypted(AFilePath, 'Database', 'Port',      Port);
  WriteEncrypted(AFilePath, 'Database', 'Path',      PathVal);
  WriteEncrypted(AFilePath, 'Database', 'User',      User);
  WriteEncrypted(AFilePath, 'Database', 'Password',  Pass);
  WriteEncrypted(AFilePath, 'Database', 'Charset',   Charset);
  WriteEncrypted(AFilePath, 'Database', 'ClientLib', ClientLib);

  Ini := TIniFile.Create(AFilePath);
  try
    if Ini.SectionExists('VPS') then
      Ini.EraseSection('VPS');
  finally
    Ini.Free;
  end;
end;

end.
