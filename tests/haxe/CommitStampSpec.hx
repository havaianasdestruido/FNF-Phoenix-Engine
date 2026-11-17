import backend.HaxeCommit;

/**
 * Checks that a build is really stamped with the checkout's commit.
 *
 * The bottom-right watermark (`debug.CommitWatermark`) and the FPS counter
 * only get a commit id when `backend.HaxeCommit` compiles a real hash instead
 * of its null fallback, which only happens under `-Dcommit`. This spec is
 * compiled twice by `tests/haxe/run-commit-freshness.sh`:
 *
 *  - without the define, the macros must return null (the old default, which
 *    made every local build print "Development build");
 *  - with `-Dcommit`, they must return this repository's HEAD as a 7 and a
 *    40 character hex string, the short one being the prefix of the long one.
 *
 * `project.hxp` opts builds into the stamp automatically (`-Dno-commit` opts
 * out); without that define nothing embeds the commit and the watermark
 * silently degrades to "Development build".
 */
class CommitStampSpec
{
  static function check(ok:Bool, message:String):Void
  {
    if (!ok) throw message;
  }

  static final HEX:EReg = ~/^[0-9a-f]+$/;

  static function isHex(text:String):Bool
  {
    return text != null && HEX.match(text);
  }

  static function main():Void
  {
    final short = HaxeCommit.getGitCommitHash();
    final full = HaxeCommit.getGitCommitFullHash();

    #if commit
    check(short != null && short.length == 7 && isHex(short), 'stamped short hash must be 7 hex characters, got ' + short);
    check(full != null && full.length == 40 && isHex(full), 'stamped full hash must be 40 hex characters, got ' + full);
    check(full != null && short != null && (full : String).substr(0, 7) == short, 'short hash prefixes the full hash');
    #else
    check(short == null, 'without -Dcommit the short hash must stay null, got ' + short);
    check(full == null, 'without -Dcommit the full hash must stay null, got ' + full);
    #end

    Sys.println('Commit stamp tests passed (' + (#if commit 'stamped' #else 'unstamped' #end) + ')');
  }
}
