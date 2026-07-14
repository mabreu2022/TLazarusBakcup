# TLazarusPortable — Guia Completo e Documentação

Sistema completo de portabilidade do Lazarus IDE (Lazarus 4.8 / FPC 3.2.4+ / Windows) com dois entregáveis:

1. **`LazarusPortable.exe`**: Aplicação Standalone Gerenciadora com GUI Rica em Dark Mode.
2. **`LazPortableTools.lpk`**: Pacote IDE Instalável (equivalente ao OTA / Expert do Delphi) com menus na IDE e painel dockado.

---

## 📂 Estrutura do Projeto Gerado

```
c:\Fontes\Componentes\TLazarusBakcup\
├── LazarusPortable\
│   ├── LazarusPortable.lpi          # Projeto do Gerenciador Standalone
│   ├── LazarusPortable.lpr          # Arquivo Principal
│   ├── forms\
│   │   ├── frmMain.pas              # Lógica da Interface Principal (Tabs)
│   │   └── frmMain.lfm              # Layout Visual Dark Mode
│   └── units\
│       ├── uPortableCore.pas        # Patch de XMLs, backup, validação
│       ├── uPackageManager.pas      # Varredura .lpk, integridade e OPM API
│       ├── uProfileManager.pas      # Gerenciamento de múltiplos perfis
│       ├── uDiagnostics.pas         # Diagnóstico detalhado de ambiente
│       └── uLauncher.pas            # Lançamento seguro do lazarus.exe
│
└── LazPortableTools\                # Pacote IDE (Estilo Delphi OTA)
    ├── LazPortableTools.lpk         # Arquivo do Pacote Lazarus
    ├── uPortableIDEAddon.pas        # Registro do Menu na IDE (Register)
    ├── frmPortablePanel.pas         # Lógica do Painel de Ferramentas Dockado
    ├── frmPortablePanel.lfm         # Form do Painel IDE
    └── uSharedPatcher.pas           # Engine de patch reutilizada
```

---

## 🚀 Como Compilar e Usar

### 1. Compilando o Gerenciador Standalone (`LazarusPortable.exe`)
1. Abra o Lazarus.
2. Acesse `Arquivo -> Abrir` e selecione [LazarusPortable.lpi](file:///c:/Fontes/Componentes/TLazarusBakcup/LazarusPortable/LazarusPortable.lpi).
3. Pressione `Ctrl + F9` ou acesse `Executar -> Compilar`.
4. Copie o executável gerado `LazarusPortable.exe` para a **pasta raiz da sua instalação portável do Lazarus** (no mesmo diretório onde fica o `lazarus.exe`).

### 2. Instalando a Ferramenta Nativa dentro da IDE (`LazPortableTools.lpk` - Estilo OTA)
1. Abra a IDE do Lazarus.
2. Vá ao menu `Pacote -> Abrir arquivo de pacote (.lpk)`.
3. Selecione o arquivo [LazPortableTools.lpk](file:///c:/Fontes/Componentes/TLazarusBakcup/LazPortableTools/LazPortableTools.lpk).
4. No Editor de Pacotes, clique em **Compilar**.
5. Clique em **Instalar**.
6. O Lazarus perguntará se deseja reconstruir a IDE. Responda **Sim**.
7. Após o reinício automático da IDE, acesse o menu **Ferramentas -> Lazarus Portable Tools (Painel OTA)** para utilizar o painel integrado nativamente.

---

## ⭐ Funcionalidades Criadas e Melhorias

1. **GUI Completa e Moderna**: Visual em dark mode responsivo dividida em abas (Dashboard, Pacotes, Perfis, Diagnóstico, Log, OPM Online e Sobre).
2. **Patch em Cascata de XMLs**: Atualiza automaticamente `environmentoptions.xml`, `packagefiles.xml`, `fpcdefines.xml`, `editoroptions.xml`, `codetools.xml` e `fpc.cfg`.
3. **Gerenciador e Varredura de Pacotes (.lpk)**: Identifica todos os pacotes instalados e alerta sobre caminhos quebrados.
4. **Integração com Online Package Manager (OPM)**: Busca pacotes via API REST e baixa dependências diretamente para a instalação portável.
5. **Gerenciador de Múltiplos Perfis**: Crie e alterne rapidamente entre perfis de configuração (ex: "Desenvolvimento", "Produção").
6. **Diagnóstico Automatizado**: Checa permissões de escrita, executáveis FPC/Lazarus e gera relatórios.
7. **Pacote IDE Integrado (Estilo OTA)**: Ferramenta nativa compilada diretamente dentro da IDE para re-patch e backups em tempo real sem sair do Lazarus.
