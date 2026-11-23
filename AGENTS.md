# AGENTS.md — FNF-JS-Engine-Light (Phoenix Engine)

Documento canônico de instruções para agentes de IA que trabalham neste repositório.
**Esta é a única fonte de verdade.** CLAUDE.md, AI.md e qualquer outro ponteiro
apenas redirecionam para cá — não duplique instruções em outros arquivos.

> Se algum dia aparecer divergência entre este arquivo e outro, **este arquivo vence**.

---

## 1. O que é este projeto

**Phoenix Engine** — um Friday Night Funkin’ engine em **Haxe → OpenFL/Lime/Flixel**,
fork do *JS Engine* (Jordan Santiago), que por sua vez é um fork otimizado do
*Psych Engine*. Nome de janela: *“Friday Night Funkin' - Phoenix Engine”*;
executável: `FNF-Phoenix-Engine`; package mobile: `quack.fnf.phoenix`; versão `0.0.1`
(definida em `project.hxp`, `VERSION`).

Propósito: **performance em devices fracos + modding fácil** (Lua, e extensão
própria: **Python/Hython**), mantendo compatibilidade com mods Psych/JS Engine.

---

## 2. Stack & requisitos (segundo BUILDING.md — real)

- **Haxe 4.2.5+** (CI usa 4.3.x). `haxelib setup` / `mkdir ~/haxelib && haxelib setup ~/haxelib`.
- Agentes em Linux x86_64 sem Haxe: instalação sem sudo e testes isolados validados no [guia Haxe para Linux](docs/HAXE_LINUX.md). Cobre a toolchain, não o build completo nem as haxelibs do jogo.
- **git**, e (Windows) **Visual Studio Community** — instalação recomendada:
  `curl -# -O <url vs_Community.exe>` + `vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p`.
- (Linux) VLC/libvlc; (Win) opcional MSVC fix (ver §9 gotchas).
- Engine usa `setup/windows.bat` + `setup/windows-msvc-fix.ps1` para montar haxelibs.

**Build (raiz):**
```
haxelib run lime build windows -Dofficial
haxelib run lime build neko -Dofficial
haxelib run lime build html5 -Dofficial
haxelib run lime build flash -Dofficial -D disable-version-check
haxelib run lime build air -Dofficial -D disable-version-check -DAIR_SDK=C:\AIR\AIRSDK_51.2.2
lime test <platform>        # roda o teste
```
`<platform>` ∈ {`windows`, `linux`, `mac`}. Para limpar: `lime test cpp -clean` ou
apagar `export/`/`build/`. Android tá no CI (`main.yml`): `lime build android`.
iOS é local (`lime build ios -nosign`), sem job de CI.

Defines úteis: `-DofficialBuild`, `-Dofficial`, `-DULTRA_OPTIMIZED` (build velocidade máxima, WIP),
`-DULTRA_HTML5` (WIP), `-DDEBUG_TRACY`/`FEATURE_DEBUG_TRACY`, **`-DMODDING_LEVEL=0|1|2`**
(0 nenhum, 1 Lua, 2 Lua+Python — desktop default 2), `-Ddisable-version-check` (flash/air obrigatório),
`-debug` (build em `build/debug/` + FlxDebugger + anexo de debug do VSCode) e os flags de launch
**`-DFREEPLAY`** / **`-DMENU`** (abrem direto em `FreeplayState` / `MainMenuState`, pulando splash e
título; são mutuamente exclusivos e `project.hxp` aborta o build se ambos vierem — ver
`backend.LaunchState` e a seção "Launch and debug flags" do BUILDING.md).

Além dos flags de *build*, o executável lê **opções de linha de comando** em runtime, parseadas com
**docopt-ng** (pinada em `hmm.json` + `setup/*`, gated por `CLI_OPTIONS_ALLOWED` no `project.hxp`)
em `backend.CommandLine`: `--help`, `--version`, `--windowed`/`--fullscreen`/`--borderless`,
`--fps=<n>`, `--freeplay`/`--menu`, `--song=<name>`/`--mod=<id>` (viram rotas `phoenix://`),
`--profile`, `--vlog`, `--safe-mode`, `--troll` (legado `-troll`) e `--no-deeplinks`. Valem só para
a sessão — nada é gravado no save — e um argumento inválido **nunca** impede o boot (volta tudo ao
default e o motivo vai pro vlog). Referência: `docs/CLI.md`; spec: `bash tests/haxe/run-command-line.sh`.

Todo build feito dentro de um checkout git recebe `-Dcommit` automaticamente (o `project.hxp`
sonda `git rev-parse --verify HEAD`), o que estampa o SHA usado pelo watermark do canto inferior
direito (`debug.CommitWatermark`) e pela linha de commit do FPS counter. **`-Dno-commit`** desativa
a estampa para builds reproduzíveis; fora de um repositório git ela simplesmente não acontece.

---

## 3. Estrutura do repositório (top-level)

```
FNF-JS-Engine-Light/
├── project.hxp            # build Haxe-lime (config principal; NÃO é XML)
├── hmm.json               # declarative haxelibs
├── setup/                 # setup por SO + msvc-fix
├── source/                # TODO o código-fonte Haxe (pasta classpath principal)
├── assets/                # jogos assets (preload/shared/songs/...) — estado "no assets" (ver §6)
├── mods/                  # mods carregáveis em runtime
├── modsList.txt           # mods embutidos no build
├── docs/                  # guias (TemplateScript.py/.lua, PDF de como usar)
├── .github/workflows/     # CI: main, checks, docs, releases, housekeeping...
├── BUILDING.md            # guia de build
├── CODESTYLE.md           # guia de estilo
├── checkstyle.json        # config Haxe-Checkstyle
├── hxformat.json          # config Haxe Formatter
├── .vscode/               # tasks/lint/launch (Lime, HaxeCheckstyle)
└── build/                 # saída de builds (ignorada no git — build/release/android etc.)
```

