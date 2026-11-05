package shaders;

using StringTools;

/**
 * Flixel-free helpers that turn the shader names a stage declares in its JSON
 *
 * ```json
 * "shaders": ["rain", "Glitch.frag", "mods/mymod/shaders/myEffect.frag"]
 * ```
 *
 * into the clean, de-duplicated list `shaders.ShaderWarmup` compiles. Nothing
 * here touches the GPU, so the parsing rules can be unit tested in the Haxe
 * interpreter (`tests/haxe/ShaderWarmupPlanSpec.hx`).
 */
class ShaderWarmupPlan
{
  /**
   * The file part of a declaration, with its case intact.
   *
   * `" Rain.frag "` and `"mods/mymod/shaders/Rain.frag"` both become `"Rain"`.
   * Mod shader files are looked up with this (filesystems are case-sensitive),
   * while built-in names go through `normalizeName()`.
   *
   * @param name The name as written in the stage JSON (may be `null`).
   * @return The name without folder or shader extension, or `""`.
   */
  public static function runtimeName(name:Null<String>):String
  {
    if (name == null) return '';

    var value:String = name.trim();
    if (value.length == 0) return '';

    var slash:Int = value.lastIndexOf('/');
    if (slash < 0) slash = value.lastIndexOf('\\');
    if (slash >= 0) value = value.substr(slash + 1);
    if (value.length == 0) return '';

    // `.frag`, `.vert` and `.glsl` are all five characters long, so one
    // length works for every suffix. `endsWith` needs StringTools.
    var lower:String = value.toLowerCase();
    if (lower.endsWith('.frag') || lower.endsWith('.vert') || lower.endsWith('.glsl'))
      value = value.substr(0, value.length - 5);

    return value.trim();
  }

  /**
   * Normalizes one declared shader name for built-in lookups.
   *
   * Same as `runtimeName()` plus lowercasing: `" shaders/Rain.frag "` becomes
   * `"rain"`.
   *
   * @param name The name as written in the stage JSON (may be `null`).
   * @return The normalized name, or `""` when nothing usable is left.
   */
  public static function normalizeName(name:Null<String>):String
  {
    return runtimeName(name).toLowerCase();
  }

  /**
   * Cleans a stage's `"shaders"` array.
   *
   * Keeps the declared spelling (`Rain` stays `Rain`, so mod shader files are
   * still found on case-sensitive filesystems) but compares names normalized,
   * which drops duplicates such as `Rain`, ` rain ` and `rain.frag`.
   *
   * @param raw The array read from the stage JSON; `null` is allowed.
   * @param skip Names that should not be warmed (already normalized or not).
   * @return The usable names, in declaration order.
   */
  public static function declaredNames(raw:Null<Array<Null<String>>>, ?skip:Array<String>):Array<String>
  {
    var names:Array<String> = [];
    if (raw == null) return names;

    for (i in 0...raw.length)
    {
      var entry:Null<String> = raw[i];
      if (entry == null) continue;

      var name:String = entry.trim();
      if (name.length == 0) continue;

      var normalized:String = normalizeName(name);
      if (normalized.length == 0) continue;
      if (indexOfNormalized(names, normalized) != -1) continue;
      if (skip != null && indexOfNormalized(skip, normalized) != -1) continue;

      names.push(name);
    }

    return names;
  }

  /** Index of `normalized` inside `names`, comparing normalized spellings. */
  static function indexOfNormalized(names:Array<String>, normalized:String):Int
  {
    for (i in 0...names.length)
    {
      var candidate:Null<String> = names[i];
      if (candidate != null && normalizeName(candidate) == normalized) return i;
    }
    return -1;
  }
}
