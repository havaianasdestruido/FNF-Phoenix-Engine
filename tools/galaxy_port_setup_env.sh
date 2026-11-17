#!/usr/bin/env bash
# Rebuilds the full dev environment for the Galaxy port after a sandbox reset:
#   1. Haxe 4.3.7 toolchain (setup/install-haxe-linux.sh -> ~/.local)
#   2. All haxelibs (git sources, since haxelib.org registry is SSL-blocked here)
#   3. /tmp/galaxy (GalaxyMod clone used by the port scripts)
# Idempotent; safe to re-run. Log: /tmp/galaxy_env_setup.log
#
# Known registry blockers + fixes discovered 2026-11-16:
#   - haxelib.org registry: SSL EOF -> always `haxelib git <url> <ref>`
#   - MAJigsaw77/hxgamemode: default branch is `main` (not master)
#   - grig.audio depends on tink_core 1.26.0 (registry): install via git tag
#     and RENAME the version dir: haxelib expects dotted versions with commas
#     (Data.safe(): 1.26.0 -> "1,26,0") plus a matching .current file.
#   - hython depends on signals.hx ^1.0.0 (registry): PaoPaoGH/signals.hx main
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

say() { echo "== $* =="; }
g() { # g <name> <url> <ref> [extra...]
  local name="$1" url="$2" ref="$3"; shift 3
  if [ -e "$HOME/haxelib/$name" ]; then say "haxelib $name (already present, refreshing ref)"; else say "haxelib $name"; fi
  haxelib git "$name" "$url" "$ref" --quiet "$@" 2>&1 | tail -1
}

say "haxe toolchain"
bash "$(dirname "$0")/../setup/install-haxe-linux.sh"

say "haxelib: engine core (refs pinned in hmm.json / setup scripts)"
g lime        https://github.com/JS-Engine-things/lime-8.1.2      45816ca456764761cbea8d3cc57701a592f892f1
g openfl      https://github.com/JS-Engine-things/openfl          f2158f144bd77c950fb965939ea9bece48e45962
g flixel      https://github.com/JS-Engine-things/flixel-JS-Engine baa47998542eab29f4a9cc02a0283d6120d6b1ef
g hxcpp       https://github.com/FunkinCrew/hxcpp                  d5bda40ac13f2823fe1bdcb5476e0eb027f1e7e9
g hscript     https://github.com/CodenameCrew/hscript-improved     48ec0f4b013a4e5e18d6ce1456be7b3c3f12a1fa
g tjson       https://github.com/moxie-coder/tjson                 7e2b6540bee6c3d94cd3b957453ffb1e3e438c59
g flxanimate  https://github.com/Dot-Stuff/flxanimate              768740a56b26aa0c072720e0d1236b94afe68e3e
g hxluajit    https://github.com/ShadowEngineTeam/hxluajit         a4b2a0a14a371dc404f3062854b8d0d6b404a0ed
g funkin.vis  https://github.com/JS-Engine-things/funkVis-FrequencyFixed badf0368f0035d0d7bab6529fcbc1ca22e47d31a
g grig.audio  https://github.com/JS-Engine-things/grig.audio        eb5cad389e6110af6767457a62b9a80af2507826
g hxdiscord_rpc https://github.com/MAJigsaw77/hxdiscord_rpc        2ca5930e9647c5de8c220f98427b5c50ddd244dd --skip-dependencies
g hxvlc       https://github.com/JS-Engine-things/hxvlc            2bb1cb4d1e9277f2a64b7bcebf3622f05eddfaa2 --skip-dependencies
g hxnativefiledialog https://github.com/MAJigsaw77/hxnativefiledialog 7f2353172bd3d0e3b8324ad5de4eeb9bc9c44af9 --skip-dependencies
g hxgamemode  https://github.com/MAJigsaw77/hxgamemode             main

say "haxelib: JS-Engine-things forks (registry versions, installed from git)"
# flixel-addons: repo default; JS-Engine-things fork tracks upstream 3.3.0
g flixel-addons https://github.com/JS-Engine-things/flixel-addons  master
g flixel-ui     https://github.com/JS-Engine-things/flixel-ui      master
g flixel-tools  https://github.com/JS-Engine-things/flixel-tools   master

say "haxelib: registry-only libs (haxelib.org is blocked; git fallbacks)"
haxelib install hxp --quiet 2>&1 | tail -1
haxelib install hxcpp-debug-server --quiet 2>&1 | tail -1
haxelib install hython 0.0.352-beta --quiet 2>&1 | tail -1
# tink_core 1.26.0 for grig.audio: git tag + comma-dir rename (haxelib Data.safe)
g tink_core   https://github.com/haxetink/tink_core                1.26.0
if [ -d "$HOME/haxelib/tink_core/git" ]; then
  mv "$HOME/haxelib/tink_core/git" "$HOME/haxelib/tink_core/1,26,0"
  echo "1.26.0" > "$HOME/haxelib/tink_core/.current"
fi
# signals.hx for hython
g signals.hx  https://github.com/PaoPaoGH/signals.hx               main

say "sanity: haxelib path checks"
for l in flixel flixel-addons flixel-ui grig.audio hython; do
  echo -n "$l -> "
  haxelib path "$l" 2>&1 | head -1
done

say "done"
echo "ALL_ENV_SETUP_DONE"
