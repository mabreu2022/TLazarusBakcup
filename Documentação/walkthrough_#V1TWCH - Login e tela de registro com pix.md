# Walkthrough: Sistema de Autenticação, Trial de 10 Dias e Licenciamento PIX

Implementado com sucesso o sistema de **Autenticação de Usuários**, **Trial Gratuito de 10 Dias**, **Validação de Licenças Online** e **Envio de Comprovante de Pagamento PIX** integrado ao banco de dados Firebird em VPS Linux.

---

## 🛠️ Alterações Realizadas

### 1. Script DDL do Banco de Dados Firebird para VPS Linux
- **[schema_firebird_vps.sql](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/database/schema_firebird_vps.sql)**:
  - Tabela `USUARIOS`: cadastro com hash SHA-256 de senha e HWID único da máquina.
  - Tabela `LICENCAS`: controle de expiração, tipo de licença e status ativo.
  - Tabela `COMPROVANTES_PAGAMENTO`: armazenamento em campo BLOB de comprovantes anexados (PDF/JPG/PNG) para análise e liberação.

### 2. Módulo de Lógica de Licenciamento
- **[uLicenseManager.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/units/uLicenseManager.pas)**:
  - `GetHardwareID`: Gera identificador HWID único combinando serial do volume e nome do computador.
  - `CheckLocalTrial`: Controla os 10 dias de avaliação gratuita localmente e previne burlas.
  - `Authenticate`: Autentica o usuário e valida o status da licença na VPS Firebird.
  - `RegisterUser`: Cria a conta no banco remoto e inicializa os 10 dias de trial.
  - `SubmitPIXReceipt`: Grava o arquivo de comprovante diretamente na tabela `COMPROVANTES_PAGAMENTO`.

### 3. Formulários Visuais
- **[frmLogin.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmLogin.pas)** / **[frmLogin.lfm](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmLogin.lfm)**:
  - Tela de Login com opção de cadastro rápido de novos usuários ("✨ Ganhar 10 Dias Grátis").
  - Botão de atalho "⚙️ Configurar Servidor VPS" para definir o IP da sua VPS Linux.
  - Botão "⚡ Continuar sem Login (Usar Trial Local)".
- **[frmPayment.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmPayment.pas)** / **[frmPayment.lfm](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmPayment.lfm)**:
  - Tela exibida quando o Trial de 10 dias expira.
  - Exibe a **Chave PIX Copia e Cola** e botão para copiar com 1 clique.
  - Seletor de arquivo de comprovante com upload direto para a VPS.

### 4. Ponto de Entrada
- **[LazarusPortable.lpr](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/LazarusPortable.lpr)** / **[LazarusPortable.lpi](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/LazarusPortable.lpi)**:
  - Fluxo de inicialização integrado. O programa abre a tela principal `frmMain` somente se o Trial estiver ativo ou a Licença paga for confirmada.

---

## 🗄️ Como Criar o Banco de Dados na sua VPS Linux

1. Acesse sua VPS Linux via SSH:
   ```bash
   ssh root@seu_ip_vps
   ```
2. Instale o Firebird Server (caso ainda não esteja instalado):
   ```bash
   sudo apt update
   sudo apt install firebird3.0-server
   ```
3. Crie a pasta do banco e execute o script SQL:
   ```bash
   mkdir -p /var/lib/firebird/data
   isql-fb -user SYSDBA -password masterkey -create "/var/lib/firebird/data/lazarus_portable.fdb"
   ```
4. Cole o conteúdo de [schema_firebird_vps.sql](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/database/schema_firebird_vps.sql) dentro do console do `isql-fb` ou rode o comando:
   ```bash
   isql-fb -user SYSDBA -password masterkey -i /caminho/schema_firebird_vps.sql /var/lib/firebird/data/lazarus_portable.fdb
   ```
5. Libere a porta 3050 no firewall da VPS:
   ```bash
   sudo ufw allow 3050/tcp
   ```

---

## 🧪 Validação e Teste

1. Pressione **`Ctrl + F9`** no Lazarus para compilar a nova versão.
2. Ao abrir o aplicativo, a tela de Login será exibida indicando o status do Trial ("Modo de Testes Gratuito Ativo (10 dias restantes)").
3. Ao clicar em **"⚙️ Configurar Servidor VPS"**, insira o IP da sua VPS para testar a comunicação direta.
