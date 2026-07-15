{
  uLicenseManager.pas - Gerenciador de Autenticação, HWID, Trial e Licenciamento Firebird
}
unit uLicenseManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, IniFiles, Windows, sha1, db,
  sqldb, ibconnection, uConfigCrypt;

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

    function  GetHardwareID: string;
    function  HashPassword(const APassword: string): string;
    function  InitConnection: Boolean;
    procedure CloseConnection;
    procedure LoadConfigFromINI;

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

function TLicenseManager.InitConnection: Boolean;
begin
  Result := False;
  try
    LoadConfigFromINI;
    CloseConnection;

    // Para Firebird local com DLL específica: adiciona o caminho da fbclient.dll ao PATH do processo
    if (FClientLib <> '') and FileExists(FClientLib) then
    begin
      SetEnvironmentVariable('PATH',
        PChar(ExtractFileDir(FClientLib) + ';' + SysUtils.GetEnvironmentVariable('PATH')));
    end;

    // Se o HostName for fornecido (ex: localhost, 127.0.0.1, IP remoto), conecta via TCP/IP
    // Isso permite conexões concorrentes com o IBExpert e evita o erro "arquivo em uso por outro processo"
    if Trim(FHost) = '' then
      FHost := '127.0.0.1';
    if FPort <= 0 then
      FPort := 3050;

    FConnection.HostName := Trim(FHost);
    FConnection.DatabaseName := FDatabasePath;
    FConnection.UserName     := FDBUser;
    FConnection.Password     := FDBPassword;
    FConnection.CharSet      := ifthen(FCharset <> '', FCharset, 'UTF8');

    FConnection.Params.Clear;
    FConnection.Params.Values['user_name'] := FDBUser;
    FConnection.Params.Values['password']  := FDBPassword;
    FConnection.Params.Values['port']      := IntToStr(FPort);

    FConnection.Connected := True;
    FTransaction.StartTransaction;
    FLastError := '';
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

function TLicenseManager.TestConnection(out AErrorMsg: string): Boolean;
begin
  AErrorMsg := '';
  try
    CloseConnection;

    if (FClientLib <> '') and FileExists(FClientLib) then
    begin
      SetEnvironmentVariable('PATH',
        PChar(ExtractFileDir(FClientLib) + ';' + SysUtils.GetEnvironmentVariable('PATH')));
    end;

    FConnection.HostName := Trim(FHost);
    FConnection.DatabaseName := FDatabasePath;
    FConnection.UserName     := FDBUser;
    FConnection.Password     := FDBPassword;
    FConnection.CharSet      := ifthen(FCharset <> '', FCharset, 'UTF8');

    FConnection.Params.Clear;
    FConnection.Params.Values['user_name'] := FDBUser;
    FConnection.Params.Values['password']  := FDBPassword;
    if FConnection.HostName <> '' then
      FConnection.Params.Values['port']    := IntToStr(FPort);

    FConnection.Connected := True;
    FTransaction.StartTransaction;

    // Teste básico de acesso à tabela
    CloseConnection;
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      AErrorMsg := E.Message;
    end;
  end;
end;

procedure TLicenseManager.CloseConnection;
begin
  try
    if FTransaction.Active then
      FTransaction.Commit;
  except
  end;
  try
    if FConnection.Connected then
      FConnection.Connected := False;
  except
  end;
end;

function TLicenseManager.CheckLocalTrial: TLicenseInfo;
var
  IniFile: TIniFile;
  FirstRunStr: string;
  FirstRunDate: TDateTime;
  DaysPassed: Integer;
  TrialFile: string;
begin
  Result := Default(TLicenseInfo);
  Result.HWID := GetHardwareID;
  TrialFile := FConfigDir + 'license_info.dat';

  IniFile := TIniFile.Create(TrialFile);
  try
    FirstRunStr := IniFile.ReadString('License', 'FirstActivation', '');
    if FirstRunStr = '' then
    begin
      FirstRunDate := Now;
      IniFile.WriteString('License', 'FirstActivation', DateTimeToStr(FirstRunDate));
      IniFile.WriteString('License', 'HWID', Result.HWID);
    end
    else
      FirstRunDate := StrToDateTimeDef(FirstRunStr, Now);
  finally
    IniFile.Free;
  end;

  DaysPassed := Trunc(Now - FirstRunDate);
  Result.ExpirationDate := FirstRunDate + 10;
  Result.DaysRemaining  := 10 - DaysPassed;

  if Result.DaysRemaining < 0 then
    Result.DaysRemaining := 0;

  if DaysPassed < 10 then
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
  Query: TSQLQuery;
  PassHash: string;
  LicExpDate: TDateTime;
  LicStatus: SmallInt;
