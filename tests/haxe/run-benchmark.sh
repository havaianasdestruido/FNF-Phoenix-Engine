#!/usr/bin/env bash
# Compile and run the Device Benchmark spec in the Haxe interpreter, against a
# one-field stub and the import-free chart module — no game haxelibs needed:
#
#   backend/BenchmarkChart.hx   the fixed 60 s chart: shape, timing, ordering,
#                               lane bounds, determinism;
#   backend/RecoveryBoot.hx     the shared `modsDisabled()` predicate the mod
#                               lookups consult, flipped by Safe Mode or by the
#                               benchmark flag (the real `backend.Benchmark`
#                               controller pulls in PlayState and Flixel, so the
#                               stub only provides its static `active` flag);
#   the rest of the wiring (options row, PlayState hooks, endSong branch,
#   Paths/Mods predicate, pause menu, bundle assets) is pinned by scanning the
#   repo sources, which is why this runs from the repository root.
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$(pwd)
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/lime/system"
cp source/backend/BenchmarkChart.hx "$test_source/backend/BenchmarkChart.hx"
cp source/backend/RecoveryBoot.hx "$test_source/backend/RecoveryBoot.hx"
cat > "$test_source/lime/system/System.hx" <<'EOF'
package lime.system;
/** Test stub: RecoveryBoot only reads the application storage directory. */
class System
{
  public static var applicationStorageDirectory:String = '/tmp/';
}
EOF
cat > "$test_source/backend/Benchmark.hx" <<'EOF'
package backend;
/** Test stub: only the flag the mod-suppression predicate reads. */
class Benchmark
{
  public static var active:Bool = false;
}
EOF
"${HAXE:-haxe}" -cp "$test_source" -cp "$root/tests/haxe" -main BenchmarkSpec --interp
