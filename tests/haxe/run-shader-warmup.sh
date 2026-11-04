#!/usr/bin/env bash
# Shader warm-up (TODO §18, [P3]): exercise the Flixel-free declaration plan in
# the Haxe interpreter, then typecheck and run shaders/ShaderWarmup.hx against
# stubs that mirror the private OpenFL members it drives (`Stage.context3D`,
# `Shader.__context`/`__init()`). No game haxelibs needed.
set -euo pipefail
cd "$(dirname "$0")/../.."

test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT

# 1. Declaration parsing/dedup rules (no stubs, no Flixel).
mkdir -p "$test_source/shaders"
cp source/shaders/ShaderWarmupPlan.hx "$test_source/shaders/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ShaderWarmupPlanSpec --interp

# 2. Warm-up machinery against minimal OpenFL/Flixel stubs.
cp source/shaders/ShaderWarmup.hx "$test_source/shaders/"
mkdir -p "${test_source}/openfl/display" "${test_source}/openfl/display3D" \
  "${test_source}/flixel/system/frontEnds" "${test_source}/backend"

cat > "${test_source}/openfl/display/Shader.hx" <<'HAXE'
package openfl.display;

#if !flash
import openfl.display3D.Context3D;

/**
 * Stub of the private OpenFL surface `shaders.ShaderWarmup` touches: the lazy
 * `__context`/`__init()` pair the renderer uses before compiling a program.
 */
class Shader
{
  public var program:Dynamic = null;
  public var glVertexSource:String = 'void main() { }';
  public var glFragmentSource:String = 'void main() { gl_FragColor = vec4(1.0); }';

  @:noCompletion private var __context:Context3D = null;

  public function new() {}

  @:noCompletion private function __init():Void
  {
    if (__context == null || program != null) return;
    program = {compiled: true};
  }
}
#else
typedef Shader = flash.display.Shader;
#end
HAXE

cat > "${test_source}/openfl/display/Stage.hx" <<'HAXE'
package openfl.display;

import openfl.display3D.Context3D;

class Stage
{
  public var context3D(default, null):Context3D = null;

  public function new(?context:Context3D)
  {
    context3D = context;
  }
}
HAXE

cat > "${test_source}/openfl/display3D/Context3D.hx" <<'HAXE'
package openfl.display3D;

class Context3D
{
  public function new() {}
}
HAXE

cat > "${test_source}/flixel/FlxG.hx" <<'HAXE'
package flixel;

import flixel.system.frontEnds.LogFrontEnd;
import openfl.display.Stage;

class FlxG
{
  public static var stage:Stage = null;
  public static var log(default, null):LogFrontEnd = new LogFrontEnd();
}
HAXE

cat > "${test_source}/flixel/system/frontEnds/LogFrontEnd.hx" <<'HAXE'
package flixel.system.frontEnds;

class LogFrontEnd
{
  public function new() {}

  public function warn(message:Dynamic, ?pos:haxe.PosInfos):Void {}
}
HAXE

cat > "${test_source}/backend/VLog.hx" <<'HAXE'
package backend;

class VLog
{
  public static function isActive():Bool return false;

  public static function log(tag:String, message:String):Void {}
}
HAXE

cat > "${test_source}/backend/FlxFixedShader.hx" <<'HAXE'
package backend;

import openfl.display.Shader;

class FlxFixedShader extends Shader
{
  public var custom:Bool = false;
  public var save:Bool = true;

  public function new(?save:Bool)
  {
    if (save != null) this.save = save;
    super();
  }
}
HAXE

"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D SHADERS_ALLOWED -main ShaderWarmupSpec --interp

# 3. What a song actually warms up, with stubbed PlayState/stage/registry.
mkdir -p "$test_source/play/helpers" "$test_source/data"
cp source/play/helpers/PlayStateShaders.hx "$test_source/play/helpers/"

cat > "${test_source}/play/PlayState.hx" <<'HAXE'
package play;

import openfl.display.Shader;

class PlayState
{
  public static var screenshader:{var shader:Shader;} = {shader: new Shader()};

  public var stages:Array<BaseStage> = [];
  public var runtimeShaders:Map<String, Array<String>> = new Map();

  public function new() {}

  public function initLuaShader(name:String):Bool return runtimeShaders.exists(name);

  public function createRuntimeShader(name:String):Shader return runtimeShaders.exists(name) ? new Shader() : null;
}
HAXE

cat > "${test_source}/play/BaseStage.hx" <<'HAXE'
package play;

import openfl.display.Shader;

class BaseStage
{
  public function new() {}

  public function declareShaders():Array<Shader> return [];
}
HAXE

cat > "${test_source}/data/StageData.hx" <<'HAXE'
package data;

typedef StageFile = {
  @:optional var shaders:Array<String>;
}
HAXE

cat > "${test_source}/backend/ClientPrefs.hx" <<'HAXE'
package backend;

class ClientPrefs
{
  public static var shaders:Bool = true;
}
HAXE

cat > "${test_source}/shaders/ShaderWarmupRegistry.hx" <<'HAXE'
package shaders;

import openfl.display.Shader;

/** Stub of the built-in registry: only "rain" is known here. */
class ShaderWarmupRegistry
{
  public static function exists(name:Null<String>):Bool return normalize(name) == 'rain';

  public static function create(name:Null<String>):Shader return exists(name) ? new Shader() : null;

  static function normalize(name:Null<String>):String
  {
    if (name == null) return '';
    return StringTools.replace(StringTools.trim(name).toLowerCase(), '.frag', '');
  }
}
HAXE

"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D SHADERS_ALLOWED -main PlayStateShadersSpec --interp
echo "shader warm-up: declaration plan, warm-up counters and per-song wiring OK"
