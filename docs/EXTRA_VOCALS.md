# Extra vocal stems (unlimited vocals per strumline)

Phoenix always loaded two vocal tracks per song — `Voices-Player.ogg` (or the
player character's `vocals_file`) for the player strumline and
`Voices-Opponent.ogg` for the opponent one. Charts can now declare **any
number of additional vocal stems**, each with its own audio file and its own
muting behavior. The design is inspired by Codename Engine's per-strumline
vocals (credit to the Codename Crew for the concept — this is an original
Phoenix implementation of it, not a code port): use it for a third singer, GF
duet parts, choirs, call-and-response layers, etc.

## Declaring stems in a chart

Add an `extraVocals` array to the song's JSON (next to `notes`, `events`, …):

```json
"extraVocals": [
	{ "name": "gf",    "file": "GF",    "side": "none" },
	{ "name": "pico",  "file": "Pico",  "side": "player" },
	{ "name": "choir", "file": "Choir", "side": "opponent" }
]
```

Each entry:

| Field  | Meaning |
| ------ | ------- |
| `file` | Postfix of the audio file in the song folder: `file: "GF"` loads `Voices-GF.ogg`. Difficulty variants (`Voices-GF-hard.ogg`) are tried first, exactly like the player/opponent stems. An empty/missing `file` resolves the shared `Voices.ogg`. |
| `name` | Identifier used by scripts (e.g. `setExtraVocalVolume('gf', 0.5)`). Defaults to `file`. Keep names unique — lookups resolve the first match. |
| `side` | Which strumline's muting the stem follows: `"player"`, `"opponent"` or `"none"` (default). |

Side behavior:

- **`player`** — the stem mutes when the player misses a note and unmutes on
  the next hit, mirroring the main player stem (opponent-chart mode swaps the
  roles, same as the built-in stems).
- **`opponent`** — follows the opponent stem: never muted by player misses,
  restored when the CPU side sings.
- **`none`** — never auto-muted; the stem always plays unless a script turns
  it down. This is the right choice for GF-style third voices and ambient
  layers.

The parser is deliberately forgiving for hand-edited and ported charts:

- a bare string is shorthand for a `none`-side stem: `"extraVocals": ["GF"]`
- Codename Engine wording works too: `vocalsSuffix` (a leading `-` is
  stripped, so `"-bf"` → `Voices-bf.ogg`), `strumline` for `side`, and the
  numeric strumline `type` (`0` = opponent, `1` = player, anything else =
  `none`)
- unusable entries are skipped, never fatal.

The chart editor round-trips the field untouched, and plays the stems back in
the Chart Editor and in the editor playtest. In the editor, stems follow the
vocal volume slider and mute checkbox of their side; `none` stems follow the
main vocal slider.

## Player option

The feature is **on by default** and can be turned off under
Options → Gameplay Settings → **Extra Vocal Stems**. When off, extra stems are
not loaded at all, which saves the memory of the additional audio on low-end
devices. Charts that declare no `extraVocals` are completely unaffected either
way.

## Scripting (Lua, Python and HScript)

Stems are addressed by their chart `name`:

```lua
function onSongStart()
	local names = getExtraVocalNames() -- {"gf", "pico", "choir"}
	setExtraVocalVolume('gf', 0.8)
end

function onBeatHit()
	-- duck the choir on every 4th beat, restore otherwise
	if curBeat % 4 == 0 then setExtraVocalVolume('choir', 0.2)
	else setExtraVocalVolume('choir', 1) end
end
```

| Function | Returns | Notes |
| -------- | ------- | ----- |
| `getExtraVocalNames()` | array of names | chart order; empty when none |
| `setExtraVocalVolume(name, value)` | `true` if the stem exists | |
| `getExtraVocalVolume(name)` | volume, `0` when missing | |
| `setExtraVocalPitch(name, value)` | `true` if the stem exists | needs pitch-capable targets (`FLX_PITCH`) |
| `getExtraVocalPitch(name)` | pitch, `1` when missing | |

HScript mods can also reach the tracks directly:
`PlayState.instance.extraVocals` is an array of `ExtraVocalTrack` with
`name`, `file`, `side` and the `sound: FlxSound` itself.

## Behavior notes

- Stems start, pause, resume, seek, resync and change pitch together with the
  instrumental (countdown skips, pause menu, resume countdown, song-speed
  changes, game over and song end included).
- The **Vocal Volume Override** gameplay setting applies to extra stems too;
  a stem currently muted by a miss stays muted until its side sings again.
- Missing stem files are logged and skipped — the song still plays.
- Game Renderer (`ffmpeg`) mode keeps the stems silent, like the mains.
- `Paths.voices()` resolves postfixed stems on web builds too
  (`Voices-<file>[-<difficulty>]`), with the same null-fallback chain as
  native targets.

Implementation: `source/data/ExtraVocals.hx` (chart parsing),
`source/play/helpers/PlayStateExtraVocals.hx` (loading + playback),
spec: `bash tests/haxe/run-extra-vocals.sh`.
