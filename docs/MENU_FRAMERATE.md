# Menu framerate

`ClientPrefs.framerate` — the gameplay rate — used to be applied once, globally, from
Options → Graphics. Menus, editors, the pause screen and the title flow therefore all
rendered at the gameplay framerate, which can be raised to 1000 (10000 with **Uncapped
FPS**) just to keep gameplay smooth. Battery and fans paid for frames nobody asked for.

Two new preferences fix that:

| Preference | Options → Graphics row | Default | Applied by |
|---|---|---|---|
| `menuFramerate` | **Menu Framerate** (int, `1..1000`, or `1..10000` with Uncapped FPS) | `60` | `backend.FramerateController.applyForState`, called from `backend.MusicBeatState.create()` and `states.RecoveryState.create()` |
| `focusLostFramerate` | **Focus Lost Framerate** (same band) | `60` | `backend.FramerateController.applyFocusLost`, called from `states.InitState` and `backend.SettingsBackup.applyImmediately` |

`play.PlayState` is the one state that keeps `ClientPrefs.framerate`; every other
`MusicBeatState` — menus, editors, pause flow — runs at `menuFramerate`. Both rows apply
immediately on change, are clamped through `backend.FramerateMath.clamp` on load (a
hand-edited save cannot exceed the band) and are part of the save/load reflect lists.

The focus-lost rate used to be hard-coded in `states/InitState.hx`
(`FlxG.game.focusLostFramerate = 60`); it is now the saved `focusLostFramerate`
preference. It governs the rate the window runs at when the OS reports the app is not
focused.

Frame pacing for gameplay itself (refresh-rate detection, recommended 60/90/120/144,
separate update rate) is tracked in TODO.md §18.

Spec: `bash tests/haxe/run-menu-framerate.sh` (runs in `checks.yml`).
