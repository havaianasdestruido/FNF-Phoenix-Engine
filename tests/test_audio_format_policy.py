#!/usr/bin/env python3
"""Regression tests for the "one copy per track" audio policy.

The engine used to ship every sound twice -- an OGG for native builds and an
MP3 for web/Flash -- because `Paths.SOUND_EXT` was a compile-time constant and
`project.hxp` excluded the "wrong" format from each platform. That doubles the
repository size, makes every audio fix a two-file job, and lets the two copies
drift apart (the vocals were MP3-only, so native builds silently lost them).

The policy now is:

* Ogg Vorbis is the container (`Paths.SOUND_EXT`), because it decodes/seeks
  faster than MP3 at the same bitrate -- the important property for a rhythm
  game. Only Flash/AIR falls back to MP3, since SWF cannot decode Vorbis.
* `Paths.SOUND_EXTENSIONS` is resolved at runtime (`.ogg` then `.mp3`) by
  `Paths.modsSounds()`, `Paths.resolveSoundAsset()`, `Paths.returnSound()` and
  the song helpers, so *mods* may still ship MP3 while the repository itself
  never keeps both formats of the same audio.

Run:  python3 -m unittest discover -s tests -p 'test_*.py' -v
"""
from __future__ import annotations

import unittest
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

AUDIO_EXTENSIONS = {".ogg", ".mp3"}
AUDIO_ROOTS = ("assets", "mods", "example_mods")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


def audio_files():
    """(path, extension) for every audio file the repository would ship."""
    for folder in AUDIO_ROOTS:
        base = ROOT / folder
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS:
                yield path, path.suffix.lower()


class DuplicateAudioTests(unittest.TestCase):
    def test_no_track_ships_as_both_ogg_and_mp3(self):
        stems = defaultdict(set)
        for path, ext in audio_files():
            stems[path.parent / path.stem].add(ext)

        duplicates = sorted(str(stem.relative_to(ROOT)) for stem, exts in stems.items() if len(exts) > 1)
        self.assertEqual(
            [],
            duplicates,
            "these tracks ship twice (keep the .ogg and delete the .mp3):\n" + "\n".join(duplicates),
        )

    def test_repository_ships_no_mp3(self):
        # Ogg is the engine's container; an MP3 here would be a stray duplicate
        # or a freshly-added file that nobody converted.
        stray = sorted(str(path.relative_to(ROOT)) for path, ext in audio_files() if ext == ".mp3")
        self.assertEqual([], stray, "convert these to .ogg (ffmpeg -c:a libvorbis -q:a 2):\n" + "\n".join(stray))


class OggContainerTests(unittest.TestCase):
    def test_every_ogg_starts_with_the_ogg_magic(self):
        # Paths.returnSound() rejects a mislabelled container for mod files, and
        # the OpenFL decoders assume a real Ogg page header.
        offenders = []
        for path, ext in audio_files():
            if ext != ".ogg":
                continue
            with path.open("rb") as handle:
                if handle.read(4) != b"OggS":
                    offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual([], offenders, "not Ogg containers: " + ", ".join(offenders))

    def test_web_targets_keep_ogg_in_the_asset_libraries(self):
        project = read("project.hxp")
        # Excluding *.ogg from web builds would ship silent audio now that the
        # engine no longer keeps an MP3 copy of every track.
        self.assertIn('EXCLUDE_ASSETS_WEB:Array<String> = [];', project)
        self.assertNotIn('EXCLUDE_ASSETS_WEB:Array<String> = ["*.ogg"]', project)
        # Native builds still skip MP3s: built-in content is Ogg and mods are
        # read straight off disk.
        self.assertIn('EXCLUDE_ASSETS_NATIVE:Array<String> = ["*.mp3"];', project)


class SoundResolutionTests(unittest.TestCase):
    def test_preferred_container_is_ogg(self):
        paths = read("source/backend/Paths.hx")
        self.assertIn('SOUND_EXT = #if flash "mp3" #else "ogg" #end;', paths)
        self.assertIn('SOUND_EXTENSIONS:Array<String> = #if flash ["mp3", "ogg"] #else ["ogg", "mp3"] #end;', paths)

    def test_mods_sounds_walks_every_accepted_container(self):
        paths = read("source/backend/Paths.hx")
        helper = paths[paths.index("static public function modsSounds(") :]
        helper = helper[: helper.index("public static function playModMusic(")]
        self.assertIn("for (ext in SOUND_EXTENSIONS)", helper)
        self.assertIn("if (FileSystem.exists(candidate)) return candidate;", helper)
        self.assertIn("return null", helper)

    def test_library_sounds_walk_every_accepted_container(self):
        paths = read("source/backend/Paths.hx")
        helper = paths[paths.index("public static function resolveSoundAsset(") :]
        helper = helper[: helper.index("public static var currentTrackedSounds")]
        self.assertIn("for (ext in SOUND_EXTENSIONS)", helper)
        self.assertIn("if (OpenFlAssets.exists(assetId, SOUND)) return assetId;", helper)

    def test_ogg_header_check_only_applies_to_ogg_files(self):
        paths = read("source/backend/Paths.hx")
        # An MP3 is a perfectly valid modded sound now, so the OggS magic check
        # must be gated on the extension instead of running on every file.
        self.assertIn("inline static function isOggFile(file:String):Bool", paths)
        self.assertIn("if (isOggFile(file))", paths)
        self.assertNotIn('if (header.toString() != "OggS" && file != null)', paths)

    def test_inst_and_voices_use_the_resolver(self):
        paths = read("source/backend/Paths.hx")
        self.assertIn("return songAudioAsset(formatToSongPath(song), 'Inst');", paths)
        self.assertIn("return songAudioAsset(formatToSongPath(song), 'Voices');", paths)
        self.assertIn("if (songKeyExists(songKey)) return returnSound('songs', songKey);", paths)


class BuiltinSongAudioTests(unittest.TestCase):
    def test_every_builtin_song_has_an_ogg_instrumental(self):
        songs = ROOT / "assets" / "songs"
        missing = sorted(
            song.name for song in songs.iterdir() if song.is_dir() and not (song / "Inst.ogg").is_file()
        )
        self.assertEqual([], missing, "built-in songs without Inst.ogg: " + ", ".join(missing))


if __name__ == "__main__":
    unittest.main(verbosity=2)
