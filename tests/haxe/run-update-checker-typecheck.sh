#!/usr/bin/env bash
# Typecheck the threaded C++ update path using Lime's onUpdate signature.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/lime/app"
cp source/backend/{PhoenixVersion,PhoenixReleases,UpdateChecker}.hx "$test_source/backend/"
cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;
class ClientPrefs { public static var enablePreReleaseUpdates:Bool = false; }
HAXE
cat > "$test_source/lime/app/Application.hx" <<'HAXE'
package lime.app;
// Lime Application.onUpdate is Event<Float->Void>.
class UpdateEvent {
  public function new() {}
  public function add(listener:Float->Void):Void {}
  public function remove(listener:Float->Void):Void {}
}
class Application {
  public static var current:Application;
  public var onUpdate:UpdateEvent;
  public var meta:Map<String, String>;
}
HAXE
for platform in windows android; do
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D lime -D "$platform" \
    -main UpdateCheckerTypecheck -cpp "$test_source/out" --no-output
done
