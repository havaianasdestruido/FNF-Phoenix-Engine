/*
 * Apache License, Version 2.0
 *
 * Copyright (c) 2026 Phoenix Engine contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law and agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * CommitFreshness.hx
 * Pure rules behind the bottom-right build-freshness watermark
 * (see debug.CommitWatermark): parsing the GitHub compare payload, the
 * labels shown next to the commit id and the "rainbow-ish" color the
 * behind-counter fades through.
 *
 * Deliberately free of game libraries so it can run on the plain
 * interpreter (see tests/haxe/CommitFreshnessSpec.hx).
 */
package backend;

import haxe.Json;

class CommitFreshness
{
  /** Shown while the first freshness check of the session is in flight. */
  public static inline var LABEL_CHECKING:String = 'Checking...';

  /** Shown when the behind count could not be determined (offline, GitHub error, unknown commit). */
  public static inline var LABEL_UNKNOWN:String = 'Commits behind: ?';

  /** Fallback for the bottom line when the build was made without commit metadata. */
  public static inline var LABEL_UNKNOWN_COMMIT:String = 'Development build';

  /** Fresh green used for "Up to date" and for the far left of the fade. */
  static inline var HUE_FRESH:Float = 125;

  /**
   * Hue anchors (behind count -> hue in degrees), piecewise linear.
   *
   * The fade spans the whole 1..100 range and passes through the
   * canonical hue of each documented band near its center: pure green in
   * the green band (1-10), pure yellow in the yellow band (11-25), pure
   * orange in the orange band (26-50) and pure red at the end of the red
   * band (51-100). Every commit therefore gets a slightly different
   * shade instead of one flat color per band.
   */
  static final HUE_ANCHORS:Array<{behind:Int, hue:Float}> = [
    {behind: 1, hue: 125},
    {behind: 5, hue: 120},
    {behind: 18, hue: 60},
    {behind: 38, hue: 30},
    {behind: 60, hue: 12},
    {behind: 100, hue: 0}
  ];

  /** Commit counts beyond the red band still fade: the value channel drops for extra age. */
  static inline var VALUE_DEEP_RED:Float = 0.88;

  /**
   * Extracts how many commits the build is behind upstream `main` from a
   * GitHub compare response (`<base>...<head>`): `behind_by` counts the
   * commits on `base` that are not reachable from `head`, i.e. exactly
   * "how many commits main has that this build does not".
   *
   * Returns null when the payload is unusable: HTTP error page, garbage
   * or unexpected JSON, or a `behind_by` that is missing or negative
   * (GitHub answers 404 for SHAs it does not know, such as local-only
   * commits, with a JSON body that has no `behind_by`).
   */
  public static function parseBehindCount(payload:String):Null<Int>
  {
    if (payload == null) return null;

    var data:Dynamic = null;
    try
    {
      data = Json.parse(payload);
    }
    catch (_:Dynamic)
    {
      return null;
    }
    if (data == null) return null;

    final raw:Dynamic = Reflect.field(data, 'behind_by');
    if (raw == null) return null;

    var behind:Null<Int> = null;
    switch (Type.typeof(raw))
    {
      case TInt:
        behind = raw;
      case TFloat:
        behind = Std.int(raw);
      case TClass(c):
        // Defensive: strings arrive as TClass(String). Accept numeric strings.
        if (Type.getClassName(c) == 'String')
        {
          final parsed:Float = Std.parseFloat(Std.string(raw));
          if (!Math.isNaN(parsed)) behind = Std.int(parsed);
        }
      default:
        behind = null;
    }

    if (behind == null || behind < 0) return null;
    return behind;
  }

  /** Bottom line: the build's short commit id, or a graceful fallback for local builds. */
  public static function commitLabel(shortSha:Null<String>):String
  {
    return shortSha != null && shortSha.length > 0 ? 'Commit $shortSha' : LABEL_UNKNOWN_COMMIT;
  }

  /** Top line: how far behind the build is. `null` means "not known" (unchecked/offline). */
  public static function behindLabel(behind:Null<Int>):String
  {
    if (behind == null) return LABEL_UNKNOWN;
    if (behind <= 0) return 'Up to date';
    return behind == 1 ? '1 commit behind' : '$behind commits behind';
  }

  /**
   * Hue (degrees) for a behind count: piecewise linear between HUE_ANCHORS,
   * clamped at both ends. Non-increasing over the whole range, so larger
   * counts always look older.
   */
  public static function hueForBehind(behind:Int):Float
  {
    if (behind <= HUE_ANCHORS[0].behind) return HUE_FRESH;

    var previous = HUE_ANCHORS[0];
    for (i in 1...HUE_ANCHORS.length)
    {
      final anchor = HUE_ANCHORS[i];
      if (behind <= anchor.behind)
      {
        final span = anchor.behind - previous.behind;
        final t = span <= 0 ? 0 : (behind - previous.behind) / span;
        return previous.hue + (anchor.hue - previous.hue) * t;
      }
      previous = anchor;
    }
    return HUE_ANCHORS[HUE_ANCHORS.length - 1].hue;
  }

  /**
   * "Rainbow-ish" fade for the behind counter. Full saturation throughout,
   * hue from spring green down to red across 1..100 commits, and a dimmed
   * deep red beyond 100. Returned as 0xFFRRGGBB.
   */
  public static function behindColor(behind:Int):Int
  {
    return hsbToRgb(hueForBehind(behind), 1.0, behind > 100 ? VALUE_DEEP_RED : 1.0);
  }

  /** Grey used for the commit id and for the unknown/checking states. */
  public static inline var COLOR_DIM:Int = 0xFF9E9E9E;

  /** HSB -> 0xFFRRGGBB. Saturation/value are expected in [0, 1]. */
  public static function hsbToRgb(h:Float, s:Float, v:Float):Int
  {
    var hue = h % 360;
    if (hue < 0) hue += 360;
    if (s < 0) s = 0;
    if (s > 1) s = 1;
    if (v < 0) v = 0;
    if (v > 1) v = 1;

    final c = v * s;
    final x = c * (1 - Math.abs(((hue / 60) % 2) - 1));
    final m = v - c;

    var r = 0.0, g = 0.0, b = 0.0;
    if (hue < 60) { r = c; g = x; }
    else if (hue < 120) { r = x; g = c; }
    else if (hue < 180) { g = c; b = x; }
    else if (hue < 240) { g = x; b = c; }
    else if (hue < 300) { r = x; b = c; }
    else { r = c; b = x; }

    final ri = clampByte((r + m) * 255);
    final gi = clampByte((g + m) * 255);
    final bi = clampByte((b + m) * 255);
    return (0xFF << 24) | (ri << 16) | (gi << 8) | bi;
  }

  static inline function clampByte(value:Float):Int
  {
    final rounded = Std.int(Math.round(value));
    return rounded < 0 ? 0 : (rounded > 255 ? 255 : rounded);
  }
}