> Fonte vive em `source/`, **não** em `src/`. Assets em `assets/` (libraries: `preload`,
> `shared`, `songs`). Código `Main.hx` na raiz de `source/`.

---

## 4. Arquitetura e fluxo de inicialização

- **Entry point:** `Main.hx` → `backend.BootState`/`InitState` → `TitleState` → `MainMenuState`/
  `StoryMenuState`/`FreeplayState`/`PlayState`. Todos os estados extendem
  `MusicBeatState`/`MusicBeatSubState` (`backend/MusicBeatState.hx`).
- **`Main.hx`**: parseia as opções de linha de comando (`backend.CommandLine.load()`, `docs/CLI.md`)
  antes de criar a janela — `--help`/`--version` são respondidos ali e saem — e então cria
  `FunkinGame`, registra `FlxFix`, carrega `ClientPrefs`, `Achievements`, `Paths`, `Achievements`,
  `PlayerSettings`, splash, inicializa estados.
- **`backend/`**: núcleo não-jogável
  - `Paths.hx` — localização de assets/mod paths; `Paths.mods/`, `Paths.stage`, `Paths.char` etc.
  - `Paths.currentModDirectory`, `Paths.currMod` — decidi o dir de mod ativo.
  - `ClientPrefs.hx` — todos os pref do jogador (data/options; persistidos).
  - `Conductor.hx` — tempo de música + BPM (crochet, stepCrochet, beat/step).
  - `Highscore.hx` — scores/saves; `WeekData.hx` — semanas; `Song.hx`/`SwagSong` — charts;
    `Section` — seções; `Mods.hx` — carregamento de mods; `Paths.getPath`.
  - `CoolUtil.hx` (este é um fork modificado) — helpers genéricos (número compacto,
     dificuldade, arquivos).
- **`play/PlayState.hx`** — o coração do gameplay (jogo, notas, personagens, câmera, eventos).
  **Decomposto em helpers:** `play/helpers/` — `PlayStateNotes/Notes/Input/Camera/Countdown/
  Characters/Events/Playback/PlayStateScripts/...` + `play/` — `PlayState.hx`, `Conductor`,
  `SpawnedNote`... & `play/helpers/*` = lógica delegada.
- **`states/`**: menus (`MainMenuState`, `FreeplayState`, `StoryMenuState`, `CreditState`,
  `OptionsMenuState`...), substates (`PauseSubState`, `GameOverSubstate`, `ResetScoreSubState`,
  `GameplayChangersSubstate`, `CharacterSelector...`). `ModState` / `ModSubState` are blank
  hosts for `data/states/<Name>.hx` (see `psychlua.StateScripts`).
- **`objects/`**: `Note.hx`, `NoteSplash.hx`, `StrumNote.hx`, `HealthIcon.hx`, `Alphabet.hx`,
  `Character.hx`, `Boyfriend.hx`, `FlxText`, `BG`, `BGSprite`...
- **Alphabet (texto de menus)**: `objects/Alphabet.hx` monta cada letra como um
  `AlphaCharacter` e tem **dois renderizadores**, escolhidos pelo jogador em
  Options -> Visuals and UI (`ClientPrefs.alphabetStyle`, padrão `Font`):
  - `Font` rasteriza glifos de uma fonte real (`ClientPrefs.alphabetFont`):
    `assets/fonts/vcr.ttf` (**VCR OSD Mono**, já embutida) e `assets/fonts/inconsolata.ttf` +
    `inconsolata-bold.ttf` (**Inconsolata**, adicionada, SIL OFL 1.1 em
    `assets/fonts/LICENSE-inconsolata.txt`). Dividido em `objects/AlphabetFont.hx`
    (modelo **puro**, sem Flixel/OpenFL: estilos, fontes, tamanhos, chaves de cache) e
    `objects/AlphabetFontRenderer.hx` (rasterização via `openfl.text.TextField` + atlas
    compartilhado de `FlxGraphic`, para manter os menus em poucos draw calls). Qualquer
    caractere imprimível é desenhado, e o espaçamento vem das
    métricas da fonte — sem tabela de offsets por letra.
  - `Image` mantém o spritesheet clássico `images/alphabet` (caminho antigo intacto, e
    fallback automático se a fonte não carregar).
  `Alphabet.reloadAll()` redesenha os alphabets vivos ao trocar a opção; `AlphabetFont`
  também é exposto ao HScript. Testes: `tests/haxe/run-alphabet-font.sh` (interpretador,
    entra no CI) e `tests/haxe/run-alphabet-typecheck.sh` (typecheck html5+native contra
    flixel/openfl/lime; pula se as haxelibs não estiverem instaladas).
- **`stages/`**: `StageData.hx` + implementações de stage por semana (`StageWeek1` etc.).
- **`options/`**: menu de opções + toggles (via `options/helpers`).
- **`editors/`**: ChartEditor, WeekEditor, CharacterEditor, StageEditor, DialogueEditor e o **Modchart Lab** (`ModchartLabState`, sintonizador visual dos 34 modificadores com export Lua/Python — ver `docs/MODCHART.md`).
- **`psychlua/`**: **scripting** — FUNKINLUA (Lua), PythonScript (Hython) + HScript (hscript-improved).
- **`shaders/`**: efeitos (Grain, VHS, ChromaticAberration, Glitch, etc.).
- **`utils/`**, **`mobile/`** (controles mobile + hitbox), **`backend/states`** etc.

---

## 5. Sistemas de scripting (Lua / Python / HScript)

- **Lua**: arquivos `.lua` em `mods/scripts/`, `mods/data/<song>/`, `mods/stages/`,
  `mods/custom_notetypes/`, `mods/custom_events/`; via `psychlua/*.hx`.
  `modding/psychlua/LuaUtils`/`FunkinLua` — engine de callbacks.
- **Python**: igual a Lua, arquivos `.py` com `def onCreate()`, `def onUpdate(elapsed):` etc.
  Interprete **Hython** (pure-Haxe), compilado apenas quando `-DMODDING_LEVEL=2`.
