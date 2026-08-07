# Plano: Implementar Backup Externo e Exportação/Importação de Perfil de Usuário do Lazarus

Este plano descreve a implementação de um backup externo das configurações do usuário do Lazarus, corrigindo as falhas do backup do painel da IDE e adicionando o recurso de **Exportação e Importação de Perfil** em um arquivo `.zip` único para facilitar a transferência e o uso portátil (ex: em um pendrive).

---

## Como funciona a portabilidade no Pendrive?

Para rodar o Lazarus com todos os componentes instalados a partir de um pendrive:
1. **Isolamento de Configuração**: O Lazarus normalmente salva configurações e pacotes instalados no computador local (`%APPDATA%\lazarus` ou `%LOCALAPPDATA%\lazarus`). Para rodar portátil, o launcher (`LazarusPortable.exe`) inicia o Lazarus com o parâmetro `--primary-config-path=LazarusConfig`. Isso força o Lazarus a salvar tudo na pasta `LazarusConfig` do pendrive.
2. **Ajuste Dinâmico de Caminhos (Patches)**: Quando você muda o pendrive de computador, a letra da unidade (ex: de `D:` para `E:`) ou o caminho da pasta muda. Se os caminhos nos arquivos de configuração do Lazarus (`environmentoptions.xml`, `packagefiles.xml`) continuarem apontando para a unidade antiga, o Lazarus falhará. O launcher resolve isso corrigindo dinamicamente todos os caminhos nos arquivos de configuração para a pasta atual antes de abrir o Lazarus.
3. **Importância do Perfil ZIP**: Se você já tem componentes instalados localmente no seu computador principal, a nova função de **Exportar Perfil (.zip)** reunirá todas as pastas de configuração local (`AppData\Local\lazarus` e `AppData\Roaming\lazarus`) e a pasta portátil em um arquivo `.zip`. Ao levar esse `.zip` e o Lazarus para o pendrive, basta usar a função **Importar Perfil** no pendrive. O launcher extrairá os arquivos e corrigirá todos os caminhos automaticamente para a unidade do pendrive, deixando todos os componentes prontos para uso.

---

## Revisão do Usuário Necessária

> [!IMPORTANT]
> - Os backups externos e perfis exportados serão salvos em: `C:\Users\<NomeUsuario>\LazarusBackup\`.
> - Usaremos a unit padrão `zipper` do Free Pascal para a compactação e descompactação, garantindo compatibilidade sem dependências externas de DLLs.

---

## Alterações Propostas

### 1. Núcleo Portável (`LazarusPortable` - Standalone Launcher)

#### [MODIFY] [uPortableCore.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/units/uPortableCore.pas)
- Adicionar `zipper` à cláusula `uses`.
- Implementar o método `TPortableConfig.BackupConfigsExternal(out AExternalBkpPath: string): Boolean`:
  1. Cria uma pasta externa timestamped em `C:\Users\<NomeUsuario>\LazarusBackup\Backup_AAAAMMDD_HHMMSS\`.
  2. Copia a pasta `LazarusConfig` do launcher e as pastas de configuração locais do Windows (`AppData\Local\lazarus` e `AppData\Roaming\lazarus`).
- Implementar o método `TPortableConfig.ExportProfile(const ADestZipFile: string): Boolean`:
  1. Cria um arquivo `.zip` contendo toda a pasta portátil `LazarusConfig` e as configurações locais do Windows (LOCALAPPDATA/APPDATA).
- Implementar o método `TPortableConfig.ImportProfile(const ASourceZipFile: string): Boolean`:
  1. Limpa a pasta `LazarusConfig` portátil atual.
  2. Descompacta o arquivo `.zip` selecionado para dentro de `LazarusConfig`.
  3. Aciona o patch automático (`PatchAll`) para atualizar os caminhos físicos de todos os arquivos importados para o local atual do executável (ideal para pendrives).

#### [MODIFY] [frmMain.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/forms/frmMain.pas)
- Atualizar `btnBackupClick` para rodar o backup local existente e, em seguida, o novo backup externo.
- Adicionar dois novos botões na interface do dashboard:
  - **📦 Exportar Perfil (.zip)**: Abre um `TSaveDialog` sugerindo um arquivo ZIP e executa `ExportProfile`.
  - **📥 Importar Perfil (.zip)**: Abre um `TOpenDialog` para o usuário selecionar um ZIP e executa `ImportProfile`.
- Exibir mensagens detalhadas de sucesso e erros no log e caixas de diálogo.

---

### 2. Pacote da IDE (`LazPortableTools`)

#### [MODIFY] [frmPortablePanel.pas](file:///c:/Fontes/Componentes/TLazarusBakcup/LazPortableTools/frmPortablePanel.pas)
- Adicionar `FileUtil` e `zipper` na cláusula `uses`.
- Corrigir a rotina `btnBackupClick` para que ela realmente copie a pasta `LazarusConfig` para o diretório de backup local (atualmente ela apenas criava o diretório vazio).
- Adicionar no mesmo botão, ou em botões adicionais no painel do Addon, a execução do backup externo para garantir que ambos os lados (aplicativo principal e addon da IDE) realizem a cópia completa e externa de segurança.

---

## Plano de Verificação

### Verificação Manual
1. **Verificação de Backup**:
   - Abrir o launcher, clicar em **💾 Criar Backup**.
   - Validar que o backup interno foi criado e que a pasta externa `C:\Users\<NomeUsuario>\LazarusBackup\` contém os arquivos copiados.
2. **Verificação de Exportação**:
   - No launcher, clicar em **Exportar Perfil**. Escolher o local e gerar o arquivo `.zip`.
   - Abrir o ZIP e verificar se ele contém as estruturas do LazarusConfig e AppData.
3. **Verificação de Importação (Portabilidade)**:
   - Apagar ou renomear a pasta `LazarusConfig` atual para simular um ambiente limpo.
   - Clicar em **Importar Perfil** e selecionar o ZIP gerado.
   - Confirmar se a restauração ocorreu e se o launcher aplicou os patches de caminho corretamente para o diretório atual.
