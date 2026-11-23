package objects;

import flixel.util.FlxColor;

/**
 * Test stand-in for the real quant palette: encodes the quant index into the
 * channel values so specs can verify which subdivision CoolUtil selected.
 */
class NoteColors
{
  /** Returns [index + 1, (index + 1) * 2, (index + 1) * 3] as opaque colours. */
  public static function quantRGB(quantIndex:Int):Array<FlxColor>
    return [quantIndex + 1, (quantIndex + 1) * 2, (quantIndex + 1) * 3];
}
