# Walkthrough - Backup Externo e Perfil ZIP Portátil do Lazarus

Implementamos com sucesso a cópia adicional das configurações locais do usuário do Windows (`LOCALAPPDATA` e `APPDATA` do Lazarus) para uma pasta de backup externa (`C:\Users\<NomeUsuario>\LazarusBackup`), corrigimos a rotina de backup local que não copiava os arquivos no Addon da IDE e adicionamos a funcionalidade de **Exportação e Importação de Perfil (.zip único)**.

---

## Alterações Realizadas

### 1. Núcleo Portável (`uPortableCore.pas`)
- Implementado o método `BackupConfigsExternal` que cria uma pasta timestamped em `C:\Users\<NomeUsuario>\LazarusBackup\Backup_AAAAMMDD_HHMMSS\` e copia:
  1. A pasta de configuração portátil (`LazarusConfig`).
  2. A pasta do Lazarus em AppData Local (`%LOCALAPPDATA%\lazarus`).
  3. A pasta do Lazarus em AppData Roaming (`%APPDATA%\lazarus`).
- Implementado o método `ExportProfile` que compacta em um único arquivo `.zip` as pastas acima juntamente com um arquivo `profile_metadata.ini` contendo os caminhos originais para portabilização.
- Implementado o método `ImportProfile` que:
  1. Descompacta o arquivo `.zip` selecionado.
  2. Limpa e substitui a pasta `LazarusConfig` portátil ativa.
  3. Mescla as configurações importadas (tanto da pasta portável antiga quanto das pastas do perfil AppData original).
  4. Realiza uma busca e substituição inteligente nos arquivos de configuração importados (`.xml`, `.cfg`, `.ini`) para substituir os caminhos antigos da máquina original pelo caminho atual do Lazarus (pendrive ou nova pasta).
  5. Roda o patcher (`PatchAll`) para garantir que o Lazarus e o compilador FPC estejam apontando para os caminhos corretos.

### 2. Standalone Launcher UI (`frmMain.pas` / `frmMain.lfm`)
- Atualizado o evento do botão de backup (`btnBackupClick`) para rodar tanto o backup interno atual quanto o novo backup externo.
- Aumentada a altura do painel de Ações Rápidas (`pnlActions`) para comportar uma terceira linha de botões.
- Adicionados os botões **📦 Exportar Perfil (.zip)** e **📥 Importar Perfil (.zip)** com diálogos interativos de salvar/abrir arquivo.
- Ajustada a rotina de redimensionamento dinâmico (`FormResize`) para calcular e alinhar corretamente os novos botões na tela.

### 3. Addon da IDE (`frmPortablePanel.pas` / `uPortableIDEAddon.pas`)
- Adicionada a unit `FileUtil` aos usos de `frmPortablePanel.pas`.
- Corrigida a rotina local de backup no Addon (`btnBackupClick`), que antes apenas criava a pasta mas não copiava os arquivos (agora usa `CopyDirTree` para copiar a pasta `LazarusConfig`).
- Adicionado o backup externo também no botão do painel da IDE para garantir que a cópia para a pasta do usuário do Windows aconteça a partir de qualquer uma das ferramentas.
- Resolvido o erro de compilação da IDE ("Duplicate identifier") renomeando a variável global `frmPortablePanel` para `frmPortablePanelVar`, eliminando o conflito com o nome do arquivo unit.
- Corrigido o tipo da variável `PortableCmd` em `uPortableIDEAddon.pas` para `TIDEMenuCommand` e alterada a seção de menu alvo para `mnuTools` para compilar com sucesso.

---

## Verificação e Resultados

Executamos a compilação utilizando o compilador oficial do Lazarus (`lazbuild.exe`):
1. **LazarusPortable.lpi (Launcher)**: Compilação concluída com sucesso. O instalador foi gerado pelo Inno Setup em `Output\LazarusPortableSetup.exe`.
2. **LazPortableTools.lpk (Addon IDE)**: Compilação concluída com sucesso com zero erros.
