# Otimização de imagens grandes (> 200 KiB)

Ferramenta: `tools/optimize_images.py` (Python 3 da biblioteca padrão + ImageMagick
`convert`/`identify`). É uma ferramenta de manutenção: **não é necessária para rodar o jogo**.
Relatório: `tools/reports/image-optimization-report.json`. Testes: `tests/test_optimize_images.py`.

```sh
python3 tools/optimize_images.py            # aplica as mudanças
python3 tools/optimize_images.py --dry-run  # processa em diretório temporário
python3 tools/optimize_images.py --check    # valida o relatório contra os arquivos
```

## Elegibilidade

Um arquivo raster rastreado pelo Git entra na lista se **o tamanho no commit base
`5ca9689` for maior que 204.800 bytes**. Usar o commit base evita que uma imagem
reduzida saia da lista na reexecução.

## Dois caminhos

### 1. Redução 2x com compensação de escala (imagens avulsas)

Aplicada a imagens sem atlas, com consumidor de código conhecido (`REDUZIR_2X`):

1. Se a largura ou a altura for ímpar, replica-se a última coluna/linha (no máximo 1 px)
   até o tamanho par. Nenhum pixel original muda.
2. Reduz-se exatamente pela metade com Lanczos, em RGBA (o alfa é ponderado pelo ImageMagick).
3. Grava-se PNG indexado de 256 cores **somente se** o PSNR da cor pré-multiplicada pelo
   alfa, medido contra a versão RGBA, for >= 35 dB. Caso contrário grava-se RGBA sem perdas.
4. O consumidor precisa conter o marcador `OTIMIZACAO_2X` e a escala compensatória.
   Sem o marcador o arquivo não é tocado e a falha é registrada.

Compensação nos stages (o tamanho e a posição na tela ficam iguais):

| Asset | Textura antes -> depois | Consumidor | Compensação |
|---|---|---|---|
| `christmas/evilBG` | 2625x1613 -> 1313x807 | `stages/MallEvil.hx` | `setGraphicSize(2100)`, offset `(262.5, 161.3)` |
| `christmas/bgWalls` | 3767x1775 -> 1884x888 | `stages/Mall.hx` | `setGraphicSize(3013)`, offset `(377, 177.64)` |
| `limo/limoSunset` | 1968x1313 -> 984x657 | `stages/Limo.hx` | `scale = 2`, `updateHitbox()`, offset `(0, 0)` |

Os offsets são fixados explicitamente porque `updateHitbox()` calcula o offset a partir
de `frameWidth`/`frameHeight`, que agora são menores. Sem essa correção, o fundo se deslocaria.

### 2. Atlas Sparrow / JSON (sem redução geométrica)

Atlas com coordenadas ímpares (quase todos) não podem ser reduzidos 2x sem arredondar
frames, o que é proibido. Por isso a geometria, os XMLs e os JSONs **não são alterados**.
A recodificação sem perdas (`--recodificar-atlas`) só grava se os pixels decodificados
forem idênticos e o arquivo ficar menor. Medições feitas nesta PR:

- PNG8 do ImageMagick reduziu o `smokeRight.png` de 249 KB para 119 KB, mas **altera o
  alfa** de pixels visíveis (ex.: alfa 19 vira 0). Por isso a candidata foi removida.
- Recodificação zlib nível 9 dos mesmos dados filtrados deu 281 KB contra 249 KB do
  original, ou seja, o PNG original já está mais bem comprimido.

Conclusão medida: não há ganho sem perdas nesses atlas com as ferramentas disponíveis.

## Fora do escopo

- `.github/res/deeplink.gif`: GIF de documentação do GitHub.
- `assets/shared/images/caseys.jpg`: fotografia não referenciada por nenhum código ou metadado.

## Limitações

- Compilação Haxe e teste no jogo **não executados** (dependências em lib.haxe.org e
  forks no GitHub; sem ambiente de exibição). A compensação foi verificada lendo o
  código do fork do Flixel (`setGraphicSize`, `updateHitbox`, `drawComplex`).
- A redução com paleta de 256 cores é uma perda controlada. Erro médio pequeno, mas
  alguns pixels de borda semitransparente mudam o alfa em até 127–163 níveis. Ver os
  valores por arquivo no relatório (`validacao`).
- Atlas com coordenadas ímpares continuam com o tamanho original.
