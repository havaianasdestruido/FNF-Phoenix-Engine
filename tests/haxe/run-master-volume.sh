#!/usr/bin/env bash
# Options -> Audio -> Master Volume: the row must mirror `FlxG.sound.volume`
# (never store it twice) and follow the volume keys instead of going stale.
#
# The curve itself is executed by run-volume-curve.sh; this spec pins the wiring
# between the two options lists, `ClientPrefs` and the save/backup blacklists,
# which is what a rename breaks silently. File reads only, no game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
"${HAXE:-haxe}" -cp tests/haxe -main MasterVolumeSpec --interp