begin
  Result := False;
  AInfo := CheckLocalTrial;
  AInfo.UserEmail := Trim(AEmail);
  AInfo.IsAdmin   := SameText(Trim(AEmail), SUPER_ADMIN_EMAIL);

  FUserEmail := Trim(AEmail);
  if AInfo.IsAdmin then
    FIsAdmin := True;

  if not InitConnection then
  begin
    AInfo.Status := lsNotAuthenticated;
    if FLastError <> '' then
      AInfo.Message := 'Falha ao conectar com banco de dados: ' + FLastError
    else
      AInfo.Message := 'Servidor de licenças indisponível offline.';
    FLastLicense  := AInfo;
    Exit(False);
  end;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    PassHash := HashPassword(APassword);
    Query.SQL.Text := 'SELECT ID, NOME, STATUS FROM USUARIOS WHERE LOWER(EMAIL) = LOWER(:EMAIL) AND SENHA_HASH = :HASH';
    Query.ParamByName('EMAIL').AsString := Trim(AEmail);
    Query.ParamByName('HASH').AsString  := PassHash;
    Query.Open;

    if Query.IsEmpty then
    begin
      AInfo.Status  := lsNotAuthenticated;
      AInfo.Message := 'E-mail ou senha incorretos.';
      FLastLicense  := AInfo;
      Exit(False);
    end;

    AInfo.UserID   := Query.FieldByName('ID').AsInteger;
    AInfo.UserName := Query.FieldByName('NOME').AsString;
    Query.Close;

    // Regra de Administrador: E-mail Super Admin OU coluna IS_ADMIN = 1 no banco
    AInfo.IsAdmin := SameText(Trim(AEmail), SUPER_ADMIN_EMAIL);
    try
      Query.SQL.Text := 'SELECT IS_ADMIN FROM USUARIOS WHERE ID = :ID';
      Query.ParamByName('ID').AsInteger := AInfo.UserID;
      Query.Open;
      if not Query.IsEmpty and (Query.Fields[0].AsInteger = 1) then
        AInfo.IsAdmin := True;
      Query.Close;
    except
      // Se a coluna IS_ADMIN ainda não existir no banco do usuário, ignora o erro
    end;

    // Administrador possui licença vitalícia incondicional
    if AInfo.IsAdmin then
    begin
      AInfo.Status := lsLicensed;
      AInfo.DaysRemaining := 99999;
      AInfo.ExpirationDate := EncodeDate(2099, 12, 31);
      AInfo.Message := 'Acesso Administrador Geral (Licença Vitalícia Ativa)';
      Result := True;
      Exit;
    end;

    // Atualiza HWID do usuário se vazio
    Query.SQL.Text := 'UPDATE USUARIOS SET HWID = :HWID WHERE ID = :ID AND (HWID IS NULL OR HWID = '''')';
    Query.ParamByName('HWID').AsString := AInfo.HWID;
    Query.ParamByName('ID').AsInteger  := AInfo.UserID;
    Query.ExecSQL;

    // Busca a licença mais recente
    Query.SQL.Text := 'SELECT FIRST 1 DATA_EXPIRACAO, STATUS_ATIVO FROM LICENCAS ' +
                      'WHERE USUARIO_ID = :UID ORDER BY ID DESC';
    Query.ParamByName('UID').AsInteger := AInfo.UserID;
    Query.Open;

    if not Query.IsEmpty then
    begin
      LicExpDate := Query.FieldByName('DATA_EXPIRACAO').AsDateTime;
      LicStatus  := Query.FieldByName('STATUS_ATIVO').AsInteger;
      AInfo.ExpirationDate := LicExpDate;

      if (LicStatus = 1) and (LicExpDate >= Now) then
      begin
        AInfo.Status := lsLicensed;
        AInfo.DaysRemaining := Trunc(LicExpDate - Now);
        AInfo.Message := Format('Licença Ativa até %s (%d dias restantes)',
          [FormatDateTime('dd/mm/yyyy', LicExpDate), AInfo.DaysRemaining]);
        Result := True;
        Exit;
      end;
    end;

    // Verifica se há comprovante pendente de análise
    Query.Close;
    Query.SQL.Text := 'SELECT FIRST 1 STATUS_ANALISE FROM COMPROVANTES_PAGAMENTO ' +
                      'WHERE USUARIO_ID = :UID AND STATUS_ANALISE = ''AGUARDANDO_APROVACAO'' ORDER BY ID DESC';
    Query.ParamByName('UID').AsInteger := AInfo.UserID;
    Query.Open;

    if not Query.IsEmpty then
    begin
      AInfo.Status := lsPendingApproval;
      AInfo.Message := 'Seu comprovante PIX foi enviado e está em análise. Acesso será liberado em breve.';
      Exit(False);
    end;

    // Fallback para trial local se dentro do prazo de 10 dias
    if AInfo.DaysRemaining > 0 then
    begin
      AInfo.Status := lsTrialActive;
      Result := True;
    end
    else
    begin
      AInfo.Status := lsTrialExpired;
      AInfo.Message := 'Sua licença expirou. Faça o pagamento do PIX para reativar o acesso.';
      Result := False;
    end;
  finally
    Query.Free;
    CloseConnection;
    if Result then
    begin
      FIsAdmin   := AInfo.IsAdmin;
      FUserEmail := AInfo.UserEmail;
    end;
    FLastLicense := AInfo;
  end;
end;

function TLicenseManager.RegisterUser(const AName, AEmail, APassword: string; out AInfo: TLicenseInfo; out AErrorMsg: string): Boolean;
var
  Query: TSQLQuery;
  UID, IsAdminVal: Integer;
begin
  Result := False;
  AErrorMsg := '';
  AInfo := CheckLocalTrial;

  if not InitConnection then
  begin
    AErrorMsg := 'Não foi possível conectar ao servidor de registro na VPS.';
    Exit;
  end;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    // Verifica se e-mail já existe
    Query.SQL.Text := 'SELECT ID FROM USUARIOS WHERE EMAIL = :EMAIL';
    Query.ParamByName('EMAIL').AsString := Trim(AEmail);
    Query.Open;

    if not Query.IsEmpty then
    begin
      AErrorMsg := 'Este e-mail já está cadastrado no sistema.';
      Exit;
    end;
    Query.Close;

    // Insere novo usuário com IS_ADMIN = 0 (ou 1 se for o e-mail super admin)
    if SameText(AEmail, SUPER_ADMIN_EMAIL) then
      IsAdminVal := 1
    else
      IsAdminVal := 0;

    try
      Query.SQL.Text := 'INSERT INTO USUARIOS (NOME, EMAIL, SENHA_HASH, HWID, IS_ADMIN) ' +
                        'VALUES (:NOME, :EMAIL, :HASH, :HWID, :IS_ADMIN) RETURNING ID';
      Query.ParamByName('NOME').AsString     := Trim(AName);
      Query.ParamByName('EMAIL').AsString    := Trim(AEmail);
      Query.ParamByName('HASH').AsString     := HashPassword(APassword);
      Query.ParamByName('HWID').AsString     := AInfo.HWID;
      Query.ParamByName('IS_ADMIN').AsInteger := IsAdminVal;
      Query.Open;
    except
      // Se a coluna IS_ADMIN ainda não existir no banco legado
      Query.SQL.Text := 'INSERT INTO USUARIOS (NOME, EMAIL, SENHA_HASH, HWID) ' +
                        'VALUES (:NOME, :EMAIL, :HASH, :HWID) RETURNING ID';
      Query.ParamByName('NOME').AsString  := Trim(AName);
      Query.ParamByName('EMAIL').AsString := Trim(AEmail);
      Query.ParamByName('HASH').AsString  := HashPassword(APassword);
      Query.ParamByName('HWID').AsString  := AInfo.HWID;
      Query.Open;
    end;

    UID := Query.FieldByName('ID').AsInteger;
    Query.Close;

    // Insere Licença de Trial de 10 Dias no banco remoto
    Query.SQL.Text := 'INSERT INTO LICENCAS (USUARIO_ID, TIPO_LICENCA, DATA_INICIO, DATA_EXPIRACAO, STATUS_ATIVO) ' +
                      'VALUES (:UID, ''TRIAL_10_DIAS'', CURRENT_TIMESTAMP, DATEADD(10 DAY TO CURRENT_TIMESTAMP), 1)';
    Query.ParamByName('UID').AsInteger := UID;
    Query.ExecSQL;

    FTransaction.Commit;

    AInfo.UserID   := UID;
    AInfo.UserName := Trim(AName);
    AInfo.UserEmail:= Trim(AEmail);
    AInfo.IsAdmin  := (IsAdminVal = 1) or SameText(Trim(AEmail), SUPER_ADMIN_EMAIL);
    AInfo.Status   := lsTrialActive;
    AInfo.DaysRemaining := 10;
    AInfo.Message := 'Cadastro realizado com sucesso! Seu trial de 10 dias foi ativado.';

    FIsAdmin   := AInfo.IsAdmin;
    FUserEmail := AInfo.UserEmail;
    FLastLicense := AInfo;

    Result := True;
  except
    on E: Exception do
    begin
      AErrorMsg := 'Erro ao cadastrar usuário: ' + E.Message;
      FTransaction.Rollback;
    end;
  end;
  Query.Free;
  CloseConnection;
end;

function TLicenseManager.SubmitPIXReceipt(AUserID: Integer; const AFilePath, AChavePIX, AObs: string; out AErrorMsg: string): Boolean;
var
  Query: TSQLQuery;
  FileStream: TFileStream;
  RealUserID: Integer;
begin
  Result := False;
  AErrorMsg := '';
  RealUserID := AUserID;

  if not FileExists(AFilePath) then
  begin
    AErrorMsg := 'Arquivo de comprovante não encontrado: ' + AFilePath;
    Exit;
  end;

  if not InitConnection then
  begin
    AErrorMsg := 'Falha ao conectar ao banco de dados: ' + FLastError;
    Exit;
  end;

  // Busca automática do ID pelo e-mail se AUserID vier zerado
  if RealUserID = 0 then
  begin
    Query := TSQLQuery.Create(nil);
    try
      Query.DataBase := FConnection;
      Query.Transaction := FTransaction;
      Query.SQL.Text := 'SELECT ID FROM USUARIOS WHERE LOWER(EMAIL) = LOWER(:EMAIL)';
      if Trim(FUserEmail) <> '' then
        Query.ParamByName('EMAIL').AsString := Trim(FUserEmail)
      else
        Query.ParamByName('EMAIL').AsString := Trim(FLastLicense.UserEmail);
      Query.Open;
      if not Query.IsEmpty then
        RealUserID := Query.FieldByName('ID').AsInteger;
    finally
      Query.Free;
    end;
  end;

  if RealUserID = 0 then
  begin
    AErrorMsg := 'Usuário não localizado no banco de dados. Efetue login novamente.';
    Exit;
  end;

  Query := TSQLQuery.Create(nil);
  FileStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyNone);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text := 'INSERT INTO COMPROVANTES_PAGAMENTO ' +
                      '(USUARIO_ID, CHAVE_PIX_USADA, COMPROVANTE_BLOB, NOME_ARQUIVO, STATUS_ANALISE, OBSERVACAO) ' +
                      'VALUES (:UID, :CHAVE, :BLOB, :NOME, ''AGUARDANDO_APROVACAO'', :OBS)';
    Query.ParamByName('UID').AsInteger  := RealUserID;
    Query.ParamByName('CHAVE').AsString := Copy(AChavePIX, 1, 95);
    Query.ParamByName('NOME').AsString  := ExtractFileName(AFilePath);
    Query.ParamByName('OBS').AsString   := AObs;
    Query.ParamByName('BLOB').LoadFromStream(FileStream, ftBlob);
    Query.ExecSQL;

    FTransaction.Commit;
    Result := True;
  except
    on E: Exception do
    begin
      AErrorMsg := 'Erro ao enviar comprovante: ' + E.Message;
      FTransaction.Rollback;
    end;
  end;
  FileStream.Free;
  Query.Free;
  CloseConnection;
end;

function TLicenseManager.GetUserReceipts(AUserID: Integer; AAllUsers: Boolean): TPaymentReceiptArray;
var
  Query: TSQLQuery;
  Count: Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  if not InitConnection then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    if AAllUsers then
    begin
      Query.SQL.Text := 'SELECT C.ID, C.USUARIO_ID, U.NOME, U.EMAIL, C.DATA_ENVIO, ' +
                        'C.CHAVE_PIX_USADA, C.VALOR_PAGO, C.NOME_ARQUIVO, C.STATUS_ANALISE, C.OBSERVACAO ' +
                        'FROM COMPROVANTES_PAGAMENTO C ' +
                        'LEFT JOIN USUARIOS U ON U.ID = C.USUARIO_ID ' +
                        'ORDER BY C.ID DESC';
    end
    else
    begin
      Query.SQL.Text := 'SELECT C.ID, C.USUARIO_ID, U.NOME, U.EMAIL, C.DATA_ENVIO, ' +
                        'C.CHAVE_PIX_USADA, C.VALOR_PAGO, C.NOME_ARQUIVO, C.STATUS_ANALISE, C.OBSERVACAO ' +
                        'FROM COMPROVANTES_PAGAMENTO C ' +
                        'LEFT JOIN USUARIOS U ON U.ID = C.USUARIO_ID ' +
                        'WHERE C.USUARIO_ID = :UID ORDER BY C.ID DESC';
      Query.ParamByName('UID').AsInteger := AUserID;
    end;

    Query.Open;
    Count := 0;
    while not Query.Eof do
    begin
      SetLength(Result, Count + 1);
      Result[Count].ID            := Query.FieldByName('ID').AsInteger;
      Result[Count].UserID        := Query.FieldByName('USUARIO_ID').AsInteger;
      Result[Count].UserName      := Query.FieldByName('NOME').AsString;
      Result[Count].UserEmail     := Query.FieldByName('EMAIL').AsString;
      Result[Count].DataEnvio     := Query.FieldByName('DATA_ENVIO').AsDateTime;
      Result[Count].ChavePIX      := Query.FieldByName('CHAVE_PIX_USADA').AsString;
      Result[Count].ValorPago     := Query.FieldByName('VALOR_PAGO').AsFloat;
      Result[Count].NomeArquivo   := Query.FieldByName('NOME_ARQUIVO').AsString;
      Result[Count].StatusAnalise := Query.FieldByName('STATUS_ANALISE').AsString;
      Result[Count].Observacao    := Query.FieldByName('OBSERVACAO').AsString;
      Inc(Count);
      Query.Next;
    end;
  finally
    Query.Free;
    CloseConnection;
  end;
end;

function TLicenseManager.ApproveReceipt(AReceiptID, AUserID: Integer; ADaysToAdd: Integer; const AObs: string): Boolean;
var
  Query: TSQLQuery;
  TargetUserID: Integer;
  CurrentExp, ExpDate: TDateTime;
begin
  Result := False;
  if not InitConnection then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    // 1. Busca o USUARIO_ID real do dono do comprovante
    Query.SQL.Text := 'SELECT USUARIO_ID FROM COMPROVANTES_PAGAMENTO WHERE ID = :ID';
    Query.ParamByName('ID').AsInteger := AReceiptID;
    Query.Open;

    if Query.IsEmpty then Exit;
    TargetUserID := Query.FieldByName('USUARIO_ID').AsInteger;
    Query.Close;

    // 2. Marca o comprovante como APROVADO
    Query.SQL.Text := 'UPDATE COMPROVANTES_PAGAMENTO SET STATUS_ANALISE = ''APROVADO'', OBSERVACAO = :OBS WHERE ID = :ID';
    Query.ParamByName('OBS').AsString := AObs;
    Query.ParamByName('ID').AsInteger := AReceiptID;
    Query.ExecSQL;

    // 3. Busca a expiração atual do usuário (acumula dias se licença estiver ativa)
    Query.SQL.Text := 'SELECT FIRST 1 DATA_EXPIRACAO FROM LICENCAS WHERE USUARIO_ID = :UID AND STATUS_ATIVO = 1 ORDER BY DATA_EXPIRACAO DESC';
    Query.ParamByName('UID').AsInteger := TargetUserID;
    Query.Open;

    CurrentExp := Now;
    if not Query.IsEmpty and (Query.FieldByName('DATA_EXPIRACAO').AsDateTime > Now) then
      CurrentExp := Query.FieldByName('DATA_EXPIRACAO').AsDateTime;
    Query.Close;

    ExpDate := CurrentExp + ADaysToAdd;

    // 4. Insere a nova licença para o usuário correto
    Query.SQL.Text := 'INSERT INTO LICENCAS (USUARIO_ID, TIPO_LICENCA, DATA_INICIO, DATA_EXPIRACAO, STATUS_ATIVO) ' +
                      'VALUES (:UID, ''MENSAL'', CURRENT_TIMESTAMP, :EXP, 1)';
    Query.ParamByName('UID').AsInteger := TargetUserID;
    Query.ParamByName('EXP').AsDateTime := ExpDate;
    Query.ExecSQL;

    FTransaction.Commit;
    Result := True;
  except
    on E: Exception do
      FTransaction.Rollback;
  end;
  Query.Free;
  CloseConnection;
end;

function TLicenseManager.RejectReceipt(AReceiptID: Integer; const AObs: string): Boolean;
var
  Query: TSQLQuery;
begin
  Result := False;
  if not InitConnection then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text := 'UPDATE COMPROVANTES_PAGAMENTO SET STATUS_ANALISE = ''REJEITADO'', OBSERVACAO = :OBS WHERE ID = :ID';
    Query.ParamByName('OBS').AsString := AObs;
    Query.ParamByName('ID').AsInteger := AReceiptID;
    Query.ExecSQL;

    FTransaction.Commit;
    Result := True;
  except
    on E: Exception do
      FTransaction.Rollback;
  end;
  Query.Free;
  CloseConnection;
end;

function TLicenseManager.GetReceiptBLOB(AReceiptID: Integer; out AFileName: string; AStream: TStream): Boolean;
var
  Query: TSQLQuery;
begin
  Result := False;
  AFileName := '';
  if not InitConnection then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;
    Query.SQL.Text := 'SELECT NOME_ARQUIVO, COMPROVANTE_BLOB FROM COMPROVANTES_PAGAMENTO WHERE ID = :ID';
    Query.ParamByName('ID').AsInteger := AReceiptID;
    Query.Open;

    if not Query.IsEmpty then
    begin
      AFileName := Query.FieldByName('NOME_ARQUIVO').AsString;
      TBlobField(Query.FieldByName('COMPROVANTE_BLOB')).SaveToStream(AStream);
      Result := True;
    end;
  finally
    Query.Free;
    CloseConnection;
  end;
end;

function TLicenseManager.GetPIXConfig: TPIXConfigInfo;
var
  Query: TSQLQuery;
begin
  Result.ChavePIX     := '5511945457934';
  Result.TipoChave    := 'TELEFONE';
  Result.Titular      := 'Administrador Geral';
  Result.Banco        := 'C6 Bank';
  Result.ValorLicenca := 49.90;
  Result.Instrucoes   := 'Após efetuar o PIX, anexe o comprovante na tela de licença para liberação.';

  if not InitConnection then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;
    Query.SQL.Text := 'SELECT CHAVE_PIX, TIPO_CHAVE, TITULAR, BANCO, VALOR_LICENCA, INSTRUCOES ' +
                      'FROM CONFIG_PIX WHERE ID = 1';
    Query.Open;
    if not Query.Eof then
    begin
      Result.ChavePIX     := Query.FieldByName('CHAVE_PIX').AsString;
      Result.TipoChave    := Query.FieldByName('TIPO_CHAVE').AsString;
      Result.Titular      := Query.FieldByName('TITULAR').AsString;
      Result.Banco        := Query.FieldByName('BANCO').AsString;
      Result.ValorLicenca := Query.FieldByName('VALOR_LICENCA').AsFloat;
      Result.Instrucoes   := Query.FieldByName('INSTRUCOES').AsString;
    end;
  finally
    Query.Free;
    CloseConnection;
  end;
end;

function TLicenseManager.SavePIXConfig(const AConfig: TPIXConfigInfo): Boolean;
var
  Query: TSQLQuery;
begin
  Result := False;
  if not InitConnection then Exit;

  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.Transaction := FTransaction;

    Query.SQL.Text := 'UPDATE OR INSERT INTO CONFIG_PIX ' +
                      '(ID, CHAVE_PIX, TIPO_CHAVE, TITULAR, BANCO, VALOR_LICENCA, INSTRUCOES, ULTIMA_ATUALIZACAO) ' +
                      'VALUES (1, :CHAVE, :TIPO, :TITULAR, :BANCO, :VALOR, :INST, CURRENT_TIMESTAMP) ' +
                      'MATCHING (ID)';
    Query.ParamByName('CHAVE').AsString   := AConfig.ChavePIX;
    Query.ParamByName('TIPO').AsString    := AConfig.TipoChave;
    Query.ParamByName('TITULAR').AsString := AConfig.Titular;
    Query.ParamByName('BANCO').AsString   := AConfig.Banco;
    Query.ParamByName('VALOR').AsFloat    := AConfig.ValorLicenca;
    Query.ParamByName('INST').AsString    := AConfig.Instrucoes;
    Query.ExecSQL;

    FTransaction.Commit;
    Result := True;
  except
    on E: Exception do
      FTransaction.Rollback;
  end;
  Query.Free;
  CloseConnection;
end;

end.
