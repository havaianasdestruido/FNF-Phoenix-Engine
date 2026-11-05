import backend.LogUtils;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;
using StringTools;

@:access(backend.LogUtils)
class LogUtilsSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function repeated(value:String, count:Int):String
  {
    final out = new StringBuf();
    for (_ in 0...count)
      out.add(value);
    return out.toString();
  }

  static function main():Void
  {
    final sample:String = "cwd: /home/alice/game/source.hx:12\n"
      + "Windows: C:\\Users\\Alice\\Phoenix\\source.hx:8\n"
      + "UNC: \\\\server\\share\\mods\\bad.hx\n"
      + "URL: https://example.test/docs\n";
    final redacted:String = LogUtils.redact(sample);
    check(!redacted.contains("/home/alice"), "POSIX home path must be redacted");
    check(!redacted.contains("C:\\Users\\Alice"), "Windows profile path must be redacted");
    check(!redacted.contains("\\\\server\\share"), "UNC path must be redacted");
    check(redacted.contains("[absolute path]"), "redaction marker should explain removed paths");
    check(redacted.contains("https://example.test/docs"), "URLs must not be mistaken for local paths");

    check(LogUtils.saveLog("crash/report.log", sample), "sanitized crash report should save");
    final crash:String = File.getContent("crash/report.log");
    check(!crash.contains("/home/alice"), "saved report must not contain the home path");
    check(!crash.contains("C:\\Users\\Alice"), "saved report must not contain a Windows profile path");

    FileSystem.createDirectory("legacy");
    LogUtils.localUserNames.push("alice");
    File.saveContent("legacy/crash-alice.log", "/home/alice/private/source.hx");
    LogUtils.cleanDirectory("legacy");
    final legacyNames:String = FileSystem.readDirectory("legacy").join(" ");
    check(!legacyNames.contains("alice"), "legacy filenames must redact account names too");
    check(!File.getContent('legacy/${FileSystem.readDirectory("legacy")[0]}').contains("/home/alice"),
      "legacy report contents must be redacted during cleanup");

    final oversized:String = repeated("x", LogUtils.MAX_LOG_FILE_BYTES + 256);
    final limited:String = LogUtils.limitText(oversized, LogUtils.MAX_LOG_FILE_BYTES);
    check(Bytes.ofString(limited).length <= LogUtils.MAX_LOG_FILE_BYTES, "individual log size limit");
    check(limited.contains("truncated"), "size-limited logs should explain truncation");
    check(LogUtils.saveLog("crash/oversized.log", oversized), "oversized report should be safely saved");
    check(FileSystem.stat("crash/oversized.log").size <= LogUtils.MAX_LOG_FILE_BYTES, "saved report must obey file cap");

    // Per-directory count retention: preserve the newest report and drop older ones.
    for (i in 0...(LogUtils.MAX_LOG_FILES + 3))
      check(LogUtils.saveLog('logs/report-$i.txt', 'report $i'), 'report $i should save');
    final retained = FileSystem.readDirectory("logs").filter(function(name:String):Bool {
      return name.endsWith(".txt");
    });
    check(retained.length <= LogUtils.MAX_LOG_FILES, "directory file-count cap");

    // Aggregate-size rotation runs on metadata and removes oldest files first.
    FileSystem.createDirectory("size-cap");
    final sizePayload:String = repeated("s", LogUtils.MAX_LOG_FILE_BYTES);
    for (i in 0...9)
      File.saveContent('size-cap/profile-$i.log', sizePayload);
    LogUtils.pruneDirectory("size-cap");
    var totalBytes:Float = 0.0;
    for (name in FileSystem.readDirectory("size-cap"))
      totalBytes += FileSystem.stat('size-cap/$name').size;
    check(totalBytes <= LogUtils.MAX_LOG_TOTAL_BYTES, "directory aggregate-size cap");

    // A simulated future cutoff makes age retention deterministic.
    FileSystem.createDirectory("age-cap");
    File.saveContent("age-cap/old.log", "old");
    final future:Float = Date.now().getTime() + (LogUtils.MAX_LOG_AGE_DAYS + 1) * 24.0 * 60.0 * 60.0 * 1000.0;
    LogUtils.pruneDirectory("age-cap", null, future);
    check(!FileSystem.exists("age-cap/old.log"), "age-expired logs must be removed");

    Sys.println("LogUtilsSpec: all checks passed");
  }
}
