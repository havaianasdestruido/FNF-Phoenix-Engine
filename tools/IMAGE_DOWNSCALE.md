# Auditoria de redução 2x de imagens grandes

Script: `tools/image_downscale_audit.py`. Manifesto: `tools/reports/image-downscale-manifest.json`.
Testes: `tests/test_image_downscale_audit.py`.

## Política

Uma imagem > 200 KB só é reduzida se **todas** as condições forem verdadeiras:

1. Largura e altura pares (metade exata, sem arredondamento).
2. Todas as coordenadas do atlas pares. O engine lê `x`, `y`, `width`, `height`,
   `frameX`, `frameY`, `frameWidth` e `frameHeight` como inteiros (Sparrow), então
   metade de um pixel não é representável sem reamostrar ou arredondar.
3. Recurso de jogo (não documentação, fotografia ou GIF).

Quando a condição 2 é violada, o atlas inteiro é excluído: não existe redução
exata do XML.

## Resultado atual

Execute `python3 tools/image_downscale_audit.py` para regenerar o manifesto.
Nenhum asset foi alterado nesta auditoria. Os totais estão no campo `summary`
do manifesto, calculados a partir dos arquivos do repositório.

## Limitações

- A validação visual (tamanho dos personagens em tela) depende de executar o
  jogo, o que não foi feito aqui.
- Para reduzir os atlas no futuro, é preciso reexportá-los com coordenadas
  pares ou alterar a escala de renderização dos consumidores, decisões que
  dependem de revisão de conteúdo.
