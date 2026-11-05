---
title: Audio & music
sidebar_position: 7
description: Song audio, the freeplay music player, the sound tray, hitsounds and video playback.
---

# Audio & music

## Formats

**Ogg Vorbis is the audio container.** `Paths.SOUND_EXT` is `ogg` on every target except
Flash/AIR, whose SWF backend cannot decode Vorbis and therefore falls back to `mp3`.
Vorbis decodes faster, seeks more precisely and is smaller than MP3 at a comparable
quality, which matters when a chart has to stay locked to the instrumental.

Each track exists **once**. There is no `.ogg` + `.mp3` pair anywhere in `assets/`:
`Paths.SOUND_EXTENSIONS` (`["ogg", "mp3"]`, reversed on Flash) is the list of formats the
engine will accept, and sound lookups use the first file that actually exists — so a mod
can ship either container while the repository stays Ogg-only. Audio assets were
re-encoded for roughly 50 % size reduction without a quality change that matters at game
volume.

| Kind | Path |
|---|---|
| Instrumental | `songs/<song>/Inst.ogg` |
| Vocals | `songs/<song>/Voices.ogg` (loaded only when `needsVoices`) |
| Music | `music/<key>.ogg` |
| SFX | `sounds/<key>.ogg` |

`Paths.inst(song, difficulty)` and `Paths.voices(song, difficulty, postfix)` handle
difficulty-specific and postfixed variants (used by per-character vocal tracks via the
character JSON's `vocals_file`). Both go through the extension resolver, so a
`Voices-Player.mp3` in a mod folder still loads.

:::note[Browser support]

HTML5 plays Ogg Vorbis in Chrome, Edge and Firefox. Safari's Web Audio backend has no
Vorbis decoder, so a Safari-facing distribution would have to ship MP3s; nothing in the
code needs to change for that, because `Paths.modsSounds()` and
`Paths.resolveSoundAsset()` already fall back to `.mp3` when it is what the build has.

:::

## Playback during a song

`play.helpers.PlayStatePlayback` owns the song audio:

- starts instrumental and vocals together and keeps them in sync,
- resyncs when they drift (a dropped frame or a long GC pause),
- applies `playbackRate` to both audio and the conductor,
- handles pause/resume, including the vocals,
- stops everything cleanly on game over and at the end of the song.

`Conductor.songPosition` is driven from the instrumental's time, not from `elapsed`, so
rendering hitches cannot desync the chart.

### Global stem volume overrides

Two opt-in settings in **Options → Gameplay Settings** pin a stem's volume for *every* song:

| Option | `ClientPrefs` fields |
|---|---|
| Override Instrumental Volume | `overrideInstrumentalVolume`, `instrumentalVolumeOverride` |
| Override Vocal Volume | `overrideVocalsVolume`, `vocalsVolumeOverride` |

`PlayStatePlayback.instrumentalVolume()` and `PlayStatePlayback.vocalsVolume()` resolve the
volume a stem should play at — the override while its toggle is on, full volume otherwise —
and `PlayStatePlayback.enforceStemVolumes()` re-applies both every frame while the chart
plays (`PlayState.update`, guarded so pause, cutscenes, the ending sequence and renderer mode
are left alone). Stages, events and scripts therefore cannot drift away from the chosen
value; `setSoundVolume('')` and `setProperty('FlxG.sound.music.volume', …)` are reverted on
the next frame. That is the point of an override, but modders should know it exists.

Four things the override deliberately does **not** touch:

- **Miss-muting still wins.** Missing a note mutes the vocal stems to 0, and the next hit
  restores them to the override value instead of a hardcoded full volume.
- **Game Renderer mode** (`ffmpegMode`) keeps the stems silent because it captures audio
  separately; that always beats the override.
- **The chart editor** keeps its own instrumental/vocal sliders and mute checkboxes —
  `ChartingState` and `EditorPlayState` never read the override.
- **The freeplay preview** keeps its own quieter levels (`music.MusicPlayer`,
  `FreeplayStateHelpers.playSong`); the override applies to songs you actually play.

:::note[Pitch on SWF targets]

Flash and AIR have no pitch shifting. A [haxelib patch](../architecture/haxelib-patches.md)
gives `FlxSound` a store-only `pitch` property so the code compiles there, and
`#if FLX_PITCH` guards the places where real pitch shifting is required.

:::

## Menu music

`Paths.playMenuMusic(force, volume)` plays the menu theme, and
`Paths.playModMusic(file, fallback, volume)` lets a mod replace it: it tries
`mods/<mod>/music/<file>.ogg` (or `.mp3`), then the legacy name, then the base theme,
then the default. This is what makes "modified `freakyMenu` names" work — a mod can ship its own
menu track without renaming engine assets. `ClientPrefs.daMenuMusic` and
`ClientPrefs.pauseMusic` choose between shipped variants.

## The freeplay music player

`music.MusicPlayer` is the overlay in `states.FreeplayState` that lets you listen to songs
from the song list: play/pause (`pauseOrResume`), seek, track time (`curTime`) and
`switchPlayMusic()` to toggle between browsing and listening. It owns Freeplay previews
separately from gameplay. The Android Media3 session is currently attached by
`PlayStateAndroidMedia` once a chart enters `PlayState`, so chart playback—not a Freeplay
preview—is exposed to system media controls, the lock screen, Bluetooth devices and
Android Auto.

## Sound tray

`objects.CustomSoundTray` replaces Flixel's volume overlay with the engine's styled
version (`CustomSoundFrontEnd` extends Flixel's `SoundFrontEnd`). Volume and mute keys
come from `ClientPrefs.keyBinds` and are pushed into `TitleState.muteKeys`,
`volumeUpKeys` and `volumeDownKeys` on load. The tray is disabled on Flash/AIR via
`FLX_NO_SOUND_TRAY`.

## Hitsounds and feedback

`ClientPrefs.hitsoundVolume` and `hitsoundType` (e.g. `osu!mania`) drive the per-note
click; `missSoundEnabled` plays the classic miss sound. Both are played through
`FlxG.sound.play(Paths.sound(...))` with the sound preloaded by the playstate so the first
hit does not stutter.

## Video

Video playback uses **hxvlc** behind `VIDEOS_ALLOWED` (desktop and mobile C++ targets
only). `play.CutsceneHandler` sequences cutscenes, and Lua's `startVideo(name)` plays one
from a script. On Linux this is why libvlc is a build requirement; the old `hxCodec`
instructions in `BUILDING.md` no longer apply.

## Spectrum analysis

`stages.objects.ABotSpeaker` visualises the instrumental through `funkin.vis`
(`SpectralAnalyzer`) and `grig.audio`. Both are forks, and the analyzer needed a
[patch](../architecture/haxelib-patches.md) so Flash/AIR builds compile without a
Web-Audio or Lime `AudioSource` backend.
