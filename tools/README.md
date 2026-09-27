# Audio compression tools

These scripts re-encode project audio at conservative, game-friendly bitrates and replace a source file **only when the encoded file is smaller**. They preserve the original file format and audio metadata where supported. Re-encoding is lossy, so review the result before committing; keep backups if the source files are important.

Both scripts require [FFmpeg](https://ffmpeg.org/) in `PATH`.

With no arguments they scan the **repository root** (the folder containing `tools/`), so they can be run from any directory. Pass `--root` / `-Root` to narrow the scan, e.g. to `assets` only:

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

`.git` is skipped. Re-encoding is destructive: commit or back up your audio first, then listen to a few tracks before committing the result.

`--dry-run` / `-DryRun` is the safe way to start: it encodes each file to a temporary copy, reports the size it would reach and the total projected saving, and deletes the copy without touching your audio. Files already encoded at or below the target bitrate are reported as skipped, which is normal — a track that is already 96 kbps cannot get smaller without quality loss.

Defaults are 128 kbps MP3 and 96 kbps Ogg Vorbis. Use a higher bitrate for music that has audible artifacts and a lower bitrate only for short sound effects. The existing `art/scripts/compress.ps1` remains available for compatibility; new usage should prefer the scripts in this directory.
