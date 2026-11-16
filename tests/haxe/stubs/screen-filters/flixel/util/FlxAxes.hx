package flixel.util;

/** Renderer-free stand-in for flixel.util.FlxAxes. */
enum abstract FlxAxes(Int)
{
  var X = 0x01;
  var Y = 0x10;
  var XY = 0x11;
  var NONE = 0x00;
}
