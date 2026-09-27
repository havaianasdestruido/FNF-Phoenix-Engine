# Compression tools

Scripts that shrink the assets committed in this repository. Replacements only
happen when the compressed file is **smaller** than the source, original
timestamps are preserved, and `--dry-run` / `-DryRun` reports the projected
saving without touching anything. `.git` is skipped. Compression is lossy in
places, so review the result before committing; keep backups if the source
files are important.

With no arguments both tools scan the **repository root** (the folder
containing `tools/`), so they can be run from any directory.

## Audio (`compress-audio.sh` / `compress-audio.ps1`)

Re-encodes project audio at conservative, game-friendly bitrates and replaces a
source file **only when the encoded file is smaller**. They preserve the
original file format and audio metadata where supported.

Requires [FFmpeg](https://ffmpeg.org/) in `PATH`.

```sh
# All MP3/OGG files in the repository
./tools/compress-audio.sh
# Only the ones below assets
./tools/compress-audio.sh --root assets
./tools/compress-audio.sh --root assets --mp3-bitrate 160 --ogg-bitrate 112
# Measure first: encode everything, report the savings, change nothing
./tools/compress-audio.sh --root assets --dry-run
```

On Windows PowerShell:

```powershell
.\tools\compress-audio.ps1
.\tools\compress-audio.ps1 -Root assets
.\tools\compress-audio.ps1 -Root assets -Mp3Bitrate 160 -OggBitrate 112
.\tools\compress-audio.ps1 -Root assets -DryRun
```

Re-encoding is destructive: commit or back up your audio first, then listen to a
few tracks before committing the result.

`--dry-run` / `-DryRun` is the safe way to start: it encodes each file to a
temporary copy, reports the size it would reach and the total projected saving,
and deletes the copy without touching your audio. A file is replaced only when
the encoded output is smaller than the source; output that is the same size or
larger is reported as skipped, which is normal for audio that is already tightly
encoded.

Defaults are 128 kbps MP3 and 96 kbps Ogg Vorbis. Use a higher bitrate for music
that has audible artifacts and a lower bitrate only for short sound effects. The
existing `art/scripts/compress.ps1` remains available for compatibility; new
usage should prefer the scripts in this directory.

## Images (`compress-images.sh` / `compress-images.ps1`)

Re-compresses PNG and JPEG images in place, replacing a source file **only when
the result is smaller**. The pipeline is:

1. **PNG, lossy (skippable with `--lossless` / `-Lossless`)**: high-quality
   palette quantization with [pngquant](https://pngquant.org/), capped at
   `--colors` (default 256) and guarded by a `--quality` window (default
   `85-95` - files whose measured quality would fall below the floor are left
   untouched). This is where most of the saving comes from; flat game art is
   visually indistinguishable afterwards.
2. **PNG, lossless**: re-optimizes the deflate stream and strips metadata with
   the first available tool: [oxipng](https://github.com/oxipng/oxipng),
   `optipng`, `zopflipng`, `pngcrush` or ImageMagick.
3. **JPEG**: re-encodes at `--jpeg-quality` (default 85, adaptive with
   `jpegoptim --max`, fixed quality with ImageMagick), stripping metadata.

Files are identified by **content**, not by extension - a JPEG named `.png` is
still processed as JPEG, which matters because this repository contains a few
such files. WebP/GIF/BMP files (including WebP data stored under a `.png` name)
are reported and left untouched. Animated PNGs are never quantized. Pixel
dimensions never change, so Sparrow/XML atlas frame coordinates stay valid.

```sh
# All images in the repository
./tools/compress-images.sh
# Only the ones below assets
./tools/compress-images.sh --root assets
# Measure first: compress everything to temp copies, change nothing
./tools/compress-images.sh --root assets --dry-run
# Lossless pass only (no palette quantization)
./tools/compress-images.sh --root assets --lossless
# More aggressive: 128-color palettes, still guarded by the quality floor
./tools/compress-images.sh --root assets --colors 128
```

On Windows PowerShell:

```powershell
.\tools\compress-images.ps1
.\tools\compress-images.ps1 -Root assets
.\tools\compress-images.ps1 -Root assets -DryRun
.\tools\compress-images.ps1 -Root assets -Lossless
.\tools\compress-images.ps1 -Root assets -Colors 128
```

At least one PNG tool and one JPEG tool must be installed; the more of them are
present, the smaller the result. `pngquant` plus `oxipng` is the recommended
pair. Without `pngquant` the scripts still run, but only apply the lossless
step. On Windows, install tools via e.g. `winget install ImageMagick.ImageMagick`
or `choco install pngquant oxipng jpegoptim`.

The quantization step is lossy: run `--dry-run` / `-DryRun` first if you are
unsure, spot-check a few spritesheets in-game, and use `--lossless` /
`-Lossless` for assets that must stay bit-exact.
