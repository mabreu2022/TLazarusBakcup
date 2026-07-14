# Plano de Implementação: Autenticação, Trial de 10 Dias e Sistema de Licenciamento com PIX

Criar um sistema completo de autenticação e licenciamento para o **Lazarus Portable Manager**, incluindo tela de login, cálculo de trial gratuito de 10 dias, validação de licenças ativas via banco de dados Firebird remoto na VPS Linux, bloqueio automático após expiração, tela de pagamento com chave PIX, envio de comprovante de pagamento e o script DDL SQL completo para a VPS Linux.

---

## User Review Required

> [!IMPORTANT]
> **Conexão com Banco de Dados Firebird na VPS Linux**:
> O sistema utilizará os componentes nativos do FPC (`IBConnection` + `TSQLTransaction` + `TSQLQuery`) para conexão direta via porta TCP/IP (porta padrão `3050`) da VPS Linux.
> É necessário garantir que a porta `3050` esteja liberada no Firewall (UFW/iptables) da sua VPS Linux.

> [!NOTE]
> **Armazenamento Seguro de Senhas e HWID**:
> O HWID (Identificador Único do Computador) é gerado combinando o número de série do volume do disco rígido e o nome da máquina, garantindo que o trial de 10 dias não seja burlado por simples reinstalação.
> As senhas dos usuários no banco de dados serão armazenadas utilizando Hash SHA-256.

---

## Proposed Changes

### Componente de Banco de Dados e Script DDL

#### [NEW] [schema_firebird_vps.sql](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/database/schema_firebird_vps.sql)
Script SQL completo para criação do banco de dados na VPS Linux contendo:
- Tabela `USUARIOS`: Cadastro de usuários, hash de senha, HWID e data do trial.
- Tabela `LICENCAS`: Cadastro de licenças ativas, data de início, data de expiração e status.
- Tabela `COMPROVANTES_PAGAMENTO`: Armazenamento de comprovantes PIX (BLOB) enviados pelos clientes, status da análise e histórico.

---

### Unidades de Lógica de Negócio e Licenciamento

#### [NEW] [uLicenseManager.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/units/uLicenseManager.pas)
Unidade responsável por:
- Gerar o **HWID único** do computador do usuário.
- Conectar ao banco Firebird online na VPS Linux via `IBConnection`.
- Verificar status do Trial de 10 Dias (gravação da primeira execução e expiração).
- Validar se o usuário autenticado possui uma licença ativa válida na tabela `LICENCAS`.
- Enviar comprovante PIX (upload de arquivo PDF/JPG para campo BLOB no Firebird).

---

### Formulários da Interface Visual (GUI)

#### [NEW] [frmLogin.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmLogin.pas)
#### [NEW] [frmLogin.lfm](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmLogin.lfm)
Formulário moderno de Login e Cadastro contendo:
- Campos: Email e Senha.
- Botão "Entrar" (Valida login na VPS e verifica a licença).
- Botão "Criar Nova Conta" (Inicia o período de trial de 10 dias para novos usuários).
- Indicador visual dos dias restantes de teste ("Você possui X dias de teste restantes").

#### [NEW] [frmPayment.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmPayment.pas)
#### [NEW] [frmPayment.lfm](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmPayment.lfm)
Formulário exibido quando o Trial expira ou a licença está inativa:
- Bloqueia o acesso ao Dashboard do programa.
- Exibe instrução de pagamento PIX e a **Chave PIX Copia e Cola**.
- Campo para anexo do arquivo de comprovante de pagamento (PDF, PNG ou JPG).
- Botão "Enviar Comprovante" que grava o arquivo diretamente no banco Firebird da VPS Linux com status `AGUARDANDO_APROVACAO`.

---

### Ponto de Entrada da Aplicação

#### [MODIFY] [LazarusPortable.lpr](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/LazarusPortable.lpr)
- Atualizar o `lpr` para instanciar a verificação de Login/Licença antes de abrir o `frmMain`.
- Se o usuário não estiver logado ou se o Trial de 10 dias tiver expirado sem pagamento aprovado, redirecionar para a tela de Pagamento/Registro.

---

## Verification Plan

### Automated Verification
- Compilar o projeto `LazarusPortable.lpi` via lazbuild para garantir ausência de erros de sintaxe.
- Testar a conexão do driver Firebird (`IBConnection`) com o banco de dados.

### Manual Verification
1. **Teste de Primeiro Acesso (Trial)**: Executar o aplicativo pela primeira vez e confirmar o início da contagem regressiva de 10 dias.
2. **Teste de Login e Validação de Licença**: Fazer login com um usuário cadastrado e validar retorno de licença ativa/inativa.
3. **Teste de Expiração & Envio de Comprovante PIX**: Simular expiração do trial, validar bloqueio da tela principal, selecionar um arquivo de comprovante e testar a gravação no banco Firebird da VPS.
