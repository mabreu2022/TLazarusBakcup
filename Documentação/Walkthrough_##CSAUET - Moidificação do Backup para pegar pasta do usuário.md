# Walkthrough - Backup Externo, Perfil ZIP Portátil e Restauração Seletiva do Lazarus

Implementamos com sucesso a cópia completa das configurações locais do usuário do Windows (`LOCALAPPDATA` e `APPDATA` do Lazarus), a inclusão da pasta inteira de instalação do Lazarus (`C:\Lazarus`) nos backups e ZIPs, a correção de dupla criptografia do banco de dados e a nova **Interface de Escolha e Restauração de Backups**.

---

## Alterações Realizadas

### 1. Núcleo Portável (`uPortableCore.pas`)
- **Pasta Completa do Lazarus**: 
  - Atualizada a rotina `BackupConfigsExternal` para copiar a pasta inteira do Lazarus (`FPortableDir`, ex: `C:\Lazarus`) para o diretório de backup externo (`LazarusBackup\Backup_<TimeStamp>\Lazarus\`).
  - Atualizada a função `ExportProfile` para compactar recursivamente a pasta do Lazarus inteira para dentro do ZIP na raiz `/Lazarus`.
  - Adicionados filtros na recursão do ZIP (`AddFolderToZip`) para excluir as pastas de backup locais, temporárias e o próprio arquivo ZIP gerado, evitando redundância e loops de escrita.
- **Restauração Seletiva e Patches**:
  - Implementada a função `RestoreBackupFromPath(const ABkpPath: string; AIsExternal: Boolean): Boolean`.
  - Se for um backup local (apenas configurações), limpa e restaura os arquivos XML na pasta portátil ativa.
  - Se for um backup externo, restaura a configuração portátil, os diretórios de AppData local e roaming, e substitui a pasta inteira de instalação `C:\Lazarus` pelos arquivos guardados.
  - Roda a rotina de patches dinâmicos (`PatchAll`) após qualquer restauração para garantir que todos os caminhos do Lazarus e FPC apontem para a unidade/unidade atual (ex: pendrive ou nova pasta de máquina).

### 2. Standalone Launcher UI (`frmMain.pas` / `frmRestoreSelect.pas` / `frmRestoreSelect.lfm`)
- **Tela de Escolha de Backups**:
  - Criada a nova tela `frmRestoreSelect` que varre a pasta local (`LazarusPortable\Backup\`) e a pasta externa (`C:\Users\<Usuario>\LazarusBackup\`) e as lista em um visual unificado.
  - Cada item exibe se é `[Local]` ou `[Externo]` e o timestamp.
  - O botão de restauração do dashboard (`btnRestoreClick`) agora abre essa janela modal para que o usuário escolha o ponto de restauração desejado antes de aplicar a ação.

### 3. Addon da IDE (`frmPortablePanel.pas`)
- Atualizada a rotina de backup externo no Addon da IDE para também copiar a pasta de instalação completa do Lazarus (`FPortableDir`) para a pasta de backup do usuário, garantindo paridade de comportamento com o launcher independente.

### 4. Correção de Conexão com o Banco de Dados (`vps_config.ini`)
- Identificada a causa da mensagem de erro de login: a rotina de migração encontrou parâmetros em formato hexadecimal de criptografia prévia sem o prefixo `ENC:`, interpretando-os como texto puro e aplicando uma segunda camada de criptografia sobre eles (dupla criptografia).
- Corrigidas todas as chaves do arquivo [vps_config.ini](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/LazarusConfig/vps_config.ini) para utilizarem criptografia de camada única válida, restabelecendo a conexão com o host do banco de dados remoto (`45.225.129.86:3050`) e aceitando a senha do usuário com sucesso.

---

## Verificação e Resultados

Executamos a compilação utilizando o compilador oficial do Lazarus (`lazbuild.exe`):
1. **LazarusPortable.lpi (Launcher)**: Compilado com sucesso. O instalador final `LazarusPortableSetup.exe` foi gerado perfeitamente pelo compilador Inno Setup em `Output\LazarusPortableSetup.exe`.
2. **LazPortableTools.lpk (Addon IDE)**: Compilado com sucesso com zero erros.
3. **Conexão de Banco**: Teste de conexão local via driver Firebird completado com **sucesso** apontando para as novas credenciais.