- **HScript**: arquivos standalone `*.hx`/`*.hscript` nos mesmos escopos de Lua/Python
  (`scripts/`, `data/<song>/`, `stages/`, `characters/`, `custom_notetypes/`,
  `custom_events/`), sem pai Lua — `psychlua/HScript.hx` (`PlayState.hscriptArray`,
  `startHScriptOnFolder`, mesmos hooks/sentinelas); também embutido em Lua via
  `runHaxeCode`/`runHaxeFunction`/`addHaxeLibrary`; via `hscript-improved`.
- Callbacks principais (o que mods podem usar): `onCreate/onCreatePost`, `onUpdatePost`,
  `onCountdownTick`, `onStartCountdown`, `onSongStart`, `onNoteHit`, `onNoteMiss`,
  `onGoodNoteHit`, `onStepHit`, `onBeatHit`, `onSectionHit`, `onRecalculateAllScores`,
  `onGameOver`, `onPause`, `onResume`, `onEndSong`, `onTweenCompleted`, `onCameraMove`
  (ver `docs/TemplateScript.py` e `.lua` para a lista canônica). Publicados via `PsychLua`/
  `LuaUtils`; chamados em `PlayState.hx`/helpers — se você VAI adicionar um callback novo,
  siga o padrão: registrar no helper de scripts + `callOnScripts(...)` + documentar no template.

---

## 6. Mods & conteúdo

- Mods ficam em `mods/<mod>/` (structure: `mods/<mod>/data/`, `mods/<mod>/images/`,
  `mods/<mod>/songs/`, `mods/<mod>/weeks/`, `mods/<mod>/scripts/`). O formato segue Psych.
- Lista de mods habilitados: `modsList.txt` na raiz do mod armazenado (autogerado).
- `Project.hxp` (root): `addAssetPath` para semana/`songs`, `mods` embedded (`mods/*`),
  `assets embed` para flash/air.
- Conteúdo vanilla: `assets/preload/songs` (não existe mais), `assets/preload/data`, `assets/songs`.
- Se adicionar mod de exemplo: siga `mods/<mod>/{data,images,songs,weeks}` + `pack.json`.

### Conteúdo vanilla e modo compacto

- Os assets vanilla estão no repositório; não os remova para implementar o
  modo compacto. A seleção ocorre somente na configuração da build.
- Builds locais usam conteúdo completo por padrão. `-DNO_BUILTIN_CONTENT` é o
  modo compacto usado no CI: mantém Tutorial, Week 1 completo, seus personagens,
  palco e sprites, a interface e mods; remove as semanas posteriores e vídeos.
  Apesar do nome, ele contém conteúdo protegido por direitos autorais.
- Workflows de release passam `fullAssets: true` e incluem todos os assets.

### Áudio: Ogg, uma cópia só

- **Nunca** versione a mesma faixa em `.ogg` **e** `.mp3`. O engine prefere Ogg
  (`Paths.SOUND_EXT = "ogg"`; só Flash/AIR usa MP3) porque decodifica e busca mais rápido
  que MP3 na mesma taxa — o que importa num jogo de ritmo.
- `Paths.SOUND_EXTENSIONS` (`ogg`, depois `mp3`) é resolvido em runtime por
  `Paths.modsSounds()`, `Paths.resolveSoundAsset()` e `Paths.returnSound()`: mods podem
  enviar qualquer um dos dois, mas o repositório fica **só Ogg**.
- Ao adicionar música/SFX: `ffmpeg -i in.wav -vn -c:a libvorbis -q:a 2 out.ogg`
  (`tools/compress-audio.sh` já faz isso em lote; `-q:a 2` ≈ 96 kbps VBR).
- Nunca versione um par `.ogg`/`.mp3` da mesma faixa; revise isso no code review.

---

## 7. Convenções de código (CODESTYLE.md + hxformat.json + checkstyle.json)

- **Haxe**: indentação **2 espaços** (não tabs) — `hxformat.json` (`"character":"  "`).
- Formatação via extensão **vshaxe**/Haxe Formatter (esta é a regra de ouro: rode o formatter,
  não formate na mão) + **Haxe Checkstyle** (`checkstyle.json`) para qualidade (severity
  configurável; vários checks ainda TODO/IGNORE — ver CODESTYLE.md).
- Nomes: classes em `UpperCamelCase`, métodos/vars em `lowerCamelCase`, constantes UPPER_SNAKE.
- Erros de build/file style citar: `Code Style Guide` (CODESTYLE.md).
- **JSON** (charts, weeks, prefs, checkstyle): formatado por **Prettier** (`esbenp.prettier-vscode`).
- Linhas ~160chars máx (checkstyle `LineLength`), sem tabs, sem trailing whitespace.
- **Comentários em Haxe**: `//` para linha, `/** */` para doc (doco sobre membros públicos importantes);
  bloco ASCII `/* */` para separar seções de código (padrão do repo).
- Favor documentar função pública nova com `/** @param ... */` quando tiver parâmetros não óbvios.

### Testes: Haxe por padrão, Python **não**

- **Não é permitido** escrever testes em Python (`.py`) para o engine. Teste do engine é
  **Haxe**: spec em `tests/haxe/*Spec.hx` + runner `tests/haxe/run-<nome>.sh`/`.bat`/`.ps1`
  (mesmo formato dos que já existem).
- Python só é aceitável para teste **quando o código testado é um softmod** — isto é, quando
  o teste vive **dentro da pasta do mod** (`mods/<mod>/...`, `example_mods/<mod>/...`), junto
  do próprio conteúdo do mod. Fora de pasta de mod, não.
- Isso inclui os guards estáticos de `tests/test_*.py`: **não crie mais nenhum**, não estenda
  os existentes; ao mexer numa área que eles cobrem, mova a verificação para um spec Haxe
  (ou deixe para a CI que já roda). Eles são legado, não um padrão a seguir.
