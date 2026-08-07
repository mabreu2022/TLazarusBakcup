{
  uLicenseManager.pas - Gerenciador de Autenticação, HWID, Trial e Licenciamento Firebird
}
unit uLicenseManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, IniFiles, Windows, registry, sha1, db,
  sqldb, ibconnection, uConfigCrypt, fphttpclient, opensslsockets, fpjson, jsonparser, dateutils;

const
  SUPER_ADMIN_EMAIL = 'conectsolutions@hotmail.com';

type
  TLicenseStatus = (
    lsTrialActive,      // Período de 10 dias de testes ativo
    lsLicensed,         // Licença paga ativa
    lsTrialExpired,     // Período de 10 dias de testes expirou
    lsLicenseExpired,   // Licença paga expirou
    lsPendingApproval,  // Comprovante enviado, aguardando aprovação do PIX
    lsNotAuthenticated  // Usuário não logado
  );

  TLicenseInfo = record
    Status        : TLicenseStatus;
    DaysRemaining : Integer;
    ExpirationDate: TDateTime;
    UserID        : Integer;
    UserName      : string;
    UserEmail     : string;
    HWID          : string;
    IsAdmin       : Boolean;
    Message       : string;
  end;

  TPaymentReceiptInfo = record
    ID           : Integer;
    UserID       : Integer;
    UserName     : string;
    UserEmail    : string;
    DataEnvio    : TDateTime;
    ChavePIX     : string;
    ValorPago    : Double;
    NomeArquivo  : string;
    StatusAnalise: string; // 'AGUARDANDO_APROVACAO', 'APROVADO', 'REJEITADO'
    Observacao   : string;
  end;

  TPaymentReceiptArray = array of TPaymentReceiptInfo;

  TPIXConfigInfo = record
    ChavePIX     : string;
    TipoChave    : string;
    Titular      : string;
    Banco        : string;
    ValorLicenca : Double;
    Instrucoes   : string;
  end;

  { TLicenseManager }
  TLicenseManager = class
  private
    FHost         : string;
    FDatabasePath : string;
    FPort         : Integer;
    FDBUser       : string;
    FDBPassword   : string;
    FCharset      : string;
    FClientLib    : string;
    FConfigDir    : string;
    FConnection   : TIBConnection;
    FTransaction  : TSQLTransaction;
    FLastLicense  : TLicenseInfo;
    FIsAdmin      : Boolean;
    FUserEmail    : string;
    FLastError    : string;
    FToken        : string;

    function  GetHardwareID: string;
    function  HashPassword(const APassword: string): string;
    function  InitConnection: Boolean;
    procedure CloseConnection;
    procedure LoadConfigFromINI;
    function  APIRequest(const AEndpoint: string; const AMethod: string; const ABodyJSON: string; out AResponseJSON: string; AToken: string = ''): Boolean;

  public
    constructor Create(const AConfigDir: string);
    destructor  Destroy; override;

    { Configuração de servidor VPS / Banco Local Firebird }
    procedure SetServerConfig(const AHost, ADatabasePath: string;
                APort: Integer = 3050; const AUser: string = 'SYSDBA';
                const APassword: string = 'masterkey';
                const ACharset: string = 'UTF8';
                const AClientLib: string = '');

    function TestConnection(out AErrorMsg: string): Boolean;

    { Validação do Período de Testes Local (10 Dias) }
    function CheckLocalTrial: TLicenseInfo;

    { Autenticação no Banco de Dados Remoto }
    function Authenticate(const AEmail, APassword: string; out AInfo: TLicenseInfo): Boolean;

    { Cadastro de Novo Usuário com Trial de 10 Dias }
    function RegisterUser(const AName, AEmail, APassword: string; out AInfo: TLicenseInfo; out AErrorMsg: string): Boolean;

    { Envio e Controle de Comprovantes PIX }
    function SubmitPIXReceipt(AUserID: Integer; const AFilePath, AChavePIX, AObs: string; out AErrorMsg: string): Boolean;
    function GetUserReceipts(AUserID: Integer; AAllUsers: Boolean = False): TPaymentReceiptArray;
    function ApproveReceipt(AReceiptID, AUserID: Integer; ADaysToAdd: Integer; const AObs: string): Boolean;
    function RejectReceipt(AReceiptID: Integer; const AObs: string): Boolean;
    function GetReceiptBLOB(AReceiptID: Integer; out AFileName: string; AStream: TStream): Boolean;

    { Gestão de Configuração de PIX do Administrador }
    function GetPIXConfig: TPIXConfigInfo;
    function SavePIXConfig(const AConfig: TPIXConfigInfo): Boolean;

    property Connection    : TIBConnection read FConnection;
    property CurrentLicense: TLicenseInfo  read FLastLicense;
    property LastError     : string        read FLastError;
    function IsAdminUser: Boolean;
  end;

