import backend.ClothEasterEggLogic;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

/**
 * Pins the two textures the `FlxClothSprite` easter egg draws, so the layout
 * numbers in `backend.ClothEasterEggLogic` cannot silently drift away from the
 * art they place.
 *
 * The interpreter spec (`ClothEasterEggSpec`) proves the layout fits the
 * viewport using `ClothEasterEggLogic.BANNER_WIDTH` and friends; this one reads
 * the real PNG headers and fails when a texture was re-exported at another size.
 * It also checks that both files are on the compact-build allowlist, because a
 * texture missing from `tests/assets/builtin-assets.txt` would ship in the full
 * release and be absent from `-DNO_BUILTIN_CONTENT` CI builds - where the scene
 * would then draw nothing at all.
 *
 * Needs the real source tree, so it runs from the repository root.
 *
 * Run with: bash tests/haxe/run-cloth-easter-egg.sh
 */
class ClothAssetsSpec
{
  static var failures:Int = 0;

  /** Paths of the two textures, relative to the repository root. */
  static final BANNER:String = 'assets/preload/images/clothFlag.png';

  static final ROPE:String = 'assets/preload/images/clothRope.png';

  /** Generator that recreates both textures from Phoenix's own art. */
  static final GENERATOR:String = 'tools/generate-cloth-easter-egg-art.sh';

  /** Build allowlist the content-policy spec walks. */
  static final ALLOWLIST:String = 'tests/assets/builtin-assets.txt';

  public static function main():Void
  {
    if (!FileSystem.exists(BANNER) || !FileSystem.exists(ROPE))
    {
      Sys.println('SKIP: cloth textures not found (spec copied out of the repo)');
      return;
    }

    dimensions(BANNER, ClothEasterEggLogic.BANNER_WIDTH, ClothEasterEggLogic.BANNER_HEIGHT, 'banner');
    dimensions(ROPE, ClothEasterEggLogic.ROPE_WIDTH, ClothEasterEggLogic.ROPE_HEIGHT, 'rope');

    listed(BANNER);
    listed(ROPE);

    check(FileSystem.exists(GENERATOR), 'the art generator is still shipped at $GENERATOR');

    if (failures > 0) throw '$failures cloth asset check(s) failed';
    Sys.println('ClothAssetsSpec: PASS');
  }

  /**
   * Compares a PNG's `IHDR` chunk with the size the layout reserves for it.
   *
   * @param path     PNG to inspect.
   * @param expected Width the layout assumes.
   * @param height   Height the layout assumes.
   * @param label    Name of the piece, for failure messages.
   */
  static function dimensions(path:String, expected:Int, height:Int, label:String):Void
  {
    final bytes:Bytes = File.getBytes(path);

    // 8-byte signature, then the IHDR chunk: 4 length, 4 "IHDR", then
    // width and height as big-endian 32-bit integers.
    final signature:Array<Int> = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 24)
    {
      failures++;
      Sys.println('FAILED: $label is too small to be a PNG');
      return;
    }

    for (i in 0...signature.length)
    {
      if (bytes.get(i) == signature[i]) continue;
      failures++;
      Sys.println('FAILED: $label is not a PNG');
      return;
    }

    final width:Int = be32(bytes, 16);
    final actualHeight:Int = be32(bytes, 20);

    equal(width, expected, '$label width in $path');
    equal(actualHeight, height, '$label height in $path');
  }

  /** Big-endian unsigned 32-bit read at `offset`. */
  static function be32(bytes:Bytes, offset:Int):Int
  {
    return (bytes.get(offset) << 24) | (bytes.get(offset + 1) << 16) | (bytes.get(offset + 2) << 8) | bytes.get(offset + 3);
  }

  /** Fails unless `path` is on the compact-build allowlist verbatim. */
  static function listed(path:String):Void
  {
    if (!FileSystem.exists(ALLOWLIST))
    {
      Sys.println('SKIP: $ALLOWLIST not found (spec copied out of the repo)');
      return;
    }

    final lines:Array<String> = StringTools.trim(File.getContent(ALLOWLIST)).split('\n');
    for (i in 0...lines.length)
      lines[i] = StringTools.trim(lines[i]);

    check(lines.indexOf(path) >= 0, '$path must be listed in $ALLOWLIST');
  }

  /**
   * Records one failure.
   *
   * @param ok    Whether the check passed.
   * @param label Message printed when it did not.
   */
  static function check(ok:Bool, label:String):Void
  {
    if (ok) return;
    failures++;
    Sys.println('FAILED: $label');
  }

  /**
   * Records one failure when two integers differ.
   *
   * @param actual   Value read from the file.
   * @param expected Value the layout reserves for it.
   * @param label    Message printed when they differ.
   */
  static function equal(actual:Int, expected:Int, label:String):Void
  {
    if (actual == expected) return;
    failures++;
    Sys.println('FAILED: $label (expected $expected, got $actual)');
  }
}