- Scripts de ferramenta em `tools/*.py` chamados pela CI (checagem de manifesto, versão,
  dependências) **não** são testes e continuam como estão — mas ferramenta nova só entra se
  não der para fazer em Haxe/shell, e não vire desculpa para "testar" em Python.
- Template de script de mod (`docs/TemplateScript.py`, `example_mods/scripts/TemplateScript.py`)
  é conteúdo de mod/softmod: pode ficar em Python, é o runtime Hython que o carrega.

---

## 8. Regras de modificação (IMPORTANTE — siga SEMPRE)

1. **Não** quebre compatibilidade com mods Psych/JS Engine sem discutir antes: charts
   (`SwagSong`), semanas (`WeekData`), notas (`Note`), stages (`StageData`), callbacks Lua/Python.
2. Ao mudar `Paths.mods`/diretório de mod: garanta fallback para `assets/`.
3. Novos assets: coloque em `assets/<lib>/...` e registre no `project.hxp`
   (`addAssetPath`/`addAssetLibrary`) se precisar de embed/preload (flash/air = embed).
4. Ao editar `PlayState.hx`, prefira **usar os helpers** (`play/helpers/*`) já existentes;
   não re-injeite lógica monstruosa no arquivo núcleo.
5. Callbacks de script: manter Lua∩Python simétricos (mesma assinatura) sempre que fizer sentido.
6. **Teste o build** (`lime build <platform> -Dofficial` ou `lime test windows`) antes de declarar pronto.
7. Não adicione dependências sem atualizar `hmm.json`/`setup`. Temas de versão pinada: ver §9.
8. Código de produção sem `trace()` órfão; perf-sensíveis com `#if !debug` quando necessário.
9. Toda mudança de feature/flag pública deve atualizar `ClientPrefs`/`Options` se visível ao jogador.
   Opções específicas de plataforma usam `backend.PlatformSupport` (`Option.onlyOn([...])` ou
   `requirementsForPreference()` para o campo de `ClientPrefs`), não `#if` solto — `#if` fica só
   para código que não compila em outro target. Mods embutidos declaram `"platforms"` no
   `pack.json` e são filtrados por `Mods.isSupportedOnThisPlatform()` e por
   `BUNDLED_MOD_PLATFORMS` no `project.hxp`. Teste: `bash tests/haxe/run-platform-support.sh`.
10. **Não** commits de `build/` (ignorado) nem de `art/` não-necessários; manter tree limpa
    (`git status`) antes de PR.
11. **Nada de teste em Python** fora de pasta de mod (softmod). Teste de engine = spec Haxe em
    `tests/haxe/`. Ver §7 "Testes: Haxe por padrão, Python não".
