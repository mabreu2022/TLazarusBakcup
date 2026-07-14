# TLazarusPortable — Plano de Implementação

## Visão Geral

Criar um sistema completo de portabilidade do Lazarus IDE em dois entregáveis:

1. **`LazarusPortable.exe`** — Aplicação standalone (launcher/gerenciador gráfico) com GUI rica
2. **`LazPortableTools`** — Pacote IDE instalável no Lazarus (equivalente ao OTA do Delphi), com painel dockado

---

## Análise do Projeto Original (startLazarusPortable)

O projeto original é extremamente simples — um **programa console** em Pascal que:
- Localiza o diretório onde está o `.exe`
- Lê o `environmentoptions.xml` do Lazarus
- Substitui caminhos hardcoded por caminhos relativos ao diretório portável
- Copia arquivos de configuração temporários (pasta `LazarusConfig\`)
- Inicia o `lazarus.exe` com os parâmetros corretos

### Limitações do original
| Problema | Nossa solução |
|---|---|
| Apenas console, sem GUI | Interface gráfica com progresso e log |
| Só ajusta `environmentoptions.xml` | Ajusta **todos** os XMLs de config do Lazarus |
| Não verifica integridade da instalação | Verificação completa com diagnóstico |
| Não gerencia pacotes/componentes | Inventário e gerenciamento de pacotes |
| Não faz backup antes de modificar | Backup automático antes de qualquer modificação |
| Sem suporte a múltiplos perfis | Suporte a perfis de configuração |
| Sem instalação dentro da IDE | Pacote IDE com painel dockado |

---

## Entregável 1: LazarusPortable (Aplicação Standalone)

### Estrutura de Telas

```
┌─────────────────────────────────────────────────┐
│  🔵 Lazarus Portable Manager        [─][□][✕]   │
├──────────┬──────────────────────────────────────┤
│ TOOLBAR  │  [⚡ Lançar] [🔧 Config] [📦 Pkgs]   │
├──────────┴──────────────────────────────────────┤
│  [Aba: Início] [Aba: Pacotes] [Aba: Perfis]     │
│                [Aba: Diagnóstico] [Aba: Log]    │
├─────────────────────────────────────────────────┤
│  Conteúdo da aba atual                          │
└─────────────────────────────────────────────────┘
```

### Módulos

#### 1. `uPortableCore` — Núcleo de portabilidade
Responsabilidades:
- Detectar o diretório raiz portável (onde está o `.exe`)
- Ler/gravar `environmentoptions.xml`, `packagefiles.xml`, `fpcdefines.xml`
- Substituir todos os caminhos absolutos por relativos (ex: `$(PortableDir)`)
- Verificar integridade da instalação
- Criar/restaurar backup

Arquivos que precisam ser ajustados:
```
LazarusConfig\
  environmentoptions.xml   ← LazarusDirectory, CompilerFilename, FPCSourceDir
  packagefiles.xml         ← diretórios dos pacotes instalados
  fpcdefines.xml           ← caminhos do compilador
  *.cfg (fpc.cfg)          ← search paths do FPC
  codecompletion.xml       ← caminhos de include
```

#### 2. `uPackageManager` — Inventário de pacotes
- Listar todos os pacotes instalados (`.lpk`)
- Mostrar nome, versão, autor, dependências
- Detectar pacotes com caminhos quebrados
- Exportar/importar lista de pacotes

#### 3. `uProfileManager` — Perfis de configuração
- Suporte a múltiplos perfis (ex: "Desenvolvimento", "Produção")
- Cada perfil tem sua própria pasta de configuração
- Troca rápida de perfil sem reiniciar

#### 4. `uDiagnostics` — Diagnóstico
- Verificar existência de todos os binários
- Validar FPC e seu compilador cruzado
- Checar permissões de escrita
- Testar compilação mínima

#### 5. `uLauncher` — Lançamento
- Aplicar patches nos XMLs antes de lançar
- Passar `--primary-config-path` para o Lazarus
- Aguardar fechamento e restaurar (se necessário)
- Log de sessão

### Formulários

| Formulário | Descrição |
|---|---|
| `frmMain` | Janela principal com abas |
| `frmSplash` | Splash screen durante patch |
| `frmConfig` | Configurações do launcher |
| `frmPackages` | Visualizador de pacotes instalados |
| `frmDiag` | Diagnóstico detalhado |
| `frmAbout` | Sobre |

---

## Entregável 2: LazPortableTools (Pacote IDE — equivalente OTA)

> [!IMPORTANT]
> O equivalente ao **OTA (Open Tools API) do Delphi** no Lazarus é o sistema de **IDE Packages** com `IDEIntf`.
> Você cria um `.lpk` que o Lazarus compila e instala **dentro de si mesmo**.
> O IDE é reconstruído (`Build IDE`) incluindo seu código — assim seu painel fica **nativo** na IDE.

### Estrutura do Pacote

```
LazPortableTools.lpk        ← Arquivo do pacote Lazarus
  Requires: IDEIntf, LCL
  Units:
    uPortableIDEAddon.pas   ← Registro do addon (procedure Register)
    frmPortablePanel.pas    ← Painel principal dockado
    uPortablePatcher.pas    ← Lógica de patch dos XMLs (reutiliza do core)
```

### Funcionalidades do Painel IDE

```
┌─ Lazarus Portable Tools ─────────────────────┐
│  📁 Diretório: D:\LazarusPortable\           │
│  ✅ Configuração: OK  🔋 Perfil: Padrão       │
├──────────────────────────────────────────────┤
│  [🔧 Re-Patch Configs]  [📋 Ver Log]         │
│  [📦 Listar Pacotes]    [🔍 Diagnosticar]    │
├──────────────────────────────────────────────┤
│  Pacotes Instalados (12):                    │
│  ✅ RxLib          v2.75  OK                 │
│  ✅ SynEdit        v2.0   OK                 │
│  ⚠️  MyPackage     v1.0   Caminho quebrado   │
├──────────────────────────────────────────────┤
│  Log: [15:30:22] environmentoptions.xml OK   │
│       [15:30:22] packagefiles.xml patchado   │
└──────────────────────────────────────────────┘
```

### Integração com IDE (MenuIntf)
- Menu **Tools → Lazarus Portable Tools** com:
  - `Re-Patch Configuration`
  - `Show Portable Panel`
  - `Diagnose Installation`
  - `Backup Configuration`

### Como instalar na IDE
```
1. Abrir Lazarus
2. Package → Open Package File
3. Selecionar LazPortableTools.lpk
4. Clicar "Compile"
5. Clicar "Install" → Lazarus reconstrói com o pacote embutido
```

---

## Estrutura de Arquivos do Projeto

```
c:\Fontes\Componentes\TLazarusBakcup\
├── LazarusPortable\                    ← Aplicação standalone
│   ├── LazarusPortable.lpi
│   ├── LazarusPortable.lpr
│   ├── forms\
│   │   ├── frmMain.pas / .lfm
│   │   ├── frmSplash.pas / .lfm
│   │   ├── frmPackages.pas / .lfm
│   │   └── frmDiag.pas / .lfm
│   └── units\
│       ├── uPortableCore.pas
│       ├── uPackageManager.pas
│       ├── uProfileManager.pas
│       ├── uDiagnostics.pas
│       └── uLauncher.pas
│
└── LazPortableTools\                   ← Pacote IDE (OTA-like)
    ├── LazPortableTools.lpk
    ├── uPortableIDEAddon.pas           ← Register procedure
    ├── frmPortablePanel.pas / .lfm     ← Painel dockado
    └── uPortablePatcher.pas            ← Lógica compartilhada
```

---

## Melhorias sobre o Original

| # | Melhoria | Benefício |
|---|---|---|
| 1 | **GUI completa** com abas, progresso e log | Facilidade de uso |
| 2 | **Patch de todos os XMLs** (não só `environmentoptions.xml`) | Pacotes não quebram |
| 3 | **Backup automático** antes de cada patch | Segurança |
| 4 | **Suporte a múltiplos perfis** | Flexibilidade |
| 5 | **Gerenciador de pacotes** com status visual | Visibilidade |
| 6 | **Diagnóstico detalhado** do ambiente | Troubleshooting |
| 7 | **Pacote IDE** instalável (OTA-like) | Integração nativa |
| 8 | **Painel dockado** na IDE | Workflow fluido |
| 9 | **Log persistente** de sessões | Rastreabilidade |
| 10 | **Suporte a variáveis** `$(PortableDir)` | Configuração robusta |

---

## Plano de Execução

- [x] Análise do projeto original
- [ ] Criar estrutura de diretórios
- [ ] Implementar `uPortableCore` (núcleo de patch XML)
- [ ] Implementar `uPackageManager`
- [ ] Criar formulário principal `frmMain` com abas
- [ ] Criar formulário de diagnóstico `frmDiag`
- [ ] Criar projeto principal `LazarusPortable.lpi`
- [ ] Implementar pacote IDE `LazPortableTools.lpk`
- [ ] Criar `uPortableIDEAddon.pas` com `Register`
- [ ] Criar painel dockado `frmPortablePanel`
- [ ] Documentar como instalar o pacote na IDE

## Open Questions

> [!NOTE]
> **Versão do Lazarus alvo?** O projeto original foi feito para Lazarus 2.x. Estamos assumindo Lazarus 3.x (FPC 3.2+). A estrutura do `environmentoptions.xml` é igual.

> [!NOTE]
> **Suporte cross-platform?** O original é só Windows. Deseja suporte a Linux/macOS também? O projeto atual do workspace sugere Windows.

> [!NOTE]
> **Pacotes de terceiros?** O gerenciador de pacotes deve incluir integração com **OPM (Online Package Manager)** do Lazarus para instalar/atualizar pacotes no ambiente portável?
