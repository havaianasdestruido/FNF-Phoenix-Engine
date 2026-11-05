package backend;
import haxe.io.Bytes;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
/**
 * Privacy and retention helpers for engine-generated diagnostic logs.
 *
 * Before a log is persisted or exported, absolute paths and local account
 * names are replaced with safe placeholders. Retained crash, shader/copy and
 * profiler logs are limited to 2 MiB each, 10 files / 16 MiB per directory,
 * and 30 days. All operations are best-effort so logging can never interrupt
 * gameplay or crash handling.
 */
class LogUtils
{
  /** Maximum size of an individual crash, profiler, shader or copy report. */
  public static inline var MAX_LOG_FILE_BYTES:Int = 2 * 1024 * 1024;
  /** Maximum number of engine reports retained in one report directory. */
  public static inline var MAX_LOG_FILES:Int = 10;
  /** Aggregate on-disk budget for reports in one directory. */
  public static inline var MAX_LOG_TOTAL_BYTES:Int = 16 * 1024 * 1024;
  /** Remove old reports after this many days, even when space is available. */
  public static inline var MAX_LOG_AGE_DAYS:Int = 30;
  static inline final MAX_SANITIZE_READ_BYTES:Int = MAX_LOG_FILE_BYTES * 8;
  static inline final DAY_MS:Float = 24.0 * 60.0 * 60.0 * 1000.0;
  static inline final TRUNCATION_MARKER:String = "\n[Phoenix Engine truncated this log at its size limit.]\n";
  static final WINDOWS_BACKSLASH_PATH:EReg = new EReg('(^|[\\s=\\[\\(\\x22\\x27])([A-Za-z]:\\\\[^\\s\\x22\\x27<>|]+)', "g");
  static final WINDOWS_SLASH_PATH:EReg = new EReg('(^|[\\s=\\[\\(\\x22\\x27])([A-Za-z]:/[^\\s\\x22\\x27<>|]+)', "g");
  static final UNC_ABSOLUTE_PATH:EReg = new EReg('(^|[\\s=\\[\\(\\x22\\x27])\\\\[^\\s\\x22\\x27<>|]+', "g");
  static final POSIX_ABSOLUTE_PATH:EReg = new EReg('(^|[\\s=\\[\\(\\x22\\x27])/(?:[^\\s\\x22\\x27<>|]+/)*[^\\s\\x22\\x27<>|,;\\]\\)]*', "g");
  static final POSIX_PROFILE_USER:EReg = new EReg('(/(?:home|Users)/)[^/]+', "ig");
  static var privacyInitialized:Bool = false;
  static var homePathPatterns:Array<EReg> = [];
  static var localUserNames:Array<String> = [];
  /**
   * Redacts home directories, common user-profile paths, usernames, and
   * absolute POSIX, Windows-drive, and UNC paths from diagnostic text.
   */
  public static function redact(text:String):String
  {
    if (text == null || text.length == 0)
      return text == null ? "" : text;
    #if sys
    initializePrivacyPatterns();
    #end
    var safe:String = text;
    for (pattern in homePathPatterns)
      safe = pattern.replace(safe, "[home]");
    for (name in localUserNames)
      safe = new EReg(escapeRegex(name), "ig").replace(safe, "[username]");
    safe = POSIX_PROFILE_USER.replace(safe, "$1[username]");
    safe = WINDOWS_BACKSLASH_PATH.replace(safe, "$1[absolute path]");
    safe = WINDOWS_SLASH_PATH.replace(safe, "$1[absolute path]");
    safe = UNC_ABSOLUTE_PATH.replace(safe, "$1[absolute path]");
    safe = POSIX_ABSOLUTE_PATH.replace(safe, "$1[absolute path]");
    return safe;
  }
  /**
   * Limits text by UTF-8 byte count, cutting at a line boundary where possible.
   */
  public static function limitText(text:String, maxBytes:Int):String
  {
    if (text == null || maxBytes <= 0)
      return "";
    final bytes:Bytes = Bytes.ofString(text);
    if (bytes.length <= maxBytes)
      return text;
    final markerBytes:Int = Bytes.ofString(TRUNCATION_MARKER).length;
    if (maxBytes <= markerBytes)
      return "[truncated]";
    var end:Int = maxBytes - markerBytes;
    var lineEnd:Int = end;
    while (lineEnd > 0 && bytes.get(lineEnd - 1) != "\n".code)
      lineEnd--;
    if (lineEnd > end / 2)
    {
      end = lineEnd;
    }
    else
    {
      // Do not split a UTF-8 continuation sequence when there is no useful
      // newline near the cap.
      while (end > 0 && end < bytes.length && (bytes.get(end) & 0xC0) == 0x80)
        end--;
    }
    return bytes.getString(0, end) + TRUNCATION_MARKER;
  }
  /**
   * Saves a sanitized report and applies age, file-count and aggregate-size
   * retention in its containing directory. Returns false on unavailable or
   * unwritable storage; callers should treat that as a non-fatal log failure.
   */
  public static function saveLog(path:String, text:String, maxBytes:Int = MAX_LOG_FILE_BYTES):Bool
  {
    #if sys
    try
    {
      final directory:String = Path.directory(path);
      ensureDirectory(directory);
      cleanDirectory(directory);
      File.saveContent(path, limitText(redact(text), maxBytes));
      pruneDirectory(directory, Path.withoutDirectory(path));
      return FileSystem.exists(path) && !FileSystem.isDirectory(path);
    }
    catch (_:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }
  /**
   * Redacts and size-limits an already-created export in place, then enforces
   * the directory retention policy. Returns false if the file cannot be made
   * safe to hand off.
   */
  public static function sanitizeFile(path:String, maxBytes:Int = MAX_LOG_FILE_BYTES):Bool
  {
    #if sys
    try
    {
      if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
        return false;
      final stat = FileSystem.stat(path);
      if (stat.size > MAX_SANITIZE_READ_BYTES)
        return false;
      final original:String = File.getContent(path);
      final safe:String = limitText(redact(original), maxBytes);
      if (safe != original)
        File.saveContent(path, safe);
      pruneDirectory(Path.directory(path), Path.withoutDirectory(path));
      return true;
    }
    catch (_:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }
  /**
   * Applies retention and redacts existing engine report files at startup.
   * This also upgrades logs written by older builds before Android's read-only
   * document roots or a user-selected export can expose them.
   */
  public static function cleanup():Void
  {
    #if sys
    for (directory in ["crash", "debug/log", "logs"])
    {
      try
      {
        cleanDirectory(directory);
      }
      catch (_:Dynamic) {}
    }
    #end
  }
  /** Replaces characters that are invalid or unsafe in a log filename. */
  public static function safeFileName(value:String, fallback:String = "log"):String
  {
    if (value == null)
      value = "";
    final out = new StringBuf();
    for (i in 0...value.length)
    {
      final ch:String = value.charAt(i);
      final code:Int = value.charCodeAt(i);
      if (code < 32 || code == 127 || ch == "/" || ch == "\\" || ch == ":" || ch == "*" || ch == "?"
          || ch == '"' || ch == "<" || ch == ">" || ch == "|")
        out.add("_");
      else
        out.add(ch);
    }
    var safe:String = StringTools.trim(out.toString());
    while (StringTools.startsWith(safe, "."))
      safe = safe.substr(1);
    if (safe == "" || safe == "." || safe == "..")
      safe = fallback;
    if (safe.length > 100)
      safe = safe.substr(0, 100);
    return safe;
  }
  #if sys
  static function initializePrivacyPatterns():Void
  {
    if (privacyInitialized)
      return;
    privacyInitialized = true;
    final homes:Array<String> = [];
    addUnique(homes, Sys.getEnv("HOME"));
    addUnique(homes, Sys.getEnv("USERPROFILE"));
    final homeDrive:Null<String> = Sys.getEnv("HOMEDRIVE");
    final homePath:Null<String> = Sys.getEnv("HOMEPATH");
    if (homeDrive != null && homePath != null)
      addUnique(homes, homeDrive + homePath);
    for (home in homes)
    {
      if (home.length > 3)
      {
        final pattern:String = pathLiteralPattern(home);
        if (pattern != "")
          homePathPatterns.push(new EReg(pattern, "ig"));
      }
    }
    for (key in ["USER", "USERNAME", "LOGNAME"])
      addUnique(localUserNames, Sys.getEnv(key));
  }
  static function addUnique(values:Array<String>, value:Null<String>):Void
  {
    if (value == null || value.length == 0)
      return;
    final trimmed:String = StringTools.trim(value);
    if (trimmed != "" && !values.contains(trimmed))
      values.push(trimmed);
  }
  static function pathLiteralPattern(path:String):String
  {
    final normalized:String = StringTools.replace(path, "\\", "/");
    final parts:Array<String> = normalized.split("/");
    final escaped:Array<String> = [];
    for (part in parts)
      escaped.push(escapeRegex(part));
    return escaped.join("[\\\\/]");
  }
  static function escapeRegex(value:String):String
  {
    final special:String = "\\^$.*+?()[]{}|";
    final out = new StringBuf();
    for (i in 0...value.length)
    {
      final ch:String = value.charAt(i);
      if (special.indexOf(ch) >= 0)
        out.add("\\");
      out.add(ch);
    }
    return out.toString();
  }
  static function ensureDirectory(directory:String):Void
  {
    if (directory == null || directory == "" || directory == "." || FileSystem.exists(directory))
    {
      if (directory != null && directory != "" && directory != "." && !FileSystem.isDirectory(directory))
        throw new haxe.Exception('Log directory is not a directory: $directory');
      return;
    }
    final parent:String = Path.directory(directory);
    if (parent != "" && parent != "." && parent != directory)
      ensureDirectory(parent);
    FileSystem.createDirectory(directory);
  }
  static function cleanDirectory(directory:String):Void
  {
    if (directory == null || directory == "" || !FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
      return;
    pruneDirectory(directory);
    for (entryName in FileSystem.readDirectory(directory))
    {
      if (!isManagedLogFile(entryName))
        continue;
      var name:String = entryName;
      var path:String = Path.join([directory, name]);
      if (FileSystem.isDirectory(path))
        continue;
      try
      {
        // Older exports could put a local account name in the filename.
        // Preserve the extension while replacing that metadata as well.
        final extension:String = Path.extension(name).toLowerCase();
        final safeStem:String = safeFileName(redact(Path.withoutExtension(name)), "report");
        var safeName:String = safeStem + "." + extension;
        if (safeName != name)
        {
          var suffix:Int = 1;
          while (FileSystem.exists(Path.join([directory, safeName])))
          {
            safeName = safeStem + "-" + suffix + "." + extension;
            suffix++;
          }
          FileSystem.rename(path, Path.join([directory, safeName]));
          name = safeName;
          path = Path.join([directory, name]);
        }
        final stat = FileSystem.stat(path);
        if (stat.size > MAX_SANITIZE_READ_BYTES)
        {
          FileSystem.deleteFile(path);
          continue;
        }
        final original:String = File.getContent(path);
        final safe:String = limitText(redact(original), MAX_LOG_FILE_BYTES);
        if (safe != original)
          File.saveContent(path, safe);
      }
      catch (_:Dynamic)
      {
        // If an old engine log cannot be safely read or rewritten, remove it
        // rather than leave a potentially identifying file in a shareable dir.
        try
        {
          if (FileSystem.exists(path))
            FileSystem.deleteFile(path);
        }
        catch (_:Dynamic) {}
      }
    }
    pruneDirectory(directory);
  }
  static function pruneDirectory(directory:String, ?keepFileName:String, ?nowMs:Float):Void
  {
    if (directory == null || directory == "" || !FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
      return;
    final now:Float = nowMs == null ? Date.now().getTime() : nowMs;
    final cutoff:Float = now - MAX_LOG_AGE_DAYS * DAY_MS;
    final files:Array<ManagedLogFile> = [];
    for (name in FileSystem.readDirectory(directory))
    {
      if (!isManagedLogFile(name))
        continue;
      final path:String = Path.join([directory, name]);
      if (FileSystem.isDirectory(path))
        continue;
      try
      {
        final stat = FileSystem.stat(path);
        final modified:Float = stat.mtime.getTime();
        if (name != keepFileName && modified > 0.0 && modified < cutoff)
        {
          try
          {
            FileSystem.deleteFile(path);
          }
          catch (_:Dynamic) {}
          if (!FileSystem.exists(path))
            continue;
        }
        files.push({
          name: name,
          path: path,
          size: Std.int(Math.max(stat.size, 0)),
          modified: modified
        });
      }
      catch (_:Dynamic) {}
    }
    files.sort(function(a:ManagedLogFile, b:ManagedLogFile):Int {
      if (a.modified < b.modified)
        return -1;
      if (a.modified > b.modified)
        return 1;
      if (a.name < b.name)
        return -1;
      if (a.name > b.name)
        return 1;
      return 0;
    });
    var totalBytes:Float = 0.0;
    for (file in files)
      totalBytes += file.size;
    while (files.length > MAX_LOG_FILES || totalBytes > MAX_LOG_TOTAL_BYTES)
    {
      var oldest:Int = 0;
      while (oldest < files.length && files[oldest].name == keepFileName)
        oldest++;
      if (oldest >= files.length)
        break;
      final victim:ManagedLogFile = files[oldest];
      try
      {
        FileSystem.deleteFile(victim.path);
      }
      catch (_:Dynamic) {}
      if (FileSystem.exists(victim.path))
        break;
      totalBytes -= victim.size;
      files.splice(oldest, 1);
    }
  }
  static function isManagedLogFile(name:String):Bool
  {
    final extension:String = Path.extension(name).toLowerCase();
    return extension == "log" || extension == "txt";
  }
  #end
}
#if sys
private typedef ManagedLogFile =
{
  var name:String;
  var path:String;
  var size:Int;
  var modified:Float;
}
#end
