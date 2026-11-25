#!/usr/bin/env bash
# Converts every .ogg under assets/ to a sibling .mp3 (Layer III, CBR).
# lime's Flash embedder (lime/tools/FlashHelper.hx) refuses to embed .ogg as
# a flash Sound, but automatically substitutes a same-basename .mp3/.wav
# sibling when one exists next to the .ogg. Run this before `lime build flash`
# so songs and sound effects actually play inside the SWF.
#
# Usage: setup/convert-audio-for-flash.sh [assets-root]
#
# The generated .mp3 files are build artefacts, not source: every one of them
# has an .ogg sibling that stays the file of record, and `project.hxp` excludes
# `*.mp3` from native builds (native prefers Vorbis). They are therefore NOT
# committed - run this script before the first `lime build flash`, or let CI
# run it, and regenerate them with `FORCE=1` after re-encoding the oggs.
set -euo pipefail

ROOT="${1:-assets}"

# Flash needs every sound as an embedded flash Sound, and the whole
# self-contained SWF is assembled in one neko BytesBuffer with a hard
# 268435456-byte (256 MB) ceiling (neko max_string_size). At 128 kbps the
# full asset set exceeds that, so the mp3s are encoded at 64 kbps stereo:
# the whole library then fits with room to spare. Set BITRATE to override.
BITRATE="${BITRATE:-64k}"

# Prefer a system ffmpeg; fall back to the one bundled by the
# imageio-ffmpeg pip package (e.g. in /home/user/ffmpeg-venv).
FFMPEG="$(command -v ffmpeg || true)"
if [ -z "$FFMPEG" ]; then
  FFMPEG="$(/home/user/ffmpeg-venv/bin/python3 - <<'EOF' 2>/dev/null || true
try:
    import imageio_ffmpeg
    print(imageio_ffmpeg.get_ffmpeg_exe())
except Exception:
    pass
EOF
)"
fi
if [ -z "$FFMPEG" ]; then
  FFMPEG="$(python3 - <<'EOF' 2>/dev/null || true
try:
    import imageio_ffmpeg
    print(imageio_ffmpeg.get_ffmpeg_exe())
except Exception:
    pass
EOF
)"
fi
if [ -z "$FFMPEG" ]; then
  echo "ffmpeg not found. Install ffmpeg or \`pip install imageio-ffmpeg\`." >&2
  exit 1
fi

echo "Using ffmpeg: $FFMPEG"

find "$ROOT" -name '*.ogg' -print0 |
while IFS= read -r -d '' ogg; do
  mp3="${ogg%.ogg}.mp3"
  if [ -f "$mp3" ] && [ "${FORCE:-0}" != "1" ]; then
    continue
  fi
  echo "converting: $ogg"
  "$FFMPEG" -nostdin -hide_banner -loglevel error -y -i "$ogg" -codec:a libmp3lame -b:a "$BITRATE" -ar 44100 "$mp3"
done

echo "Done. $(find "$ROOT" -name '*.mp3' | wc -l) mp3 files present under $ROOT."
