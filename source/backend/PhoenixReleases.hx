package backend;

import haxe.Json;

/** A published Phoenix release selected from this repository's GitHub feed. */
typedef PhoenixRelease =
{
  /** Canonical version, without the tag's leading v. */
  version:String,
  /** Original validated Git tag, preserving its exact spelling. */
  tag:String,
  /** Release notes rendered as bounded plain text for the in-game screen. */
  changes:String,
  /** Exact release page, never GitHub's legacy /releases/latest redirect. */
  url:String
}

enum ReleaseLookup
{
  Available(release:PhoenixRelease);
  UpToDate(version:String);
  NoReleases;
  InvalidData;
}

/**
 * Pure GitHub-release selection logic, kept separate from HTTP/UI so the
 * versioning and feed-validation rules can be tested without game libraries.
 */
class PhoenixReleases
{
  static inline var MAX_CHANGELOG_CHARS:Int = 12000;
  static inline var EMPTY_NOTES:String = "No changelog was published for this release. Open the release page for details.";

  /**
   * Select the highest published Phoenix version, not the first feed item and
   * not GitHub's "latest" flag. The repository contains legacy non-semver tags
   * (fix-ci, pre-pre-pre-alpha), and Phoenix prereleases are part of its own
   * version line. Drafts and invalid tags are always ignored; prereleases are
   * included only when requested, whether identified by GitHub or by the tag.
   */
  public static function evaluate(payload:String, installedVersion:String, includePrereleases:Bool = false):ReleaseLookup
  {
    final installed:Null<String> = PhoenixVersion.normalize(installedVersion);
    if (installed == null) return InvalidData;

    var data:Dynamic = null;
    try
    {
      data = Json.parse(payload);
    }
    catch (_:Dynamic)
    {
      return InvalidData;
    }
    if (!Std.isOfType(data, Array)) return InvalidData;

    var best:Null<PhoenixRelease> = null;
    for (entry in (data : Array<Dynamic>))
    {
      if (entry == null || !Reflect.isObject(entry)) continue;
      if (Reflect.field(entry, "draft") == true) continue;
      final rawTag:Dynamic = Reflect.field(entry, "tag_name");
      if (!Std.isOfType(rawTag, String)) continue;
      final version:Null<String> = PhoenixVersion.normalize(cast rawTag);
      if (version == null) continue;
      if (!includePrereleases && (Reflect.field(entry, "prerelease") == true || version.indexOf("-") >= 0)) continue;
      if (best != null && PhoenixVersion.compare(version, best.version) <= 0) continue;

      best = {
        version: version,
        tag: cast rawTag,
        changes: plainText(Reflect.field(entry, "body")),
        url: PhoenixVersion.RELEASES_URL + "/tag/" + StringTools.urlEncode(cast rawTag)
      };
    }

    if (best == null) return NoReleases;
    return PhoenixVersion.compare(best.version, installed) > 0 ? Available(best) : UpToDate(best.version);
  }

  /** Convert GitHub Markdown to readable, bounded FlxText content. */
  public static function plainText(body:Dynamic):String
  {
    if (!Std.isOfType(body, String)) return EMPTY_NOTES;
    var text:String = cast body;
    text = StringTools.replace(text, "\r\n", "\n");
    text = StringTools.replace(text, "\r", "\n");
    text = ~/<!--[\s\S]*?-->/g.replace(text, "");
    text = ~/!\[([^\]]*)\]\([^)]*\)/g.replace(text, "$1");
    text = ~/\[([^\]]+)\]\([^)]*\)/g.replace(text, "$1");
    text = ~/^[ \t]*```[^\n]*\n?/gm.replace(text, "");
    text = ~/^[ \t]*#{1,6}[ \t]+/gm.replace(text, "");
    text = ~/\*\*([^*\n]+)\*\*/g.replace(text, "$1");
    text = ~/__([^_\n]+)__/g.replace(text, "$1");
    text = ~/^[ \t]*[-*+][ \t]+/gm.replace(text, "- ");
    text = ~/`([^`\n]+)`/g.replace(text, "$1");
    text = ~/\n{3,}/g.replace(text, "\n\n");
    text = StringTools.trim(text);
    if (text.length == 0) return EMPTY_NOTES;
    if (text.length > MAX_CHANGELOG_CHARS)
      text = StringTools.trim(text.substr(0, MAX_CHANGELOG_CHARS)) + "\n\n[Changelog truncated. Open the release page to read the rest.]";
    return text;
  }
}
