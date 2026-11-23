package shaders;

import flixel.util.FlxColor;

/**
 * Minimal stand-in for the engine's RGB shader reference: plain FlxColor
 * channels with no shader parent, so specs can read back what CoolUtil set.
 */
class RGBShaderReference
{
  public var r:FlxColor = 0xFF102030;
  public var g:FlxColor = 0xFF405060;
  public var b:FlxColor = 0xFF708090;

  public function new() {}
}
