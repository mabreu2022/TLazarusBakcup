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
    Ini.WriteString(ASection, AKey, string(Encoded));
  finally
    Ini.Free;
  end;
end;

{ Lê e descriptografa valor do INI. Se não for Hex válido (ex: .ini legado sem criptografia), retorna o valor puro. }
class function TConfigCrypt.ReadEncrypted(const AFilePath, ASection, AKey, ADefault: string): string;
var
  Ini      : TIniFile;
  CryptKey : AnsiString;
  Encoded  : AnsiString;
  Encrypted: AnsiString;
begin
  Ini := TIniFile.Create(AFilePath);
  try
    Encoded := AnsiString(Ini.ReadString(ASection, AKey, ''));
  finally
    Ini.Free;
  end;

  if Encoded = '' then
  begin
    Result := ADefault;
    Exit;
  end;

  // Fallback para arquivo ini legadão em texto puro (ex: "SYSDBA" ou "masterkey")
  if not IsValidHex(Encoded) then
  begin
    Result := string(Encoded);
    Exit;
  end;

  CryptKey  := DeriveKey;
  Encrypted := HexToBytes(Encoded);
  Result    := string(XORBytes(Encrypted, CryptKey));
end;

end.
