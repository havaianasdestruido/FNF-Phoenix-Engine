package backend;

#if (lime && !flash)
import lime.app.Application;
#end

/**
 * Phoenix Engine's own version identity and ordering rules.
 *
 * Phoenix versions are independent from the upstream JS Engine / Psych Engine
 * compatibility markers. Tags may carry a leading `v`; the canonical runtime
 * form does not. Supported prerelease stages, in ascending order, are:
 * alpha < beta < pre < rc < final release (for example 0.0.1-pre1 < 0.0.1).
 */
class PhoenixVersion
{
  /** Repository that owns Phoenix releases and their changelogs. */
  public static inline var REPOSITORY:String = "havaianasdestruido/FNF-Phoenix-Engine";
  public static inline var REPOSITORY_URL:String = "https://github.com/" + REPOSITORY;
  public static inline var RELEASES_URL:String = REPOSITORY_URL + "/releases";
  public static inline var RELEASES_API_URL:String = "https://api.github.com/repos/" + REPOSITORY + "/releases?per_page=100";

  /**
   * Fallback for contexts without Lime application metadata. Keep equal to
   * VERSION in project.hxp.
   */
  public static inline var FALLBACK:String = "0.0.1";


  /** Running Phoenix version, sourced from the metadata set by project.hxp. */
  public static var current(get, never):String;

  static function get_current():String
  {
    #if (lime && !flash)
    try
    {
      if (Application.current != null && Application.current.meta != null)
      {
        final version:String = Application.current.meta.get('version');
        if (version != null && StringTools.trim(version).length > 0) return StringTools.trim(version);
      }
    }
    catch (_:Dynamic) {}
    #end
    return FALLBACK;
  }

  /** Canonical Phoenix version without a leading v, or null when invalid. */
  public static function normalize(raw:String):Null<String>
  {
    if (raw == null) return null;
    final pattern:EReg = ~/^[vV]?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-(alpha|beta|pre|rc)(?:[.-]?(0|[1-9][0-9]*))?)?$/i;
    final text:String = StringTools.trim(raw);
    if (!pattern.match(text)) return null;
    final core:String = pattern.matched(1) + "." + pattern.matched(2) + "." + pattern.matched(3);
    final stage:String = pattern.matched(4);
    if (stage == null || stage.length == 0) return core;
    final revision:String = pattern.matched(5);
    return core + "-" + stage.toLowerCase() + (revision == null || revision.length == 0 ? "" : "." + revision);
  }

  /** -1, 0 or 1. Invalid/unknown versions never compare as newer. */
  public static function compare(a:String, b:String):Int
  {
    final left:Null<ParsedVersion> = parse(a);
    final right:Null<ParsedVersion> = parse(b);
    if (left == null || right == null) return 0;

    var result:Int = compareNumber(left.major, right.major);
    if (result != 0) return result;
    result = compareNumber(left.minor, right.minor);
    if (result != 0) return result;
    result = compareNumber(left.patch, right.patch);
    if (result != 0) return result;
    if (left.stage != right.stage) return left.stage < right.stage ? -1 : 1;
    return compareNumber(left.revision, right.revision);
  }

  public static function isNewer(candidate:String, installed:String):Bool
  {
    return normalize(candidate) != null && normalize(installed) != null && compare(candidate, installed) > 0;
  }

  /** Display form with exactly one leading v. Invalid input is only trimmed. */
  public static function display(raw:String):String
  {
    final normalized:Null<String> = normalize(raw);
    return normalized == null ? (raw == null ? "" : StringTools.trim(raw)) : "v" + normalized;
  }

  static function parse(raw:String):Null<ParsedVersion>
  {
    final normalized:Null<String> = normalize(raw);
    if (normalized == null) return null;
    final pattern:EReg = ~/^[vV]?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-(alpha|beta|pre|rc)(?:[.-]?(0|[1-9][0-9]*))?)?$/i;
    pattern.match(StringTools.trim(raw));
    final stageName:String = pattern.matched(4);
    final stage:Int = switch (stageName == null ? "" : stageName.toLowerCase())
    {
      case "alpha": 0;
      case "beta": 1;
      case "pre": 2;
      case "rc": 3;
      default: 4;
    };
    final revision:String = pattern.matched(5);
    return {
      major: pattern.matched(1),
      minor: pattern.matched(2),
      patch: pattern.matched(3),
      stage: stage,
      revision: revision == null || revision.length == 0 ? "0" : revision
    };
  }

  /** Decimal comparison without Float/Int overflow on long version numbers. */
  static function compareNumber(a:String, b:String):Int
  {
    if (a.length != b.length) return a.length < b.length ? -1 : 1;
    return a == b ? 0 : (a < b ? -1 : 1);
  }
}

private typedef ParsedVersion =
{
  major:String,
  minor:String,
  patch:String,
  stage:Int,
  revision:String
}
