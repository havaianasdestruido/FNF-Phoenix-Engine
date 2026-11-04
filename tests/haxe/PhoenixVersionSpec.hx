import backend.PhoenixVersion;
import backend.PhoenixReleases;

class PhoenixVersionSpec {
  static function check(ok:Bool, message:String):Void {
    if (!ok) throw message;
  }
  static function main():Void {
    check(PhoenixVersion.normalize('v0.0.1-pre1') == '0.0.1-pre.1', 'normalize');
    check(PhoenixVersion.isNewer('v0.0.1', '0.0.1-pre1'), 'final after pre');
    check(PhoenixVersion.isNewer('0.0.1-pre10', '0.0.1-pre2'), 'numeric pre');
    check(PhoenixVersion.isNewer('0.0.1-beta', '0.0.1-alpha'), 'stage order');
    check(!PhoenixVersion.isNewer('fix-ci', '0.0.1'), 'invalid');
    check(PhoenixVersion.isNewer('999999999999999999999.0.0', '9.0.0'), 'large number');
    final payload = haxe.Json.stringify([
      {tag_name:'fix-ci', draft:false, prerelease:false, body:'bad'},
      {tag_name:'v0.0.2', draft:false, prerelease:false, body:'# Stable\n- **Stable notes**'},
      {tag_name:'v0.0.3-pre1', draft:false, prerelease:false, body:'pre tag'},
      {tag_name:'v0.0.4', draft:false, prerelease:true, body:'# Changes\n<!--a--><!--b-->\n- **Hello**'},
      {tag_name:'v0.0.5', draft:true, prerelease:false, body:'draft'}
    ]);
    switch (PhoenixReleases.evaluate(payload, '0.0.1')) {
      case Available(release):
        check(release.tag == 'v0.0.2', 'default selects stable');
        check(release.changes.indexOf('Stable notes') >= 0, 'GitHub release body');
      default: throw 'expected stable update';
    }
    switch (PhoenixReleases.evaluate(payload, '0.0.1', true)) {
      case Available(release):
        check(release.tag == 'v0.0.4', 'opt-in selects GitHub prerelease');
        check(StringTools.endsWith(release.url, '/v0.0.4'), 'release url');
        check(release.changes.indexOf('Hello') >= 0 && release.changes.indexOf('<!--') < 0, 'notes');
      default: throw 'expected prerelease update';
    }
    final onlyPre = haxe.Json.stringify([
      {tag_name:'v0.0.2-pre1', draft:false, prerelease:false, body:'tag pre'},
      {tag_name:'v0.0.1', draft:false, prerelease:true, body:'GitHub pre'}
    ]);
    switch (PhoenixReleases.evaluate(onlyPre, '0.0.0')) { case NoReleases: default: throw 'prereleases excluded'; }
    switch (PhoenixReleases.evaluate(onlyPre, '0.0.0', true)) {
      case Available(release):
        check(release.tag == 'v0.0.2-pre1', 'original prerelease tag');
        check(StringTools.endsWith(release.url, '/v0.0.2-pre1'), 'original tag url');
      default: throw 'expected prerelease by tag';
    }
    switch (PhoenixReleases.evaluate(payload, '0.0.3')) { case UpToDate(_): default: throw 'stable up to date'; }
    switch (PhoenixReleases.evaluate('[]', '0.0.1')) { case NoReleases: default: throw 'empty'; }
    switch (PhoenixReleases.evaluate('{}', '0.0.1')) { case InvalidData: default: throw 'invalid data'; }
    Sys.println('Phoenix version and release tests passed');
  }
}
