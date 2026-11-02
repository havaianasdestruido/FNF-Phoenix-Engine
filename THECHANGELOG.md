0.3.2;

Phoenix Engine 0.3.2 (current release; version defined by VERSION in project.hxp).
The update checker polls this file in this repository and compares its first
entry with the running Phoenix version, so keep the first entry equal to
VERSION whenever a release is cut. Entries below this one pre-date the fork
and describe the upstream JS Engine history they were inherited from.
Added first-class standalone HScript mods: .hx/.hscript files dropped into any
Lua/Python script folder (scripts/, data/<song>/, stages/, characters/,
custom_notetypes/, custom_events/) now load directly with the full hook
lifecycle, their own sandboxed interpreter scope, and addHScript/removeHScript
interop from Lua, Python and HScript — no Lua parent script required. Start
from docs/TemplateScript.hx.
Added "Import mod (.zip)" to the Mods menu: pick a mod archive through the
Android document picker (or the desktop dialog), and it is unpacked into
mods/<folder>/, its pack.json is validated, it is enabled in modsList.txt and
the list reloads. This is the practical install path on a phone without a file
manager. Archives are checked before a single byte is decompressed: absolute
and .. entries, symbolic links, encrypted entries, unsupported compression and
oversized/expanded archives are rejected, content is extracted into a hidden
staging folder so a rejected archive never leaves a half-installed (or enabled)
mod, and an existing folder is only replaced after you confirm it. See
source/mobile/files/ModZipInstaller.hx and source/backend/ModPathPolicy.hx.

1.50.1;

Fixed a bug where the opponent/bf's camera would be incredibly offset.
Fixed a crash in 2hot related to its special notes.

1.50.0;

The crash handler now has summarized reasoning that tells you WHY your engine crashed specifically. there are a few summarized reasons right now, but there'll be more added in the future!
The cameraSetTarget function can now target GF! to do it, put "gf" as the target instead!
Added FPS Border option: Allows you to add a border around the FPS counter. Increases readability.
Added Autosave Time Option (Misc): Change the amount of time in seconds that it takes to autosave a chart.

Removed Render Info and Random Botplay Text as they've been recreated in LUA.

"Exit To Your Mother" no longer softlocks the game.
The "Windows Notification" event now detects if you're using Wine.
The MS and Judge text popups have been refactored into separate classes (Not fully tested!)
"qt_taunt" keybind has been renamed to "taunt".
Tabbing out of the game with auto pause inactive will no longer inaccurately change the Discord RPC to say "BRB!"

Fixed the Update State failing to download an update. (Only applies to 1.50.0 and newer!)
Fixed Classic Rendering Mode crashing on Linux devices
After MONTHS of not seeing it, fixed a bug with Bot Energy if it wasn't binded to CTRL.
Fixed the Golden Apple icon bounce looking.. off.
Tried to add failsafes when using the section copy buttons in the Chart Editor.
Fixed some functions being null in LUA (hopefully)
Hurt Notes have been fixed.. again.
Added hitCausesMiss null safety, fixing a bug where not having this value on a note would crash the game.
Fixed 'Clear Left/Right Section' clearing notes from a different section than the one you're on. (probably)
