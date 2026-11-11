#!/usr/bin/env bash
# Compile the production DiscordClient against the real hxdiscord_rpc/hxcpp
# native types, then exercise its ready callback without starting Discord.
# Requires the pinned hxcpp and hxdiscord_rpc from hmm.json and a C++ compiler.
# Haxe typechecking alone cannot catch the struct-vs-null C++ template error.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/lime/app" "$test_source/states"
cp source/backend/{DiscordClient,PhoenixVersion}.hx "$test_source/backend/"
cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;
class ClientPrefs { public static var discordRPC:Bool = true; }
HAXE
cat > "$test_source/states/MainMenuState.hx" <<'HAXE'
package states;
class MainMenuState {}
HAXE
cat > "$test_source/lime/app/Application.hx" <<'HAXE'
package lime.app;
class CloseEvent {
  public function add(listener:Void->Void):Void {}
}
class TestWindow {
  public var onClose:CloseEvent;
}
class Application {
  public static var current:Application;
  public var window:TestWindow;
}
HAXE
export HXCPP_COMPILE_THREADS="${HXCPP_COMPILE_THREADS:-2}"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -lib hxdiscord_rpc \
  -D DISCORD_ALLOWED -main DiscordReadySpec -cpp "$test_source/out"
exe="$test_source/out/DiscordReadySpec"
if [ "${OS:-}" = Windows_NT ]; then exe="$exe.exe"; fi
"$exe"