12. **Comentários no estilo JSDoc em todas as alterações de código.** Toda classe, função,
    método e campo novo ou modificado deve ter um bloco de documentação `/** ... */` no estilo
    [JSDoc](https://jsdoc.app/): descrição curta e, quando houver, tags `@param`, `@return`/`@returns`,
    `@throws` e `@deprecated`. Vale para código Haxe e também para qualquer outra linguagem que
    o repo use. Ao alterar uma função existente, atualize a documentação dela junto com o código.
13. **Anexe sempre um screenshot no PR em caso de alteração visual.** Sempre que o PR adicionar ou
    modificar algo visível no jogo, nos menus ou na interface, anexe na descrição do PR uma captura
    de tela demonstrando a mudança:
    - Nova opção de menu → screenshot do menu com a nova opção visível.
    - Nova música → screenshot da tela de Freeplay (`FreeplayState`) com a música visível.
    - Outras alterações visuais (HUD, layout, fontes/Alphabet, sprites, personagens, stages,
      shaders, telas, editores, site/docs, etc.) → screenshot mostrando o resultado visual
      (antes/depois quando ajudar na revisão).
    - **Não** commite arquivos temporários de screenshot no repositório; anexe-os apenas na
      descrição do PR. Se não for possível capturar a tela no ambiente atual, registre o motivo
      explicitamente no PR em vez de omitir em silêncio.

---

## 9. Gotchas de build (todos do BUILDING.md — reais)

- **Flash/AIR**: obrigatório `-D disable-version-check`; flash usa `-D disable-version-check`
  e `-DAIR_SDK` DEVE ser **um único token** (`-DAIR_SDK=C:\AIR\...`), NÃO via env var.
- **HTML5**: usa definições `-D analyzer-optimize` + `-D js-es=6`; o áudio é **Ogg**
  (o exclude web não filtra `*.ogg` — filtrar isso deixaria o build web mudo). Só
  Flash/AIR usa MP3 (`Paths.SOUND_EXT`).
- **Linux**: instalar `libvlc` (hxvlc/hxCodec) — erro típico `libvlc.so.5 ... syntax error` → usar hxCodec 3.0.2 ou instalar VLC.
- **MSVC Windows (LNK1181/LNK1120)**: rodar `setup/windows-msvc-fix.ps1` (ativa fork hxcpp com
  suporte `<assembler>` + J17); ou `lime test cpp -clean`/apagar `export/obj`.
- **Android (`dlopen failed: library "libc++_shared.so" not found ... needed by ... liblime.so`)**:
  o `liblime.so` pré-compilado do fork do lime linka contra o `libc++_shared` e nada no
  Lime/Gradle copia esse runtime pro APK. O `project.hxp` (`configureAndroidRuntime`) registra
  um pre-build callback que roda `setup/android-copy-stl.sh` (ou `.bat` no Windows) e copia o
  `libc++_shared.so` do NDK para `build/<tipo>/android/bin/app/src/main/jniLibs/<abi>/`.
  Confira com `unzip -Z1 <apk> | grep libc++_shared` — o CI checa isso no step
  `Verify Android APK native libs`. Detalhes em `BUILDING.md`.
- Runtime `lime.hdll` (HashLink) **bloqueado neste fork** — use windows/neko/linux/mac/html5.
- Estado do build local: **só `build/release/android/` presente** (build release Android antigo,
  Haxe 4.3.7, NDK 27.2.12479018, versão 0.3.2) — não é a fonte de build atual; a versionName vem
  do `VERSION` em `project.hxp` (via `meta.version`/`::APP_VERSION::`) e o versionCode do
  build number do Lime (`::APP_BUILD_NUMBER::` no template Android), não do `project.hxp`.
- **`build/release/android`** mostrou completa artefatos `.so` + `.obj` mas **sem `.apk` final** —
  o pipeline Gradle/APK não chegou a rodar no último build local. Use CI (`main.yml`) para APK.

### 9.1. Módulos C++ nativos (`source/backend/native/`)

O padrão do repo para código nativo é **um par `.h`/`.cpp` + um `build.xml`**, nunca
`@:cppFileCode` com C++ grande. `.cpp` só entra como *translation unit* própria quando
precisa de headers que não devem vazar para o C++ gerado pelo hxcpp (`windows.h`,
`Xlib.h`: eles definem `None`, `Bool`, `min`, `max`…). Referência viva:
`refresh_rate_build.xml` (Linux/X11) e `gdi_build.xml` (Win32/GDI).

`build.xml` nativo — os cinco detalhes que já quebraram build de verdade:
- `<pragma once="true" />` é **obrigatório** sempre que o arquivo é puxado por mais de um
  `@:buildXml`. Sem ele o hxcpp registra o grupo duas vezes e o build falha.
- Um `<file name="...">` só é compilado se estiver dentro de um `<files id="...">` que
  algum `<target id="haxe">` **referencie** (`<files id="nome" />`). Um grupo declarado e
  nunca referenciado é silenciosamente ignorado — o `.cpp` nunca compila, o header resolve,
  e o erro só aparece no **link** (`unresolved external symbol`).
- O `<files id="haxe">` recebe o `-I` do include path e um `<depend>` para **cada** header
  que o `.cpp` inclui. O hxcpp hasheia esses `<depend>` ao reusar objetos cacheados: header
  não declarado = objeto velho com código antigo, e o cache do CI esconde a mudança.
- Linkagem por SO vai dentro de `<target id="haxe"><section if="windows">` (ou
  `if="linux" unless="android"`). Nomear `user32.lib`/`gdi32.lib` no XML é o que o MinGW
  precisa; no MSVC o `#pragma comment(lib, ...)` do header já resolve, mas manter os dois
  é o padrão daqui.
- **Não** use `<compilerflag value="/std:c++17" />` para escolher o padrão de C++. O
  `project.hxp` já define o haxedef **`HXCPP_CPP17`** (o `hxcpp` então emite `-std=c++17`),
  e o hxcpp **acrescenta o próprio `-std=` depois** de qualquer `compilerflag`, então o
  padrão antigo (`-std=c++11`) vence calado. Se um arquivo isolado precisar de outro padrão,
  use o atributo `cxx_standard="17"` no `<files>`/`<file>`.

C++ que compila no Linux e quebra no MSVC — checklist ao tocar `.cpp` nativo:
- **`<algorithm>` explícito** para `std::min`/`std::max`/`std::sort`. A libstdc++ puxa
  `std::min` transitivamente por `<string>`/`<vector>`/`<map>` e o GCC aceita; a STL do
  MSVC **não**, e o job Windows falha. Isso é invisível para `g++ -fsyntax-only` local —
  nunca valide código nativo só pelo GCC.
- **`NOMINMAX` antes de `<windows.h>`**, senão `min()`/`max()` como macro quebram `std::min`.
  Defina no header (com `#if !defined(NOMINMAX)`), não no build.xml, para valer em qualquer
  ordem de include; `hxcpp.h` também define, mas o header pode ser visto antes.
- **`<cstdlib>`** para `rand()`/`abs()`, `<cstring>` para `memcpy`, `<cstdio>` para `sprintf`.
  Os headers do Windows "emprestam" esses símbolos e o GCC compila por acidente.

Como validar nativo **sem** mingw/MSVC nesta máquina: escreva stubs de `windows.h`,
`dwmapi.h`, `winuser.h` e rode
`g++ -std=c++17 -D_WIN32 -D_M_X64 -I<stubs> -I<dir do header> -fsyntax-only <arquivo>.cpp`.
Pega erro de sintaxe e de símbolo, **não** pega a diferença de STL descrita acima — nesse
caso a evidência final é o job Windows da CI. Para provar que o hxcpp realmente compila um
`.cpp`, use um compilador falso que só loga `argv` no PATH: a saída do hxcpp lista
`Compiling group: <nome> (N files)`, e o `.cpp` deve aparecer no log de chamadas.
Bypass do cache de objetos (`rm -rf obj`) é obrigatório ao comparar variantes de `build.xml`,
senão o hxcpp reusa o objeto antigo e as duas variantes parecem iguais.

**Localize o alvo antes de investigar.** Um módulo nativo Windows-only compilado num
`<section if="windows">` aparece como `Compile (Windows)` vermelho e `Compile (Android)` verde.
Isso já diz que o problema é C++/MSVC, não Haxe — o Android nem toca naquele `.cpp`. O
inverso (Android vermelho, Windows verde) aponta para Haxe/typecheck ou para o NDK. Antes de
mexer em código, confirme ainda **se aquele arquivo já compilava** naquele alvo: rode o
`-fsyntax-only` com stubs e o teste do compilador falso; se o `.cpp` nem aparecia no
`Compiling group:`, o vermelho é de *link* ou é anterior à sua mudança, e "consertar" o C++
não muda nada.

---

## 10. CI / GitHub Actions

- `.github/workflows/main.yml` — build compartilhado: Windows e Android (ubuntu-24.04,
  Haxe 4.3.7, NDK 27.0.12077973). Trigger: `push`/`pull_request` em main/bleeding,
  `workflow_dispatch` e `workflow_call`. Valida o manifesto e as libs nativas do APK.
- `mobile-release.yml` — valida uma tag Phoenix existente e reutiliza `main.yml` com
  apenas Android habilitado para publicar o APK. O antigo `mobile.yml` duplicava esse build.
- `release.yml` — publica o artefato Windows de `main.yml` em uma draft release.
- `checks.yml` — regressões Java/nativas; `docs.yml` — build e deploy do site.
- `sparse-submodule.yml` — valida o checkout sparse e o link do mod fnf_030_ui.
- `nightly.yml`, `autotriage.yml`, `autolock.yml` — housekeeping.
- **Caches (quota de 10 GB):** cada cache do Actions é um snapshot imutável do `path`. As
  chaves em `main.yml` (`CACHE_SCHEMA` + target + OS/arch + Haxe + `hmm.json`/setup + flags)
  **não** incluem `source/`, `project.hxp` nem o próprio workflow: se incluírem, cada commit
  cria um snapshot novo de 140–370 MB e as entradas só se acumulam. O save usa a **mesma**
  chave do restore (`cache-hit` só é true com match exato), então o cache é rolante. PRs só
  leem; `push`/`workflow_dispatch`/`workflow_call` salvam. Gradle é cacheado à mão em
  `~/.gradle/caches` (nunca `cache: gradle` do setup-java: ele hasheia um projeto que o Lime
  só gera durante o build, então erra sempre e salva 512 MB por PR). Quem mexe nisso roda
  `bash tests/haxe/run-build-cache-policy.sh` (roda em `checks.yml`, sem toolchain). Cabeçalho
  nativo novo precisa de `<depend>` no `build.xml` respectivo, senão o objeto cacheado fica
  com o código antigo.
- **Sem CodeQL:** não adicionar workflows `github/codeql-action` nem ativar o default setup
  de code scanning. O default setup é uma configuração do GitHub, separada dos arquivos de workflow.
- Para rodar android localmente (Windows): configurar Android SDK/NDK via `haxelib run lime config`
  (ver BUILDING.md / workflows).

---

## 10.1. Labels em issues e pull requests

**Obrigatório:** ao criar ou atualizar uma issue **ou** um pull request, consulte os
labels disponíveis no GitHub (`gh label list --limit 200`) e aplique **todos os que
se aplicam**, não apenas um label principal nem só o de origem da IA. Combine tipo,
área/plataforma, prioridade, origem e estado quando houver evidência para cada um.
Reavalie-os se o escopo ou estado mudar; não remova labels válidos de outras pessoas
sem motivo. Use os nomes exatos, inclusive espaços e maiúsculas. Se faltar permissão,
informe quais labels deveriam ser aplicados e o erro; não finja que foram aplicados.
Não crie labels novos nem altere issues/PRs antigos apenas por causa destes exemplos.

O catálogo abaixo foi conferido no GitHub; consulte-o novamente porque pode mudar.
Os exemplos remetem a issues/PRs reais, mas são **orientações de classificação**,
não uma afirmação de que todos esses labels estavam atribuídos historicamente.
Condições hipotéticas de estado/prioridade não são fatos sobre os itens citados.

| Label | Quando aplicar; exemplo baseado no histórico |
| --- | --- |
| `bug` | Algo não funciona: PR #105, correção do gameplay do BF Clicker. |
| `documentation` | Documentação adicionada/corrigida: issue #92, afirmação incorreta no BUILDING.md. |
| `duplicate` | Issue ou PR repete outro existente; por exemplo, #92 e #82 tratam dos mesmos avisos de MP3: confirmar antes qual é o duplicado. |
| `enhancement` | Recurso ou melhoria: PR #309, ajuste de navegação para Android TV. |
| `good first issue` | Tarefa pequena e acessível a iniciantes, após avaliar escopo; por exemplo, uma correção pontual como a issue #84, se confirmada simples. |
| `help wanted` | Precisa de ajuda adicional ou contribuição externa; por exemplo, auditoria iOS #80 se os mantenedores pedirem ajuda. |
| `invalid` | Relato/proposta comprovadamente inválido ou fora do escopo; por exemplo, um relato como #92 **se** investigação mostrasse que a alegação é falsa. |
| `question` | Pedido de esclarecimento ou investigação ainda dependente de resposta: issue #89, verificar uso de `FlxG.watch`, quando houver pergunta aberta. |
| `wontfix` | Decisão dos mantenedores de não implementar/corrigir; por exemplo, proposta #81 **se** fosse explicitamente recusada. Não presumir essa decisão. |
| `codex` | Conteúdo gerado pelo Codex, quando a origem for conhecida: PR #18. Não aplicar a qualquer IA indistintamente. |
| `stale` | Inatividade por 30 dias conforme política; issue #80 **se** aberta e inativa por esse período. `autolock.yml` automatiza issues, não PRs; não presumir inatividade. |
| `status: pending triage` | Issue aguardando primeira resposta de mantenedor; por exemplo, #80 quando recém-aberta e ainda sem resposta. `autotriage.yml` remove em comentário ou fechamento de issue. |
| `MOBILE - Android` | Android é diretamente afetado: issue #75 ou PR #309. |
| `MOBILE - iOS` | iOS é diretamente afetado: issue #80. |
| `P0` | Prioridade crítica e urgente, após confirmar impacto; por exemplo, issue #65 **se** confirmada como exploração crítica ativa. |
| `P1` | Alta prioridade, problema grave sem a urgência de P0; por exemplo, issue #64 **se** bloquear builds Android importantes. |
| `P2` | Prioridade intermediária: PR #207, suporte para copiar diagnósticos, identificado como P2 no título. |
| `P3` | Baixa prioridade, melhoria cosmética ou não urgente; por exemplo, issue #84 se a avaliação confirmar impacto baixo. Use apenas uma prioridade, conforme impacto e triagem, não o número da issue. |
| `Windows` | Windows é diretamente afetado: PR #240, modo de renderização no Windows. |
| `Web/HTML` | Web/HTML5 é diretamente afetado: issue #88, pressão do garbage collector em HTML5. |
| `dependency issue` | Problema causado por dependência ou configuração dela: issue #42, forks diferentes de hxcpp. Não confundir com uma simples atualização de dependência. |
| `not really a bug but its something to check out` | Algo que merece investigação, mas não está comprovado como bug: issue #89, verificação do `FlxG.watch`. |
| `SOFTmodding` | Scripts/mods sem recompilar a engine são afetados: PR #105, mod BF Clicker; issue #77, sandbox de scripts Lua/Python. |
| `HARDmodding` | Modificação direta do código-fonte da engine ou extensão compilada para modding: PR #266, modcharts nativos. Não usar só porque um PR altera código interno. |
| `Arena.AI` | Issue ou PR gerado pelo Arena.AI: issue #80 ou PR #277. Não aplicar a trabalho de outra ferramenta sem evidência. |
| `big and complex PR that may give cool beneficts` | PR amplo e complexo com potencial benefício que merece avaliação: PR #277 ou #236; não rotular toda mudança grande automaticamente. |
| `dependencies` | PR que atualiza arquivo de dependências: PR #170, atualização de React, ou #252, atualização de action. |
| `github_actions` | PR que atualiza código/configuração de GitHub Actions: PR #252, atualização de `actions/checkout`. |
| `javascript` | PR que atualiza código ou dependências JavaScript: PR #170, atualização de React no website. |

Exemplos de **combinações**, sujeitos à verificação do escopo e origem: issue #92 →
`bug` + `documentation` + `Arena.AI`; issue #77 → `enhancement` + `SOFTmodding` +
`Arena.AI`; PR #309 → `enhancement` + `MOBILE - Android`; PR #252 → `dependencies` +
`github_actions`; PR #170 → `dependencies` + `javascript`. Acrescente prioridade,
estado ou outros labels apenas se as respectivas condições forem confirmadas.

---

## 11. Checklist antes de finalizar uma tarefa

- [ ] `git status` limpo (só os arquivos intencionais) e nada em `build/`.
- [ ] Código formatado (Haxe Formatter) + sem warnings/errors de Haxe-Checkstyle novos.
- [ ] Build compila: `haxelib run lime build <platform> -Dofficial` (ou o target do seu trabalho).
- [ ] Se mexeu em scripts/callbacks: testou com um mod de exemplo (`.lua` e `.py`).
- [ ] Se adicionou teste: é spec Haxe em `tests/haxe/` — **nenhum** `tests/test_*.py` novo
      (Python só dentro de pasta de mod/softmod).
- [ ] Se mexeu em assets: registrou no `project.hxp` quando necessário.
- [ ] Comentários no estilo JSDoc (`/** ... */` com `@param`/`@return` quando couber) em todo código alterado (regra 12 da §8).
- [ ] Se houver alteração visual (nova opção de menu, nova música no Freeplay, HUD, sprites, telas, etc.): anexou screenshot na descrição do PR (regra 13 da §8), sem commitar a imagem temporária no repositório.
- [ ] Sem `trace()` de debug esquecido; sem segredos/chaves commitadas.
- [ ] Mensagem de commit curta no estilo do repo (Conventional-ish, tipo “fix: ...”, “feat: ...”).

---

## 12. Trabalhar em pull requests (triage, reparo, merge)

### 12.1. Ordem de prioridade

Processe **um PR por vez**, nesta ordem — não pelo número, e não em paralelo:

1. **Build quebrado / não compila** — bloqueia todo mundo, inclusive a própria CI dos outros PRs.
2. **Bug crítico, segurança, crash, perda de dados**.
3. **PR que desbloqueia outros** (dependência de outro PR aberto, mudança em `project.hxp`,
   `.github/workflows/*`, `hmm.json`, `setup/`).
4. **Feature / enhancement**.
5. **Cosmético, docs, housekeeping**.

Reavalie a cada merge: um PR de feature que vira conflito por causa de um merge anterior
sobe de prioridade. **Nunca mescle um PR só para resolver conflito.**

### 12.2. Antes de tocar em qualquer coisa

```bash
gh pr view <n> --json number,title,state,mergeable,mergeStateStatus,headRefName,headRefOid,baseRefName
gh pr diff <n> --name-only          # superfície real da mudança
gh pr checks <n>                    # Android / Windows / Regression / Lua / hxcpp smoke
```

Leia o `mergeStateStatus`: `CLEAN` = mergeável; `DIRTY` = conflito real; `BEHIND` = só falta
sincronizar; `BLOCKED` = falta check ou review obrigatório; `UNKNOWN` = o GitHub ainda está
calculando — espere ~20 s e consulte de novo em vez de agir.

**Nunca trabalhe na branch `main`.** Cada PR é reparado na **branch de origem dele**,
`arena/<id>-fnf-phoenix-engine`. Abra um worktree por PR
(`git worktree add /tmp/wt/<id> <branch>`) para não misturar estado.

### 12.3. Integrar a `main` na branch do PR

```bash
cd /tmp/wt/<id>
git fetch origin
git merge origin/main --no-edit   # resolva na mão; nunca rebase/force-push por cima do autor
```

Regras de resolução de conflito:
- **Analise conflito por arquivo, não “aceite um lado”.** Leia os dois lados e o que cada
  um queria fazer. O resultado tem que preservar a intenção **das duas** branches.
- **`.github/workflows/checks.yml` é o conflito recorrente.** Quase todo PR adiciona um
  step de teste novo ancorado no mesmo lugar (depois do último `- name:` existente). A
  resolução correta é **manter os dois lados**, não escolher um: cada step é o runner de um
  spec diferente e os dois precisam rodar. Depois valide que cada script referenciado existe
  e roda (`bash tests/haxe/run-<nome>.sh`).
- **Nunca** `git checkout --ours/--theirs` no arquivo inteiro, `git reset --hard`,
  force-push, ou reescrever commits de outra pessoa. Se o autor deu force-push e o seu
  commit sumiu, **refaça o commit por cima do novo tip**; não tente restaurar a história.
- Depois de mesclar, rode o gate local antes de empurrar:

```bash
bash tests/haxe/run-<especifico-do-PR>.sh
bash /tmp/check.sh  <worktree>    # typecheck Haxe MODDING_LEVEL=0 (windows)
bash /tmp/check2.sh <worktree>    # typecheck Haxe MODDING_LEVEL=2 (o que o CI Android usa)
```

Um typecheck limpo **não** é prova de build: confirme pelo job `Android`/`Windows` da CI.

### 12.4. Ler resultado de CI sem conseguir baixar o log

`gh run view --log` e o endpoint de logs costumam falhar com `EOF` (blob do Azure). O que
funciona:

```bash
gh pr checks <n>                                   # nome + conclusão + duração por job
gh api repos/<owner>/<repo>/actions/jobs/<job_id> -q '.steps[] | "\(.name) -> \(.conclusion)"'
gh api repos/<owner>/<repo>/check-runs/<id>/annotations
```

Os steps dizem **onde** quebrou (`Compile (Android)` vs `Compile (Windows)` vs
`Verify Android APK native libs`), o que já separa problema de Haxe de problema nativo.
Anotações normalmente só trazem `Process completed with exit code 1`.

### 12.5. Falha intermitente vs falha real

Antes de “consertar” um check vermelho, prove que ele é reproduzível:
- Se o mesmo commit passou antes e falhou depois, ou o PR passou e um re-sync falhou no
  mesmo step, trate como **flake**: re-sincronize a `main` (isso dispara run nova) e
  confirme. Não invente correção para um fantasma.
- Se o código relevante ao step **nunca** passou naquela branch, é falha real.
- `gh run rerun <run> --failed` falha com `cannot be rerun; its workflow file may be broken`
  quando a `main` já mudou o workflow — nesse caso só um commit/push novo adianta.

### 12.6. Merge

```bash
gh pr merge <n> --merge      # estratégia configurada; `--squash`/`--rebase` só se pedido
```

- Mergue **só** com conflito resolvido e todos os checks obrigatórios verdes. Reconsulte
  `mergeable` imediatamente antes: cada merge na `main` pode deixar o próximo `DIRTY`.
- **Não** use `--auto`, não use `--admin`, não desative proteção. Se não der para mergear,
  documente o bloqueio exato e siga para outro PR independente.
- Depois de mergear, confirme o resultado e o tip de `main`:

```bash
gh pr view <n> --json state,mergeCommit -q '"\(.state) \(.mergeCommit.oid[0:8])"'
git fetch origin && git log --oneline -1 origin/main
```

### 12.7. Relatório final

Tabela com **uma linha por PR**: número, prioridade, mudanças, conflitos resolvidos, commits
criados, resultado de build/CI e bloqueio restante. Nada de “tudo certo” sem o SHA e o check
verde correspondente.

---

## 13. Armadilhas deste ambiente de agente (fora do repo)

- O clone pode vir **shallow** (`git rev-parse --is-shallow-repository` → `true`). Nesse
  estado `git merge origin/main` falha com `refusing to merge unrelated histories`:
  rode `git fetch --unshallow origin` primeiro.
- O `remote.origin.fetch` costuma ser estreito (só `main` + a branch desta sessão). Branches
  `arena/*` de PR **não** aparecem num `git fetch` normal:
  `git fetch origin 'refs/heads/arena/*:refs/remotes/origin/arena/*' --force`.
- Sem Haxe no sandbox: `bash setup/install-haxe-linux.sh` e depois
  `export PATH="$HOME/.local/bin:$PATH"` (detalhes e limites em `docs/HAXE_LINUX.md`).
  As haxelibs do jogo normalmente **não** vêm instaladas; use `haxelib dev` apontando para
  checkouts locais em vez de `haxelib install` quando a rede para o `lib.haxe.org` estiver
  limitada.
- Sem sudo não há MSVC, e normalmente não há mingw-w64: **build nativo Windows/Linux não é
  reproduzível aqui**. Shims de `windows.h` quebram em `hx/Tls.h`. A evidência de build
  nativo é a CI; localmente use `-fsyntax-only` com stubs (§9.1) + o gate Haxe.
- `haxelib run lime build android` exige `lime setup android`. Responder o setup com valores
  falsos grava `ANDROID_SDK=y`/`ANDROID_NDK_ROOT=n` na config do Lime — inútil e sujo.
  Para typecheck use `lime build android -DMODDING_LEVEL=2 -Dno-compilation`.
- O `EAttributeError` em `source/psychlua/PythonScript.hx` (`Unmatched patterns:
  EAttributeError`) aparece no typecheck local com a revisão de `hython` fora do pin do
  `hmm.json`. **Já existe na `main`** — não é regressão do PR que você está olhando;
  confira rodando o mesmo typecheck num worktree de `main` antes de culpar a branch.
- `tests/haxe/run-*.sh` são 89 arquivos, mas só ~61 são chamados em `checks.yml`. Rodar um
  script que a CI não roda ainda é válido (é o gate do seu PR), mas não conte com ele como
  “coberto pela CI”.

---

## 14. Comandos mais úteis (resumo rápido)

```
haxelib run lime build windows -Dofficial
haxelib run lime test windows
lime test <platform> -clean
setup\windows.bat                    # prepara haxelibs no Windows
setup\windows-msvc-fix.ps1           # fix hxcpp p/ MSVC
haxelib run lime build android -Dofficial   # (CI usa isto p/ mobile)
```
Depois de `setup\windows.bat`, **sempre rode também** `windows-msvc-fix.ps1` no Windows.

---

*Se uma instrução aqui conflitar com um arquivo recém-adicionado, **AGENTS.md permanece a fonte*. 
Documentos citados e verificados: `README.md`, `BUILDING.md`, `CODESTYLE.md`, `project.hxp`,
`hmm.json`, `.github/workflows/*`.
