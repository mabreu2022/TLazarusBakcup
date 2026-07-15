{
  uPIXPayload.pas - Gerador NATIVO de Payload EMV BRCode / PIX Copia e Cola
  ========================================================================
  Gera a string oficial EMV PIX com algoritmo CRC16-CCITT (Padrão Banco Central)
}
unit uPIXPayload;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  { TPIXPayloadGenerator }
  TPIXPayloadGenerator = class
  private
    class function FormatPixKey(const AKey: string): string;
    class function NormalizeText(const AText: string; AMaxLength: Integer): string;
    class function FormatEMV(const AID, AValue: string): string;
    class function CalculateCRC16(const APayload: string): string;
  public
    class function GeneratePayload(const APixKey, AMerchantName, AMerchantCity: string;
      AAmount: Double; const ATxID: string = '***'): string;
  end;

implementation

class function TPIXPayloadGenerator.FormatPixKey(const AKey: string): string;
var
  S, Nums: string;
  I: Integer;
begin
  S := Trim(AKey);
  if (Pos('@', S) > 0) or (Pos('-', S) > 0) or (Copy(S, 1, 1) = '+') then
    Exit(S);

  Nums := '';
  for I := 1 to Length(S) do
    if S[I] in ['0'..'9'] then
      Nums := Nums + S[I];

  if Length(Nums) = 11 then
    Result := '+55' + Nums
  else if (Length(Nums) = 13) and (Copy(Nums, 1, 2) = '55') then
    Result := '+' + Nums
  else
    Result := S;
end;

class function TPIXPayloadGenerator.NormalizeText(const AText: string; AMaxLength: Integer): string;
var
  I: Integer;
  S, Res: string;
begin
  S := UpperCase(AText);
  S := StringReplace(S, 'Á', 'A', [rfReplaceAll]);
  S := StringReplace(S, 'À', 'A', [rfReplaceAll]);
  S := StringReplace(S, 'Â', 'A', [rfReplaceAll]);
  S := StringReplace(S, 'Ã', 'A', [rfReplaceAll]);
  S := StringReplace(S, 'É', 'E', [rfReplaceAll]);
  S := StringReplace(S, 'Ê', 'E', [rfReplaceAll]);
  S := StringReplace(S, 'Í', 'I', [rfReplaceAll]);
  S := StringReplace(S, 'Ó', 'O', [rfReplaceAll]);
  S := StringReplace(S, 'Ô', 'O', [rfReplaceAll]);
  S := StringReplace(S, 'Õ', 'O', [rfReplaceAll]);
  S := StringReplace(S, 'Ú', 'U', [rfReplaceAll]);
  S := StringReplace(S, 'Ü', 'U', [rfReplaceAll]);
  S := StringReplace(S, 'Ç', 'C', [rfReplaceAll]);

  Res := '';
  for I := 1 to Length(S) do
  begin
    if S[I] in ['A'..'Z', '0'..'9', ' '] then
      Res := Res + S[I];
  end;
  if Res = '' then Res := 'ADMINISTRADOR';
  if Length(Res) > AMaxLength then
    Res := Copy(Res, 1, AMaxLength);
  Result := Trim(Res);
end;

class function TPIXPayloadGenerator.FormatEMV(const AID, AValue: string): string;
var
  LenStr: string;
begin
  LenStr := IntToStr(Length(AValue));
  if Length(LenStr) = 1 then
    LenStr := '0' + LenStr;
  Result := AID + LenStr + AValue;
end;

class function TPIXPayloadGenerator.CalculateCRC16(const APayload: string): string;
var
  CRC: Word;
  I, J: Integer;
  Poly: Word;
begin
  CRC := $FFFF;
  Poly := $1021;

  for I := 1 to Length(APayload) do
  begin
    CRC := CRC xor (Word(Ord(APayload[I])) shl 8);
    for J := 0 to 7 do
    begin
      if (CRC and $8000) <> 0 then
        CRC := Word((CRC shl 1) xor Poly)
      else
        CRC := Word(CRC shl 1);
    end;
  end;

  Result := UpperCase(IntToHex(CRC, 4));
end;

class function TPIXPayloadGenerator.GeneratePayload(const APixKey, AMerchantName, AMerchantCity: string;
  AAmount: Double; const ATxID: string): string;
var
  Payload: string;
  GUI, Key, AccountInfo: string;
  TxEMV, AdditionalData: string;
  AmountStr: string;
  CleanName, CleanCity, FormattedKey: string;
  FS: TFormatSettings;
begin
  FormattedKey := FormatPixKey(APixKey);
  CleanName    := NormalizeText(AMerchantName, 25);
  CleanCity    := NormalizeText(AMerchantCity, 15);

  // 00 - Format Indicator
  Payload := FormatEMV('00', '01');

  // 26 - Merchant Account Info (PIX)
  GUI := FormatEMV('00', 'br.gov.bcb.pix');
  Key := FormatEMV('01', FormattedKey);
  AccountInfo := FormatEMV('26', GUI + Key);
  Payload := Payload + AccountInfo;

  // 52 - Merchant Category Code
  Payload := Payload + FormatEMV('52', '0000');

  // 53 - Currency (986 = BRL)
  Payload := Payload + FormatEMV('53', '986');

  // 54 - Amount
  if AAmount > 0 then
  begin
    FS := DefaultFormatSettings;
    FS.DecimalSeparator := '.';
    AmountStr := FloatToStrF(AAmount, ffFixed, 15, 2, FS);
    Payload := Payload + FormatEMV('54', AmountStr);
  end;

  // 58 - Country Code
  Payload := Payload + FormatEMV('58', 'BR');

  // 59 - Merchant Name
  Payload := Payload + FormatEMV('59', CleanName);

  // 60 - Merchant City
  Payload := Payload + FormatEMV('60', CleanCity);

  // 62 - Additional Data (TXID)
  TxEMV := FormatEMV('05', ATxID);
  AdditionalData := FormatEMV('62', TxEMV);
  Payload := Payload + AdditionalData;

  // 63 - CRC16
  Payload := Payload + '6304';
  Payload := Payload + CalculateCRC16(Payload);

  Result := Payload;
end;

end.
