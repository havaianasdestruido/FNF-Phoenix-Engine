# Adaptive performance

**Options → Optimization → Adaptive Performance** is off by default. When it
is enabled, the engine watches the actual draw rate during a song, even if the
FPS display is hidden or the song is playing at a different speed. The measured
FPS is rounded to a whole number for each one-second window. If three consecutive
windows are below the current draw target, it takes one step and shows a notice:

1. Disable player and opponent note splashes, including sustain splashes.
2. Disable rating popups (including simple and Early/Late ratings).
3. Disable built-in camera bops and the **Add Camera Zoom** event.

Each further step needs another three low-FPS windows. Whole-FPS rounding avoids
reacting to tiny pacing differences such as 59.94 versus 60 Hz; a single hitch
does not count as three low windows. Effects that are already off are skipped.
Combo-number sprites and the MS display retain their own settings. In Simple
Popups mode, rating and combo share one text label, so that combined label is
hidden. Scoring, notes, input, timing and stage framing are not changed.
Intentional camera changes made directly by a mod script or a chart's
**Set/Tween Camera Zoom** event are not intercepted.

Overrides belong to the current play only. Retrying or starting the next song
starts from the player's normal settings, including any active Memory Profile;
adaptive performance never edits or saves the splash, rating or zoom options.
It is separate from the planned first-run profile, which chooses initial
settings rather than reacting during play. Sampling stops and the partial streak
is discarded during countdowns, pauses, focus loss, cutscenes, game over,
transitions and offline video rendering.

The first sustained slowdown also requests an explicit garbage collection, and
persistent slowdowns can request another at most once every 15 seconds, even
when all three cosmetic options were already off. This is a one-off request:
it does not enable automatic GC or change the **Enable GC** preference, and it
may itself cause a brief hitch. GC can reclaim only unreachable managed
objects; live song assets are not forcibly unloaded and memory reduction is not
guaranteed. Browser builds cannot explicitly request GC; Flash/AIR may only
honour it in a debug player. The notice says a cleanup was requested only when
the GC call did not throw; it cannot confirm that memory was reclaimed.

The target is the actual game draw-framerate setting. A target higher than the
display or device can sustain may therefore cause reductions even if the game
looks smooth; lower the target or turn the option off if that is undesirable.

## Verification

Run the deterministic policy and PlayState adapter tests with
`bash tests/haxe/run-adaptive-performance.sh`. The optional
`bash tests/haxe/run-adaptive-performance-typecheck.sh` also checks the adapter
against installed Flixel/OpenFL/Lime sources. If a Neko executable is available,
it runs the adapter with game/Flixel doubles and OpenFL's real Neko GC implementation.
For the equivalent hxcpp runtime check with automatic GC disabled, use
`ADAPTIVE_HXCPP_SMOKE=1 bash tests/haxe/run-adaptive-performance-typecheck.sh`;
this also requires an installed hxcpp toolchain and can take several minutes.

For a manual check, enable the option and all three cosmetics, set Graphics →
Framerate higher than the device can draw, and play a song. The three notices
should appear in order while FPS remains low. Pausing or losing focus should
restart the measurement without restoring any effects already disabled; a retry
should restore them. Restore your preferred framerate after the check.
