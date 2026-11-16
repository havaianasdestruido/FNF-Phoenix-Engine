import backend.CommitFreshness;

class CommitFreshnessSpec {
  static function check(ok:Bool, message:String):Void {
    if (!ok) throw message;
  }

  static function main():Void {
    // --- parseBehindCount: GitHub compare payload ---
    check(CommitFreshness.parseBehindCount('{"status":"behind","ahead_by":0,"behind_by":52,"total_commits":52}') == 52, 'parses behind_by');
    check(CommitFreshness.parseBehindCount('{"status":"identical","ahead_by":0,"behind_by":0,"total_commits":0}') == 0, 'identical builds are 0 behind');
    check(CommitFreshness.parseBehindCount('{"status":"ahead","ahead_by":3,"behind_by":0,"total_commits":0}') == 0, 'ahead forks are 0 behind');
    check(CommitFreshness.parseBehindCount('{"status":"behind","behind_by":7}') == 7, 'minimal payload');
    check(CommitFreshness.parseBehindCount('{"message":"Not Found","documentation_url":"https://docs.github.com/rest"}') == null, '404 payload has no behind_by');
    check(CommitFreshness.parseBehindCount('garbage') == null, 'non-JSON payload');
    check(CommitFreshness.parseBehindCount('[]') == null, 'unexpected JSON shape');
    check(CommitFreshness.parseBehindCount('null') == null, 'json null literal');
    check(CommitFreshness.parseBehindCount('{"behind_by":null}') == null, 'null behind_by');
    check(CommitFreshness.parseBehindCount('{"behind_by":-4}') == null, 'negative behind_by rejected');
    check(CommitFreshness.parseBehindCount('{"behind_by":"13"}') == 13, 'numeric string behind_by');
    check(CommitFreshness.parseBehindCount('{"behind_by":2.9}') == 2, 'float behind_by truncated');

    // --- labels ---
    check(CommitFreshness.behindLabel(null) == CommitFreshness.LABEL_UNKNOWN, 'unknown label');
    check(CommitFreshness.behindLabel(0) == 'Up to date', 'up to date label');
    check(CommitFreshness.behindLabel(1) == '1 commit behind', 'singular label');
    check(CommitFreshness.behindLabel(2) == '2 commits behind', 'plural label');
    check(CommitFreshness.behindLabel(100) == '100 commits behind', 'red band edge label');
    check(CommitFreshness.behindLabel(1234567) == '1234567 commits behind', 'huge count label');
    check(CommitFreshness.commitLabel(null) == CommitFreshness.LABEL_UNKNOWN_COMMIT, 'missing sha fallback');
    check(CommitFreshness.commitLabel('') == CommitFreshness.LABEL_UNKNOWN_COMMIT, 'empty sha fallback');
    check(CommitFreshness.commitLabel('75775c9') == 'Commit 75775c9', 'short sha label');

    // --- hue anchors: piecewise-linear fade through the documented bands ---
    check(CommitFreshness.hueForBehind(1) == 125, 'spring green at the start');
    check(CommitFreshness.hueForBehind(5) == 120, 'pure green mid green band');
    check(CommitFreshness.hueForBehind(18) == 60, 'pure yellow mid yellow band');
    check(CommitFreshness.hueForBehind(38) == 30, 'pure orange mid orange band');
    check(CommitFreshness.hueForBehind(100) == 0, 'pure red at the end of the red band');
    check(CommitFreshness.hueForBehind(250) == 0, 'clamps beyond 100');
    check(CommitFreshness.hueForBehind(0) == 125, 'up to date is spring green');
    // The fade never reverses: older builds never look fresher.
    for (behind in 1...200) {
      check(CommitFreshness.hueForBehind(behind) >= CommitFreshness.hueForBehind(behind + 1),
        'hue must not increase between ' + behind + ' and ' + (behind + 1));
    }
    // Band sanity: greens for 1-10, yellows for 11-25, oranges for 26-50, reds for 51-100.
    for (behind in 1...11) {
      check(CommitFreshness.hueForBehind(behind) > 90, 'green band stays greenish at ' + behind);
    }
    for (behind in 11...26) {
      final hue = CommitFreshness.hueForBehind(behind);
      check(hue >= 46 && hue <= 96, 'yellow band stays yellowish at ' + behind);
    }
    for (behind in 26...51) {
      final hue = CommitFreshness.hueForBehind(behind);
      check(hue >= 18 && hue < 49, 'orange band stays orange-ish at ' + behind);
    }
    for (behind in 51...101) {
      check(CommitFreshness.hueForBehind(behind) < 21, 'red band stays reddish at ' + behind);
    }

    // --- hsbToRgb: canonical colors ---
    check(CommitFreshness.hsbToRgb(0, 1, 1) == 0xFFFF0000, 'pure red');
    check(CommitFreshness.hsbToRgb(60, 1, 1) == 0xFFFFFF00, 'pure yellow');
    check(CommitFreshness.hsbToRgb(120, 1, 1) == 0xFF00FF00, 'pure green');
    check(CommitFreshness.hsbToRgb(30, 1, 1) == 0xFFFF8000, 'canonical orange');
    check(CommitFreshness.hsbToRgb(120, 0, 1) == 0xFFFFFFFF, 'zero saturation is white');
    check(CommitFreshness.hsbToRgb(180, 1, 1) == 0xFF00FFFF, 'cyan');
    check(CommitFreshness.hsbToRgb(300, 1, 1) == 0xFFFF00FF, 'magenta');
    check((CommitFreshness.hsbToRgb(15, 1, 1) >>> 24) == 0xFF, 'alpha channel is opaque');

    // --- behindColor: the actual watermark colors ---
    check(CommitFreshness.behindColor(0) == CommitFreshness.behindColor(1), 'up to date matches the fresh end');
    check(CommitFreshness.behindColor(100) == 0xFFFF0000, 'exactly 100 is pure red');
    check(CommitFreshness.behindColor(1000) == 0xFFE00000, 'beyond 100 dims into deep red');
    final fresh = CommitFreshness.behindColor(4);
    final stale = CommitFreshness.behindColor(80);
    check(fresh != stale, 'fresh and stale builds get different colors');
    // Adjacent commits never share a shade inside the smooth part of the ramp.
    for (behind in 1...60) {
      check(CommitFreshness.behindColor(behind) != CommitFreshness.behindColor(behind + 1),
        'adjacent commits must fade between ' + behind + ' and ' + (behind + 1));
    }
    final greenBand = CommitFreshness.behindColor(3);
    check(((greenBand >> 16) & 0xFF) < ((greenBand >> 8) & 0xFF), 'fresh build is green-dominant');
    final redBand = CommitFreshness.behindColor(80);
    check(((redBand >> 16) & 0xFF) > ((redBand >> 8) & 0xFF), 'stale build is red-dominant');
    check(((redBand >> 8) & 0xFF) > 0, 'red band keeps some green at 80 of 100');
    check((CommitFreshness.behindColor(100) & 0x0000FF) == 0, 'pure red has no blue');

    Sys.println('Commit freshness tests passed');
  }
}