implementation

function TLicenseManager.IsAdminUser: Boolean;
begin
  Result := FIsAdmin or FLastLicense.IsAdmin or
            SameText(Trim(FUserEmail), SUPER_ADMIN_EMAIL) or
            SameText(Trim(FLastLicense.UserEmail), SUPER_ADMIN_EMAIL);
end;

{ Retorna HWID único da máquina combinando Volume Serial e Nome do Computador }
function TLicenseManager.GetHardwareID: string;
var
  VolName, FSName: array[0..MAX_PATH] of WideChar;
  VolSerial, MaxCompLen, FileSysFlags: DWORD;
  CompName: array[0..MAX_PATH] of WideChar;
  CompLen: DWORD;
  RawID: string;
begin
  VolSerial    := 0;
  MaxCompLen   := 0;
  FileSysFlags := 0;
  GetVolumeInformationW('C:\', @VolName[0], MAX_PATH, @VolSerial, MaxCompLen, FileSysFlags, @FSName[0], MAX_PATH);
  CompLen := MAX_PATH;
  GetComputerNameW(@CompName[0], CompLen);

  RawID := IntToHex(VolSerial, 8) + '-' + String(WideString(@CompName[0]));
  Result := SHA1Print(SHA1String(RawID));
end;

function TLicenseManager.HashPassword(const APassword: string): string;
begin
  Result := SHA1Print(SHA1String('LazPortable_' + APassword + '_Salt2026'));
end;

procedure TLicenseManager.LoadConfigFromINI;
var
  ConfigFile: string;
begin
  ConfigFile := FConfigDir + 'vps_config.ini';
  if FileExists(ConfigFile) then
  begin
    TConfigCrypt.MigrateAndEncrypt(ConfigFile);
    FHost         := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Host', 'localhost');
    FPort         := StrToIntDef(TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Port', '3050'), 3050);
    FDatabasePath := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Path', 'C:\Fontes\Componentes\TLazarusBakcup\Database\LazarusBackup.fdb');
    FDBUser       := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'User', 'SYSDBA');
    FDBPassword   := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Password', 'masterkey');
    FCharset      := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'Charset', 'UTF8');
    FClientLib    := TConfigCrypt.ReadEncrypted(ConfigFile, 'Database', 'ClientLib', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');
  end;
end;

constructor TLicenseManager.Create(const AConfigDir: string);
begin
  FConfigDir    := IncludeTrailingPathDelimiter(AConfigDir);
  FHost         := '127.0.0.1';
  FDatabasePath := 'C:\Fontes\Componentes\TLazarusBakcup\Database\LazarusBackup.fdb';
  FPort         := 3050;
  FDBUser       := 'SYSDBA';
  FDBPassword   := 'masterkey';

  FConnection  := TIBConnection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FConnection.Transaction := FTransaction;

  FLastLicense := Default(TLicenseInfo);
  FLastLicense.HWID := GetHardwareID;

  LoadConfigFromINI;
end;

destructor TLicenseManager.Destroy;
begin
  CloseConnection;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

procedure TLicenseManager.SetServerConfig(const AHost, ADatabasePath: string;
  APort: Integer; const AUser, APassword, ACharset, AClientLib: string);
begin
  FHost         := AHost;
  FDatabasePath := ADatabasePath;
  FPort         := APort;
  FDBUser       := AUser;
  FDBPassword   := APassword;
  FCharset      := ACharset;
  FClientLib    := AClientLib;
end;

function TLicenseManager.APIRequest(const AEndpoint: string; const AMethod: string; const ABodyJSON: string; out AResponseJSON: string; AToken: string): Boolean;
var
  HTTP: TFPHTTPClient;
  RequestStream: TStringStream;
  ResponseStream: TStringStream;
  API_URL: string;
begin
  Result := False;
  AResponseJSON := '';
  API_URL := 'https://connecttask.com.br/lazarus/api/api/v1' + AEndpoint;
  
  HTTP := TFPHTTPClient.Create(nil);
  RequestStream := TStringStream.Create(ABodyJSON);
  ResponseStream := TStringStream.Create('');
  try
    HTTP.AddHeader('Content-Type', 'application/json');
    if AToken <> '' then
      HTTP.AddHeader('Authorization', 'Bearer ' + AToken)
    else if FToken <> '' then
      HTTP.AddHeader('Authorization', 'Bearer ' + FToken);
      
    try
      if SameText(AMethod, 'POST') then
      begin
        HTTP.RequestBody := RequestStream;
        HTTP.Post(API_URL, ResponseStream);
      end
      else if SameText(AMethod, 'GET') then
      begin
        HTTP.Get(API_URL, ResponseStream);
      end;
      
      AResponseJSON := ResponseStream.DataString;
      Result := (HTTP.ResponseStatusCode = 200) or (HTTP.ResponseStatusCode = 201);
      if not Result then
        FLastError := 'HTTP error ' + IntToStr(HTTP.ResponseStatusCode) + ': ' + ResponseStream.DataString;
    except
      on E: Exception do
      begin
        FLastError := 'HTTP failed: ' + E.Message;
      end;
    end;
  finally
    HTTP.Free;
    RequestStream.Free;
    ResponseStream.Free;
  end;
end;

function TLicenseManager.InitConnection: Boolean;
begin
  Result := True;
end;

function TLicenseManager.TestConnection(out AErrorMsg: string): Boolean;
var
  Resp: string;
begin
  Result := APIRequest('/config/pix', 'GET', '', Resp);
  if not Result then
    AErrorMsg := FLastError;
end;

procedure TLicenseManager.CloseConnection;
begin
  // no-op
end;

function TLicenseManager.CheckLocalTrial: TLicenseInfo;
var
  IniFile: TIniFile;
  Reg: TRegistry;
  FirstRunStr, LastRunStr, RegFirstStr, RegLastStr: string;
  FirstRunDate, LastRunDate: TDateTime;
  DaysPassed: Integer;
  TrialFile, RegPath: string;
  ClockTampered: Boolean;
begin
  Result := Default(TLicenseInfo);
  Result.HWID := GetHardwareID;
  TrialFile := FConfigDir + 'license_info.dat';
  RegPath := 'Software\ConectSolutions\LazarusPortable';
  ClockTampered := False;

  FirstRunDate := 0;
  LastRunDate := 0;
  RegFirstStr := '';
  RegLastStr := '';

  // 1. Leitura no Registro do Windows (camada primária oculta)
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(RegPath) then
    begin
      if Reg.ValueExists('FirstActivation') then
        RegFirstStr := Reg.ReadString('FirstActivation');
      if Reg.ValueExists('LastRun') then
        RegLastStr := Reg.ReadString('LastRun');
    end;
  finally
    Reg.Free;
  end;

  // 2. Leitura no Arquivo Local INI (camada secundária)
  IniFile := TIniFile.Create(TrialFile);
  try
    FirstRunStr := IniFile.ReadString('License', 'FirstActivation', '');
    LastRunStr  := IniFile.ReadString('License', 'LastRun', '');

    // Prioriza a data do Registro se o arquivo local foi apagado ou manipulado
    if (RegFirstStr <> '') and (FirstRunStr = '') then
      FirstRunStr := RegFirstStr;

    if FirstRunStr = '' then
    begin
      FirstRunDate := Now;
      FirstRunStr := DateTimeToStr(FirstRunDate);
      IniFile.WriteString('License', 'FirstActivation', FirstRunStr);
      IniFile.WriteString('License', 'HWID', Result.HWID);
    end
    else
      FirstRunDate := StrToDateTimeDef(FirstRunStr, Now);

    // Verificação Anti-Rollback do Relógio (se voltou o relógio em mais de 1h)
    if RegLastStr <> '' then
      LastRunDate := StrToDateTimeDef(RegLastStr, 0)
    else if LastRunStr <> '' then
      LastRunDate := StrToDateTimeDef(LastRunStr, 0);

    if (LastRunDate > 0) and (Now < (LastRunDate - (1.0 / 24.0))) then
      ClockTampered := True;

    // Atualiza o timestamp do último acesso no INI
    IniFile.WriteString('License', 'LastRun', DateTimeToStr(Now));
  finally
    IniFile.Free;
  end;

  // 3. Atualiza ou cria as chaves no Registro do Windows
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(RegPath, True) then
    begin
      if not Reg.ValueExists('FirstActivation') then
        Reg.WriteString('FirstActivation', DateTimeToStr(FirstRunDate));
      Reg.WriteString('LastRun', DateTimeToStr(Now));
      Reg.WriteString('HWID', Result.HWID);
    end;
  finally
    Reg.Free;
  end;

  DaysPassed := Trunc(Now - FirstRunDate);
  Result.ExpirationDate := FirstRunDate + 10;
  Result.DaysRemaining  := 10 - DaysPassed;

  if Result.DaysRemaining < 0 then
    Result.DaysRemaining := 0;

  if ClockTampered then
  begin
    Result.Status := lsTrialExpired;
    Result.DaysRemaining := 0;
    Result.Message := 'Adulteração na data/hora do sistema detectada. O período de testes foi encerrado. Registre-se e realize o pagamento via PIX para continuar.';
  end
  else if DaysPassed < 10 then
  begin
    Result.Status := lsTrialActive;
    Result.Message := Format('Modo de Testes Gratuito Ativo (%d dias restantes)', [Result.DaysRemaining]);
  end
  else
  begin
    Result.Status := lsTrialExpired;
    Result.Message := 'Seu período de testes de 10 dias expirou. Registre-se e realize o pagamento via PIX para continuar.';
  end;

  FLastLicense := Result;
end;

function TLicenseManager.Authenticate(const AEmail, APassword: string; out AInfo: TLicenseInfo): Boolean;
var
  ReqJSON, RespJSON: string;
  JSONData: TJSONData;
  Obj, UserObj, LicObj: TJSONObject;
  StatusStr: string;
begin
  Result := False;
  AInfo := CheckLocalTrial;
  AInfo.UserEmail := Trim(AEmail);
  AInfo.IsAdmin   := SameText(Trim(AEmail), SUPER_ADMIN_EMAIL);
  
  FUserEmail := Trim(AEmail);
  if AInfo.IsAdmin then
    FIsAdmin := True;

  ReqJSON := '{"email":"' + Trim(AEmail) + '","password":"' + APassword + '"}';
  
  if not APIRequest('/auth/login', 'POST', ReqJSON, RespJSON) then
  begin
    AInfo.Status := lsNotAuthenticated;
    AInfo.Message := FLastError;
    FLastLicense := AInfo;
    Exit(False);
  end;

  try
    JSONData := GetJSON(RespJSON);
    try
      Obj := TJSONObject(JSONData);
      FToken := Obj.Get('access_token', '');
      UserObj := Obj.Objects['user'];
      AInfo.UserID := UserObj.Get('id', 0);
      AInfo.UserName := UserObj.Get('nome', '');
      AInfo.IsAdmin := UserObj.Get('is_admin', False);
      FIsAdmin := AInfo.IsAdmin;
      FUserEmail := AInfo.UserEmail;
    finally
      JSONData.Free;
    end;

    // Validate license with HWID
    ReqJSON := '{"email":"' + AInfo.UserEmail + '","hwid":"' + AInfo.HWID + '"}';
    if APIRequest('/license/validate', 'POST', ReqJSON, RespJSON) then
    begin
      JSONData := GetJSON(RespJSON);
      try
        LicObj := TJSONObject(JSONData);
        AInfo.IsAdmin := LicObj.Get('is_admin', False);
        FIsAdmin := AInfo.IsAdmin;
        
        if LicObj.Get('valid', False) then
        begin
          AInfo.Status := lsLicensed;
          AInfo.DaysRemaining := LicObj.Get('days_remaining', 0);
          AInfo.ExpirationDate := StrToDateDef(LicObj.Get('expiration_date', ''), Now + AInfo.DaysRemaining);
          AInfo.Message := Format('Licença Ativa até %s (%d dias restantes)',
            [FormatDateTime('dd/mm/yyyy', AInfo.ExpirationDate), AInfo.DaysRemaining]);
          Result := True;
        end
        else
        begin
          StatusStr := LicObj.Get('message', '');
          if SameText(StatusStr, 'Seu comprovante PIX foi enviado e está em análise. Acesso será liberado em breve.') or
             SameText(StatusStr, 'Aguardando Aprovação') or SameText(StatusStr, 'AGUARDANDO_APROVACAO') then
          begin
            AInfo.Status := lsPendingApproval;
            AInfo.Message := 'Seu comprovante PIX foi enviado e está em análise. Acesso será liberado em breve.';
          end
          else
          begin
            // Fallback for trial
            if AInfo.DaysRemaining > 0 then
            begin
              AInfo.Status := lsTrialActive;
              Result := True;
            end
            else
            begin
              AInfo.Status := lsTrialExpired;
              AInfo.Message := 'Sua licença expirou. Faça o pagamento do PIX para reativar o acesso.';
            end;
          end;
        end;
      finally
        JSONData.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      AInfo.Status := lsNotAuthenticated;
      AInfo.Message := 'Erro ao processar autenticação: ' + E.Message;
    end;
  end;

  if Result then
  begin
    FIsAdmin   := AInfo.IsAdmin;
    FUserEmail := AInfo.UserEmail;
  end;
  FLastLicense := AInfo;
end;

function TLicenseManager.RegisterUser(const AName, AEmail, APassword: string; out AInfo: TLicenseInfo; out AErrorMsg: string): Boolean;
var
  ReqJSON, RespJSON: string;
begin
  Result := False;
  AErrorMsg := '';
  AInfo := CheckLocalTrial;
  AInfo.UserEmail := Trim(AEmail);
  
  ReqJSON := '{"nome":"' + AName + '","email":"' + Trim(AEmail) + '","password":"' + APassword + '","hwid":"' + GetHardwareID() + '"}';
  
  if not APIRequest('/auth/register', 'POST', ReqJSON, RespJSON) then
  begin
    AErrorMsg := FLastError;
    Exit(False);
  end;
  
  // Authenticate immediately to fetch license
  Result := Authenticate(AEmail, APassword, AInfo);
  if not Result then
    AErrorMsg := AInfo.Message;
end;

function TLicenseManager.SubmitPIXReceipt(AUserID: Integer; const AFilePath, AChavePIX, AObs: string; out AErrorMsg: string): Boolean;
var
  HTTP: TFPHTTPClient;
  Params: TStringList;
  ResponseStream: TStringStream;
  RealUserID: Integer;
begin
  Result := False;
  AErrorMsg := '';
  RealUserID := AUserID;
  if RealUserID = 0 then
    RealUserID := FLastLicense.UserID;

  if not FileExists(AFilePath) then
  begin
    AErrorMsg := 'Arquivo de comprovante não encontrado: ' + AFilePath;
    Exit;
  end;

  Params := TStringList.Create;
  ResponseStream := TStringStream.Create('');
  HTTP := TFPHTTPClient.Create(nil);
  try
    try
      Params.Values['user_id'] := IntToStr(RealUserID);
      Params.Values['chave_pix_usada'] := AChavePIX;
      Params.Values['valor_pago'] := '49.90'; // Default license price
      
      HTTP.AddHeader('Authorization', 'Bearer ' + FToken);
      HTTP.FileFormPost('https://connecttask.com.br/lazarus/api/api/v1/payment/submit', Params, 'file', AFilePath, ResponseStream);
      
      if (HTTP.ResponseStatusCode = 200) or (HTTP.ResponseStatusCode = 201) then
      begin
        Result := True;
      end
      else
      begin
        AErrorMsg := 'Erro do servidor (' + IntToStr(HTTP.ResponseStatusCode) + '): ' + ResponseStream.DataString;
      end;
    except
      on E: Exception do
      begin
        AErrorMsg := 'Falha na conexão HTTP: ' + E.Message;
      end;
    end;
  finally
    HTTP.Free;
    Params.Free;
    ResponseStream.Free;
  end;
end;

function TLicenseManager.GetUserReceipts(AUserID: Integer; AAllUsers: Boolean): TPaymentReceiptArray;
var
  RespJSON: string;
  JSONData: TJSONData;
  JSONArray: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
begin
  SetLength(Result, 0);
  if not APIRequest('/payments', 'GET', '', RespJSON) then
    Exit;
    
  try
    JSONData := GetJSON(RespJSON);
    try
      if JSONData.JSONType = jtArray then
      begin
        JSONArray := TJSONArray(JSONData);
        SetLength(Result, JSONArray.Count);
        for I := 0 to JSONArray.Count - 1 do
        begin
          Obj := TJSONObject(JSONArray.Items[I]);
          Result[I].ID := Obj.Get('id', 0);
          Result[I].UserID := Obj.Get('usuario_id', 0);
          Result[I].UserName := Obj.Get('nome', '');
          Result[I].UserEmail := Obj.Get('email', '');
          
          // DataEnvio conversion
          try
            Result[I].DataEnvio := ScanDateTime('yyyy-mm-dd hh:nn:ss', Obj.Get('data_envio', ''));
          except
            Result[I].DataEnvio := Now;
          end;
          
          Result[I].ChavePIX := Obj.Get('chave_pix_usada', '');
          Result[I].ValorPago := Obj.Get('valor_pago', 0.0);
          Result[I].NomeArquivo := Obj.Get('nome_arquivo', '');
          Result[I].StatusAnalise := Obj.Get('status_analise', '');
          Result[I].Observacao := Obj.Get('observacao', '');
        end;
      end;
    finally
      JSONData.Free;
    end;
  except
  end;
end;

function TLicenseManager.ApproveReceipt(AReceiptID, AUserID: Integer; ADaysToAdd: Integer; const AObs: string): Boolean;
var
  ReqJSON, RespJSON: string;
begin
  ReqJSON := '{"receipt_id":' + IntToStr(AReceiptID) + ',"duration_days":' + IntToStr(ADaysToAdd) + '}';
  Result := APIRequest('/admin/payments/approve', 'POST', ReqJSON, RespJSON);
end;

function TLicenseManager.RejectReceipt(AReceiptID: Integer; const AObs: string): Boolean;
var
  ReqJSON, RespJSON: string;
begin
  ReqJSON := '{"receipt_id":' + IntToStr(AReceiptID) + ',"observation":"' + AObs + '"}';
  Result := APIRequest('/admin/payments/reject', 'POST', ReqJSON, RespJSON);
end;

function TLicenseManager.GetReceiptBLOB(AReceiptID: Integer; out AFileName: string; AStream: TStream): Boolean;
var
  HTTP: TFPHTTPClient;
  API_URL: string;
begin
  Result := False;
  AFileName := 'comprovante_' + IntToStr(AReceiptID) + '.jpg';
  API_URL := 'https://connecttask.com.br/lazarus/api/api/v1/admin/payments/' + IntToStr(AReceiptID) + '/image';
  
  HTTP := TFPHTTPClient.Create(nil);
  try
    try
      HTTP.AddHeader('Authorization', 'Bearer ' + FToken);
      HTTP.Get(API_URL, AStream);
      Result := (HTTP.ResponseStatusCode = 200);
    except
      on E: Exception do
        FLastError := E.Message;
    end;
  finally
    HTTP.Free;
  end;
end;

function TLicenseManager.GetPIXConfig: TPIXConfigInfo;
var
  RespJSON: string;
  JSONData: TJSONData;
  Obj: TJSONObject;
begin
  Result.ChavePIX     := '5511945457934';
  Result.TipoChave    := 'TELEFONE';
  Result.Titular      := 'Administrador Geral';
  Result.Banco        := 'C6 Bank';
  Result.ValorLicenca := 49.90;
  Result.Instrucoes   := 'Após efetuar o PIX, anexe o comprovante na tela de licença para liberação.';

  if APIRequest('/config/pix', 'GET', '', RespJSON) then
  begin
    try
      JSONData := GetJSON(RespJSON);
      try
        Obj := TJSONObject(JSONData);
        Result.ChavePIX     := Obj.Get('chave_pix', Result.ChavePIX);
        Result.TipoChave    := Obj.Get('tipo_chave', Result.TipoChave);
        Result.Titular      := Obj.Get('titular', Result.Titular);
        Result.Banco        := Obj.Get('banco', Result.Banco);
        Result.ValorLicenca := Obj.Get('valor_licenca', Result.ValorLicenca);
        Result.Instrucoes   := Obj.Get('instrucoes', Result.Instrucoes);
      finally
        JSONData.Free;
      end;
    except
    end;
  end;
end;

function TLicenseManager.SavePIXConfig(const AConfig: TPIXConfigInfo): Boolean;
var
  ReqJSON, RespJSON: string;
begin
  ReqJSON := '{"chave_pix":"' + AConfig.ChavePIX + '",' +
             '"tipo_chave":"' + AConfig.TipoChave + '",' +
             '"titular":"' + AConfig.Titular + '",' +
             '"banco":"' + AConfig.Banco + '",' +
             '"valor_licenca":' + FloatToStr(AConfig.ValorLicenca) + ',' +
             '"instrucoes":"' + AConfig.Instrucoes + '"}';
  Result := APIRequest('/admin/config/pix', 'POST', ReqJSON, RespJSON);
end;

end.
