package backend;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Builds and writes the crash-bundle `.zip` (TODO.md §19 "Crash bundle
 * export").
 *
 * This module is deliberately Flixel-free, exactly like
 * `backend.SettingsBackupCodec`: the engine glue that *collects* the crash
 * text, mod list, `pack.json` files, prefs and screenshot lives in
 * `backend.CrashBundle`, while everything here is pure data work. That keeps
 * the archive format, its size caps and its retention rules runnable in the
 * Haxe interpreter through `tests/haxe/CrashBundleSpec.hx`, with no game
 * haxelibs.
 *
 * Safety rules (the bundle is opened by support volunteers, and it is built
 * while the engine is already crashing):
 *
 * 1. Every entry name goes through {@link backend.ModPathPolicy} — the same
 *    policy the mod *importer* uses — so a mod folder with a hostile name can
 *    never put `../` or absolute paths into the archive.
 * 2. Per-entry, per-bundle and entry-count caps keep a broken/huge file from
 *    turning the bundle into a memory bomb. Oversized or unsafe entries are
 *    skipped and listed in the manifest, never silently dropped.
 * 3. Writing is atomic (temp file + rename) and old bundles are pruned, so a
 *    crash loop cannot fill the disk with `.zip` files.
 * 4. Nothing here throws for bad input: `build()` skips what it cannot use
 *    and `writeBytes()` reports failures through its result.
 */
class CrashBundleWriter
{
  /** Value of the `format` marker in `bundle.json`. */
  public static inline var FORMAT_ID:String = 'phoenix-crash-bundle';

  /** Format this build writes. */
  public static inline var FORMAT_VERSION:Int = 1;

  /** Prefix of every bundle file name (also used to find old bundles). */
  public static inline var BUNDLE_PREFIX:String = 'FNF-Phoenix-Engine_crash-bundle_';

  /** Largest single entry accepted, in bytes (a 4K screenshot fits). */
  public static inline var MAX_ENTRY_BYTES:Int = 8 * 1024 * 1024;

  /** Largest total uncompressed payload accepted, in bytes. */
  public static inline var MAX_BUNDLE_BYTES:Int = 32 * 1024 * 1024;

  /** Largest number of entries accepted (manifest included). */
  public static inline var MAX_ENTRY_COUNT:Int = 512;

  /** Bundles kept in the crash folder; older ones are pruned. */
  public static inline var MAX_BUNDLES_KEPT:Int = 3;

  /** Deflate level for text entries; screenshots are already compressed. */
  static inline final COMPRESS_LEVEL:Int = 6;

  /**
   * Builds the `.zip` bytes from already-collected entries.
   *
   * A `bundle.json` manifest is prepended: it carries `info` (engine version,
   * target, mod list, ... supplied by the caller) plus the final file list and
   * the reasons entries were skipped. Unsafe, duplicate or oversized entries
   * are skipped instead of failing the whole bundle.
   *
   * @param files collected entries, e.g. `crash.txt`, `modsList.txt`, ...
   * @param info  extra manifest fields (engine, target, createdAt, ...)
   * @return the archive bytes plus the manifest's file/skip lists
   */
  public static function build(files:Array<CrashBundleFile>, ?info:Dynamic):CrashBundleBuild
  {
    var skipped:Array<String> = [];
    var kept:Array<CrashBundleFile> = [];
    var seen:Map<String, Bool> = new Map();
    var total:Int = 0;

    if (files != null)
    {
      for (file in files)
      {
        if (file == null || file.data == null)
          continue;

        var name:Null<String> = ModPathPolicy.normalizeRelative(file.name);
        if (name == null)
        {
          skipped.push('unsafe entry name: "${file.name}"');
          continue;
        }

        var key:String = name.toLowerCase();
        if (seen.exists(key))
        {
          skipped.push('duplicate entry: "$name"');
          continue;
        }

        if (file.data.length > MAX_ENTRY_BYTES)
        {
          skipped.push('"$name" is too large (${file.data.length} bytes, limit $MAX_ENTRY_BYTES)');
          continue;
        }
        if (kept.length + 1 >= MAX_ENTRY_COUNT) // +1 reserves room for the manifest
        {
          skipped.push('"$name" skipped: too many entries (limit $MAX_ENTRY_COUNT)');
          continue;
        }
        if (total + file.data.length > MAX_BUNDLE_BYTES)
        {
          skipped.push('"$name" skipped: bundle would exceed $MAX_BUNDLE_BYTES bytes');
          continue;
        }

        seen.set(key, true);
        total += file.data.length;
        kept.push({name: name, data: file.data});
      }
    }

    // The manifest describes the final archive, including itself.
    var manifestFiles:Array<Dynamic> = [{name: 'bundle.json', bytes: 0}];
    for (file in kept)
      manifestFiles.push({name: file.name, bytes: file.data.length});

    var manifest:Dynamic = {};
    if (info != null)
      for (field in Reflect.fields(info))
        Reflect.setField(manifest, field, Reflect.field(info, field));
    Reflect.setField(manifest, 'format', FORMAT_ID);
    Reflect.setField(manifest, 'formatVersion', FORMAT_VERSION);
    Reflect.setField(manifest, 'files', manifestFiles);
    Reflect.setField(manifest, 'skipped', skipped);

    // The manifest lists its own size, which depends on the encoded text.
    // Re-encode until the size stabilizes (the digit count settles in a pass
    // or two), so the written bundle.json and the returned list agree.
    var manifestBytes:Bytes = Bytes.ofString(haxe.Json.stringify(manifest, null, '  '));
    for (_ in 0...4)
    {
      if (manifestFiles[0].bytes == manifestBytes.length)
        break;
      manifestFiles[0].bytes = manifestBytes.length;
      manifestBytes = Bytes.ofString(haxe.Json.stringify(manifest, null, '  '));
    }

    var entries:haxe.ds.List<haxe.zip.Entry> = new haxe.ds.List();
    entries.add(makeEntry('bundle.json', manifestBytes));
    for (file in kept)
      entries.add(makeEntry(file.name, file.data));

    var output:BytesOutput = new BytesOutput();
    new haxe.zip.Writer(output).write(entries);

    return {bytes: output.getBytes(), files: manifestFiles, skipped: skipped};
  }

  /**
   * Builds and writes a bundle into `directory` (normally `crash/`).
   *
   * @return where the bundle landed, or the reason it could not be written
   */
  public static function write(directory:String, files:Array<CrashBundleFile>, ?info:Dynamic, ?stamp:Date):CrashBundleWriteResult
  {
    var built:CrashBundleBuild = build(files, info);
    var result:CrashBundleWriteResult = writeBytes(directory, built.bytes, stamp);
    result.files = built.files.length;
    return result;
  }

  /** Suggested bundle file name for a moment in time (defaults to now). */
  public static function fileName(?stamp:Date):String
  {
    var date:Date = stamp == null ? Date.now() : stamp;
    return BUNDLE_PREFIX + DateTools.format(date, '%Y-%m-%d_%H-%M-%S') + '.zip';
  }

  /**
   * Writes already-built archive bytes next to the crash log, atomically, and
   * prunes old bundles. Never throws: failures come back in the result so the
   * crash handler can carry on.
   */
  public static function writeBytes(directory:String, bytes:Bytes, ?stamp:Date):CrashBundleWriteResult
  {
    var result:CrashBundleWriteResult = {ok: false, path: '', files: 0, bytes: 0, error: ''};
    #if sys
    if (bytes == null || bytes.length == 0)
    {
      result.error = 'The crash bundle is empty.';
      return result;
    }

    try
    {
      var dir:String = trimSlashes(directory == null || directory.length == 0 ? 'crash' : directory);
      if (!FileSystem.exists(dir))
        FileSystem.createDirectory(dir);
      if (!FileSystem.isDirectory(dir))
        throw '"$dir" is not a directory.';

      var name:String = uniqueName(dir, fileName(stamp));
      var path:String = dir + '/' + name;
      var temp:String = path + '.tmp';

      // Atomic-ish write: a half-written bundle from a second crash must never
      // masquerade as a complete one. rename() replaces on POSIX; on Windows
      // the target does not exist yet (uniqueName), so it succeeds too.
      File.saveBytes(temp, bytes);
      try
      {
        FileSystem.rename(temp, path);
      }
      catch (renameError:Dynamic)
      {
        // Locked folder / cross-mount rename: fall back to a direct write.
        File.saveBytes(path, bytes);
        try
        {
          if (FileSystem.exists(temp))
            FileSystem.deleteFile(temp);
        }
        catch (cleanupError:Dynamic) {}
      }

      result.ok = true;
      result.path = path;
      result.bytes = bytes.length;
      prune(dir);
    }
    catch (e:Dynamic)
    {
      result.ok = false;
      result.error = describeError(e);
    }
    #else
    result.error = 'Crash bundles cannot be written on this target (no filesystem).';
    #end
    return result;
  }

  /**
   * Keeps only the newest {@link MAX_BUNDLES_KEPT} bundles in `directory` and
   * removes leftover `.tmp` files from interrupted writes. Bundle names carry
   * a sortable timestamp, so a lexical sort is enough.
   */
  public static function prune(directory:String):Void
  {
    #if sys
    try
    {
      if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
        return;

      var bundles:Array<String> = [];
      for (name in FileSystem.readDirectory(directory))
      {
        if (!StringTools.startsWith(name, BUNDLE_PREFIX))
          continue;
        var path:String = directory + '/' + name;
        if (FileSystem.isDirectory(path))
          continue;
        if (StringTools.endsWith(name, '.zip'))
          bundles.push(name);
        else if (StringTools.endsWith(name, '.tmp'))
          FileSystem.deleteFile(path); // interrupted write from an earlier crash
      }

      if (bundles.length <= MAX_BUNDLES_KEPT)
        return;

      bundles.sort(Reflect.compare);
      var remove:Int = bundles.length - MAX_BUNDLES_KEPT;
      for (i in 0...remove)
        FileSystem.deleteFile(directory + '/' + bundles[i]);
    }
    catch (e:Dynamic) {} // retention is best-effort; never break the crash path
    #end
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  /** Wraps bytes as a zip entry, deflating everything but media files. */
  static function makeEntry(name:String, data:Bytes):haxe.zip.Entry
  {
    var entry:haxe.zip.Entry = {
      fileName: name,
      fileSize: data.length,
      fileTime: Date.now(),
      compressed: false,
      dataSize: data.length,
      data: data,
      // The zip CRC32 covers the *uncompressed* data and must be set before
      // Tools.compress(), or haxe.zip.Writer refuses the entry.
      crc32: haxe.crypto.Crc32.make(data)
    };

    if (!isAlreadyCompressed(name) && data.length > 0)
    {
      try
      {
        haxe.zip.Tools.compress(entry, COMPRESS_LEVEL);
      }
      catch (e:Dynamic)
      {
        // No zlib on some exotic target: a stored entry is still a valid zip.
        entry.compressed = false;
        entry.data = data;
        entry.dataSize = data.length;
      }
    }
    return entry;
  }

  /** Media formats that would only waste CPU if deflated again. */
  static function isAlreadyCompressed(name:String):Bool
  {
    return switch (Path.extension(name).toLowerCase())
    {
      case 'png' | 'jpg' | 'jpeg' | 'gif' | 'webp' | 'ogg' | 'mp3' | 'zip': true;
      case _: false;
    }
  }

  #if sys
  /** Finds a non-colliding bundle name (`..._2.zip`, `..._3.zip`, ...). */
  static function uniqueName(directory:String, name:String):String
  {
    if (!FileSystem.exists(directory + '/' + name))
      return name;

    var base:String = name.substr(0, name.length - 4); // strip ".zip"
    var suffix:Int = 2;
    while (FileSystem.exists(directory + '/' + base + '-' + suffix + '.zip') && suffix < 1000)
      suffix++;
    return base + '-' + suffix + '.zip';
  }

  static function trimSlashes(path:String):String
  {
    var value:String = path;
    while (StringTools.endsWith(value, '/') || StringTools.endsWith(value, '\\'))
      value = value.substr(0, value.length - 1);
    return value;
  }
  #end

  static function describeError(e:Dynamic):String
  {
    if (e == null)
      return 'Unknown error.';
    if (Std.isOfType(e, String))
      return cast e;
    var message:Dynamic = Reflect.field(e, 'message');
    if (message != null && Std.isOfType(message, String))
      return cast message;
    return Std.string(e);
  }
}

/** One collected file before it goes into the archive. */
typedef CrashBundleFile =
{
  /** Archive-relative name, e.g. `mods/<folder>/pack.json`. */
  var name:String;

  /** File contents. */
  var data:Bytes;
}

/** Result of {@link CrashBundleWriter.build}. */
typedef CrashBundleBuild =
{
  /** The complete `.zip` archive. */
  var bytes:Bytes;

  /** Final entry list (`{name, bytes}`), manifest included. */
  var files:Array<Dynamic>;

  /** Human-readable reasons entries were left out. */
  var skipped:Array<String>;
}

/** Result of {@link CrashBundleWriter.write} / `writeBytes`. */
typedef CrashBundleWriteResult =
{
  /** `true` when the bundle was written. */
  var ok:Bool;

  /** Path of the written bundle ('' when `ok` is false). */
  var path:String;

  /** Number of entries in the archive (manifest included). */
  var files:Int;

  /** Size of the `.zip` in bytes. */
  var bytes:Int;

  /** Failure reason ('' when `ok` is true). */
  var error:String;
}
