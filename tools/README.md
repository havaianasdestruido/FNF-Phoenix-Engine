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
```

On Windows PowerShell:

```powershell
.\tools\compress-audio.ps1
.\tools\compress-audio.ps1 -Root assets
.\tools\compress-audio.ps1 -Root assets -Mp3Bitrate 160 -OggBitrate 112
```

`.git` is skipped. Re-encoding is destructive: commit or back up your audio first, then listen to a few tracks before committing the result.

Defaults are 128 kbps MP3 and 96 kbps Ogg Vorbis. Use a higher bitrate for music that has audible artifacts and a lower bitrate only for short sound effects. The existing `art/scripts/compress.ps1` remains available for compatibility; new usage should prefer the scripts in this directory.
