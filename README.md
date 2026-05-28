# Meeting Recorder

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-111827?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/SwiftUI-native-0ea5e9?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/local--first-no%20backend-22c55e?style=for-the-badge" alt="Local-first" />
  <img src="https://img.shields.io/badge/AI-OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white" alt="OpenAI" />
</p>

<p align="center">
  <strong>Grave reuniões no Mac, transcreva com sua própria chave OpenAI e revise notas estruturadas — tudo local.</strong>
</p>

<p align="center">
  Sem login · Sem backend · Sem Supabase · Sem sync na nuvem
</p>

<p align="center">
  <a href="./video/widget.mp4">
    <img src="./video/widget.gif" alt="Meeting Recorder widget demo" width="900" />
  </a>
</p>

<p align="center">
  <a href="./video/widget.mp4"><strong>Watch the full MP4 version</strong></a>
</p>

---

## Visão geral

**Meeting Recorder** é um app nativo de **menu bar** para macOS que:

- grava **microfone** e, quando permitido, **áudio do sistema/apps**
- salva áudio e histórico **no seu Mac**
- usa **sua chave OpenAI** (guardada no Keychain)
- gera **transcrição + notas estruturadas** após o fim da gravação

Ideal para quem quer um gravador de reuniões **open source**, **local-first** e pronto para rodar na própria máquina.

### O que você recebe ao finalizar uma reunião

| Saída | Descrição |
|--------|-----------|
| Transcrição | Texto completo do que foi dito |
| Título | Nome sugerido para a reunião |
| Resumo | Síntese executiva |
| Notas detalhadas | Bullets com contexto |
| Tópicos | Temas discutidos |
| Pontos-chave | Destaques importantes |
| Decisões | O que foi decidido |
| Action items | Próximos passos |
| Perguntas em aberto | Dúvidas não resolvidas |
| Riscos / blockers | Impedimentos |
| Follow-ups | Acompanhamentos |

---

## Por que este projeto é diferente

- **Local-first**: gravações e histórico ficam no Mac (`SwiftData` + `Application Support`)
- **Sem conta**: não há login, backend ou banco remoto
- **Sua chave, seu custo**: billing da OpenAI vai para a conta do usuário
- **Reuniões longas**: áudio é preparado em **chunks** antes do envio à API
- **Recuperável**: dá para **reprocessar** a partir dos arquivos locais
- **Idioma do sumário configurável**: português, inglês ou “mesmo da transcrição”

---

## Requisitos

Antes de começar, confira se você tem:

| Requisito | Detalhe |
|-----------|---------|
| **macOS** | 14.0 ou superior (recomendado) |
| **Xcode** | Versão recente com SDK macOS instalado |
| **Git** | Para clonar o repositório |
| **Conta OpenAI** | Com créditos/API habilitada |
| **Chave de API OpenAI** | Formato `sk-...` (ver seção abaixo) |
| **Permissões do macOS** | Microfone; captura de tela/áudio do sistema (opcional) |

> **Nota:** Este app **não** precisa de Node.js, Supabase, Docker nem servidor local.

---

## Tutorial: rodar do zero no macOS

Siga os passos na ordem. O caminho abaixo usa um clone em `~/Projects/meeting-recorder` — ajuste se usar outra pasta.

### Passo 1 — Clonar o repositório

```bash
git clone https://github.com/GabrielCordeiro2412/meeting-transcriber.git
cd meeting-transcriber
```

### Passo 2 — Abrir no Xcode (opcional, mas útil)

```bash
open MeetingNotes.xcodeproj
```

No Xcode você pode rodar com **⌘R** depois de configurar a chave no app. Para linha de comando, use o passo 3.

### Passo 3 — Compilar o app

