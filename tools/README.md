# Audio compression tools

These scripts re-encode project audio at conservative, game-friendly bitrates and replace a source file **only when the encoded file is smaller**. They preserve the original file format, audio metadata where supported, and timestamps. Re-encoding is lossy, so review the result before committing; keep backups if the source files are important.

Both scripts require [FFmpeg](https://ffmpeg.org/) in `PATH`.

```sh
# From the repository root (all MP3/OGG files below the repo)
./tools/compress-audio.sh --root assets
./tools/compress-audio.sh --root assets --mp3-bitrate 160 --ogg-bitrate 112
```

On Windows PowerShell:

```powershell
.\tools\compress-audio.ps1 -Root assets
.\tools\compress-audio.ps1 -Root assets -Mp3Bitrate 160 -OggBitrate 112
```

Defaults are 128 kbps MP3 and 96 kbps Ogg Vorbis. Use a higher bitrate for music that has audible artifacts and a lower bitrate only for short sound effects. The existing `art/scripts/compress.ps1` remains available for compatibility; new usage should prefer the scripts in this directory.
