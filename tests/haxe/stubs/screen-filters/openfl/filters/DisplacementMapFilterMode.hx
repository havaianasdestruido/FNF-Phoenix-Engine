package openfl.filters;

/** Renderer-free stand-in for openfl.filters.DisplacementMapFilterMode. */
enum abstract DisplacementMapFilterMode(String) from String to String
{
  var CLAMP = "clamp";
  var COLOR = "color";
  var IGNORE = "ignore";
  var WRAP = "wrap";
}
