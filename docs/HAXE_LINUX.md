# Haxe no Linux dos agentes — instalação testada

**Objetivo:** disponibilizar Haxe e haxelib em um sandbox Linux sem `sudo`, sem `apt` e sem depender de um PPA. Este guia complementa [AGENTS.md](../AGENTS.md); os requisitos e o build completo do jogo continuam em [BUILDING.md](../BUILDING.md).

O procedimento foi executado **antes de ser documentado**, em **3 de novembro de 2026**, no Debian 12 (bookworm), x86_64, com Git 2.39.5. Não é uma promessa de funcionamento em qualquer distribuição ou sandbox futuro: os limites da validação estão no final.

## 1. Instalar

Na raiz do repositório:

```bash
bash setup/install-haxe-linux.sh
export PATH="$HOME/.local/bin:$PATH"

haxe --version
haxelib version
haxelib config
```

Resultado obtido neste ambiente:

```text
4.3.7
4.1.1
/home/user/haxelib/
```

**Importante para agentes:** faça o `export PATH=...` no início de cada nova chamada de shell que usar Haxe. Shells não interativos/não login podem não ler `.bashrc` ou `.profile`. O instalador também imprime o caminho correto quando necessário.

O script pode ser executado novamente: confere os hashes e a versão do Haxe, reutiliza a instalação existente e recria seus launchers. Ele não sobrescreve comandos `haxe`/`haxelib` preexistentes que não pertençam a esta instalação.

### Onde ficam os arquivos?

| Conteúdo | Local |
| --- | --- |
| Comandos `haxe` e `haxelib` | `~/.local/bin/` |
| Haxe, biblioteca padrão e runtime Neko 2.4.0 | `~/.local/opt/phoenix-haxe/4.3.7/` |
| Repositório haxelib | `~/haxelib/` (ou `HAXELIB_PATH`, se definido) |

A instalação ocupa aproximadamente **59 MB**, fora do Git do projeto. Nenhum diretório de sistema é alterado. O Neko incluído é usado pelo haxelib; não é necessário instalá-lo separadamente.

## 2. Testar com código real do projeto

Estes oito scripts isolam módulos de produção e não precisam das haxelibs do jogo:

```bash
set -e
export PATH="$HOME/.local/bin:$PATH"

for test in \
  run-layout.sh \
  run-platform-support.sh \
  run-platform-util-native.sh \
  run-phoenix-version.sh \
  run-update-checker-typecheck.sh \
  run-charting-timing.sh \
  run-mod-zip.sh \
  run-pool-stats.sh
do
  bash "tests/haxe/$test"
done
```

Resultado da execução com a instalação deste guia:

| Script | Resultado |
| --- | --- |
| `run-layout.sh` | PASS — layout, toque e segurança de scripts |
| `run-platform-support.sh` | PASS — tags de plataforma, filtros de opções e requisitos do `pack.json` |
| `run-platform-util-native.sh` | PASS — type-check nos quatro sistemas |
| `run-phoenix-version.sh` | PASS — versões e seleção de releases |
| `run-update-checker-typecheck.sh` | PASS — type-check Windows/Android |
| `run-charting-timing.sh` | PASS — timing/BPM do chart |
| `run-mod-zip.sh` | PASS — importação, extração e caminhos seguros |
| `run-pool-stats.sh` | PASS — contabilidade do pool |

**Oito scripts, oito códigos de saída 0.** O teste do atualizador não imprime uma mensagem de sucesso; silêncio com saída 0 é o resultado esperado. As mensagens de rejeição de arquivos no teste de ZIP são casos negativos intencionais, não uma falha da suite.

## 3. O que foi validado além dos testes?

- Instalação a partir de um diretório HOME vazio, sem configuração prévia de Haxe.
- Reexecução do instalador sem alterar os launchers nem baixar novamente os binários.
- Haxe **4.3.7**, igual à versão usada pelo [CI](../.github/workflows/main.yml), e haxelib **4.1.1** em um shell novo.
- Compilação e execução de um smoke test em **eval**, **JavaScript + Node.js 22.22.3** e **Neko**.
- `haxelib setup`, `dev`, `run` e `remove` com uma biblioteca local, incluindo subprocessos `haxe`/`haxelib`, sem acessar o registry público.
- Preservação de um `HAXELIB_PATH` explícito e recusa de sobrescrever um comando `haxe` não relacionado.

## Por que não usar apenas `apt install haxe` ou o download oficial?

Neste sandbox, os repositórios de pacotes e os hosts de download usados pelo instalador oficial não estavam acessíveis. O download do GitHub Releases também falhou ao redirecionar para `objects.githubusercontent.com`/`release-assets.githubusercontent.com`.

O instalador usa uma cópia dos binários mantida pelo projeto Ceramic em [ceramic-engine/haxe-binary](https://github.com/ceramic-engine/haxe-binary), baixada por Git com checkout esparso, somente para Linux x86_64. **É um mirror de terceiros, não o canal oficial de distribuição do Haxe.** Por isso, fixa a revisão [`95475451f930551a8cdd65c77fcae07513952903`](https://github.com/ceramic-engine/haxe-binary/tree/95475451f930551a8cdd65c77fcae07513952903) e confere os hashes SHA-256 de `haxe-bin` e `haxelib-bin` antes de instalar. Não baixa um branch móvel nem executa um instalador remoto via pipe.

## Problemas comuns

- **`haxe: command not found` ou versão inesperada:** execute `export PATH="$HOME/.local/bin:$PATH"` e confira `command -v haxe`. Não basta instalar e assumir que todo shell de agente herdará o PATH.
- **Erro de rede no GitHub:** confirme que `github.com` está permitido e execute `git ls-remote https://github.com/ceramic-engine/haxe-binary.git HEAD`. Se o mirror estiver inacessível, a política de rede ou a imagem precisa ser ajustada; este guia não consegue contornar um bloqueio total de saída.
- **`Refusing to overwrite ...`:** já existe um launcher não relacionado. O script para sem substituí-lo. Confira a instalação existente antes de decidir removê-la.
- **`neko: command not found`:** o runtime está incluído, mas não é exposto como comando global. Use `~/.local/opt/phoenix-haxe/4.3.7/neko/neko` para um teste direto; `haxelib run` já configura seu ambiente.
- **Biblioteca do jogo não encontrada:** instalar o compilador não instala Lime, OpenFL, Flixel etc. Siga [BUILDING.md](../BUILDING.md) para as dependências do build completo.

## Limites: o que este guia não afirma

Não foram instaladas as dependências de `hmm.json`, executado um build completo Lime/OpenFL nem aberto o jogo em uma interface gráfica. O acesso ao registry público de haxelib não faz parte da validação. Os testes com `-cpp --no-output` verificam tipos, **não** compilam/linkam um executável nativo do jogo.

ARM64, outras distribuições, outras versões de libc e ambientes sem acesso a GitHub não foram testados; o instalador limita-se a **Linux x86_64**. Use os testes acima como evidência de que o compilador funciona, mas não os apresente como aprovação de um build completo ou de gameplay.