```bash
xcodebuild \
  -project MeetingNotes.xcodeproj \
  -scheme MeetingNotes \
  -configuration Debug \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Na primeira compilação o Xcode pode baixar componentes; aguarde até aparecer **BUILD SUCCEEDED**.

### Passo 4 — Obter sua chave OpenAI

1. Acesse [platform.openai.com](https://platform.openai.com/)
2. Faça login na sua conta
3. Vá em **API keys** (ou **Settings → API keys**)
4. Clique em **Create new secret key**
5. Copie a chave (`sk-proj-...` ou `sk-...`) e guarde em local seguro

**Importante:**

- A chave **não** deve ser commitada neste repositório
- O app salva a chave apenas no **Keychain do macOS** desta máquina
- O uso da API é cobrado na **sua** conta OpenAI

### Passo 5 — Abrir o app

**Opção A — Atalho do repositório**

```bash
./Open\ Meeting\ Notes.command
```

> O atalho espera o build em `.derivedData/Build/Products/Debug/MeetingNotes.app`. Rode o passo 3 antes.

**Opção B — Abrir o `.app` diretamente**

```bash
open -n .derivedData/Build/Products/Debug/MeetingNotes.app
```

O ícone aparece na **barra de menu** (topo da tela).

### Passo 6 — Configurar a chave no app

1. Clique no ícone **Meeting Notes** na menu bar
2. Toque em **OpenAI API Key**
3. Cole sua chave no campo seguro
4. Clique em **Save Key**
5. Confirme a mensagem de sucesso

Para remover ou trocar a chave depois, use **Remove Key** na mesma tela.

### Passo 7 — Escolher o idioma do sumário

1. No menu, abra **Summary Language**
2. Escolha uma opção:

| Opção | Comportamento |
|--------|----------------|
| **Same as transcript** | Notas no mesmo idioma da fala (padrão) |
| **Portuguese** | Notas sempre em português brasileiro |
| **English** | Notas sempre em inglês |

A **transcrição** segue o idioma falado (detecção automática). Esta configuração afeta só o **sumário e as notas estruturadas**.

### Passo 8 — Conceder permissões do macOS

Na primeira gravação o sistema pode pedir:

1. **Microfone** — obrigatório para capturar sua voz  
   - *Ajustes do Sistema → Privacidade e Segurança → Microfone* → habilite Meeting Notes

2. **Captura de tela / áudio do sistema** — opcional, para gravar áudio de apps (Meet, Zoom, etc.)  
   - *Ajustes do Sistema → Privacidade e Segurança → Gravação de tela* → habilite Meeting Notes  

Se a captura de sistema falhar, o app continua em modo **somente microfone**.

### Passo 9 — Gravar e gerar notas

1. No menu ou no **widget flutuante**, clique em **Start**
2. Conduza a reunião normalmente
3. Use **Pause** / **Resume** se precisar
4. Ao terminar, clique em **Finish**
5. Aguarde as fases:
   - preparação do áudio
   - transcrição por chunks
   - geração do sumário
6. Quando concluir, abra **History** para revisar, editar ou reprocessar

---

## Fluxo do produto

```text
Iniciar gravação
    → persistir áudio localmente
    → preparar chunks
    → transcrever (OpenAI)
    → consolidar transcrição
    → gerar sumário estruturado (idioma escolhido)
    → salvar no histórico local
```

---

## Onde os dados ficam

| Dado | Local |
|------|--------|
| Chave OpenAI | Keychain do macOS |
| Preferência de idioma do sumário | `UserDefaults` (local) |
| Histórico de reuniões | SwiftData |
| Arquivos de áudio | `~/Library/Application Support/.../MeetingNotes/Recordings` |

Nada disso é enviado para um backend próprio do projeto — apenas requisições diretas à **API OpenAI** durante o processamento.

---

## Estrutura do repositório

```text
meeting-recorder/
├── MeetingNotes/              # App macOS (SwiftUI + AppKit)
│   ├── AppShell/              # Orquestração e lifecycle
│   ├── AudioCapture/          # Microfone + ScreenCaptureKit
│   ├── AIProcessing/          # Contratos de processamento
│   ├── Networking/            # Cliente OpenAI
│   ├── Persistence/           # SwiftData
│   ├── Security/              # Keychain (API key)
│   └── Views/                 # UI (menu bar, histórico, etc.)
├── MeetingNotes.xcodeproj/
├── Open Meeting Notes.command # Launcher após build
└── AGENTS.md                  # Regras para contribuidores e agentes de IA
```

---

## Solução de problemas

### O atalho diz que o app não foi encontrado

Compile de novo (Passo 3). O `.app` precisa existir em `.derivedData/Build/Products/Debug/`.

### “API key missing” ao gravar

Configure a chave em **OpenAI API Key**. A gravação só inicia com chave válida (`sk-...`).

### Só grava microfone, sem áudio do app

Verifique permissão de **Gravação de tela** e reinicie o app após conceder.

### Reprocessar uma reunião antiga

Abra **History**, selecione a reunião e use a ação de reprocessar (desde que os arquivos de áudio ainda existam localmente).

### Erro na chave OpenAI ao salvar/remover

O app usa Keychain local com estratégia tolerante a builds de desenvolvimento. Se algo falhar:

1. Remova a chave pelo app (**Remove Key**)
2. Feche e reabra o app
3. Salve a chave novamente

---

## Limitações conhecidas

- **Somente macOS** (iOS/watchOS são direção futura)
- Fluxo **pós-reunião** (não há notas em tempo real)
- Custo de API OpenAI por conta do usuário
- Captura de áudio do sistema depende de permissões do macOS

---

## Contribuindo

Leia [AGENTS.md](./AGENTS.md) antes de alterar arquitetura ou fluxos críticos (áudio, persistência, Keychain, processamento).

---

## Licença e uso público

Este repositório é pensado para ser clonado e executado localmente. Ao publicar ou compartilhar:

- **nunca** commite chaves OpenAI
- **não** reintroduza backend/Supabase sem decisão explícita de produto
- mantenha o modelo **local-first**
