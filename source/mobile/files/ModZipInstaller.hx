/*
 * Copyright (C) 2026 Phoenix Engine Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile.files;

import backend.ModPathPolicy;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/** One entry described by the zip central directory. */
typedef ModZipEntry =
{
	/** Raw entry name as stored in the archive. */
	var name:String;

	/** Path relative to the mod root (wrapper folder and staging already removed). */
	var path:String;

	/** Whether the entry is a directory (`name` ends with a separator). */
	var directory:Bool;

	/** Zip compression method: 0 = stored, 8 = deflate. */
	var compression:Int;

	/** Compressed size in bytes (kept as Float so Zip64 fields cannot overflow). */
	var compressedSize:Float;

	/** Uncompressed size in bytes. */
	var uncompressedSize:Float;

	/** Offset of the local file header inside the archive. */
	var localOffset:Float;
}

/** Result of {@link ModZipInstaller.importZip}. */
typedef ModZipInstallResult =
{
	/** `true` when the mod was fully extracted, validated and moved into place. */
	var ok:Bool;

	/** Folder created under `mods/` (`` when `ok` is false). */
	var folder:String;

	/** `pack.json` name, when it declares one. */
	var name:String;

	/** Number of files written. */
	var files:Int;

	/** Human readable failure reason (`` when `ok` is true). */
	var error:String;
}

/** Dry-run metadata returned by {@link ModZipInstaller.inspect}. */
typedef ModZipInspection =
{
	var ok:Bool;

	/** Human readable failure reason (`` when `ok` is true). */
	var error:String;

	/** Folder name the import would create. */
	var folder:String;

	/** Number of files the archive would write. */
	var files:Int;

	/** `true` when `mods/<folder>` already exists and would be replaced. */
	var conflicts:Bool;
}

/** Where the mod content starts inside the archive and what gets skipped. */
typedef ModZipLayout =
{
	/** Single top-level folder wrapping the mod (`` when `pack.json` is at the root). */
	var prefix:String;

	/** Entries outside the mod root, skipped instead of failing the import. */
	var ignored:Array<String>;
}

#if sys
/**
 * Installs a mod from a `.zip` archive picked through the Storage Access
 * Framework (or the desktop file dialog) - the only practical install path on
 * a phone without a file manager.
 *
 * The importer never trusts an archive:
 *
 * 1. It parses the zip **central directory** (the authoritative record) instead
 *    of blindly walking local headers, so entry names and sizes are known
 *    before a single byte is decompressed.
 * 2. Every entry is filtered through {@link backend.ModPathPolicy}: absolute
 *    paths, `..` segments, control characters, Windows-illegal names and
 *    Zip-slip style tricks are rejected, not rewritten. Encrypted entries,
 *    symbolic links and unsupported compression methods are rejected too.
 * 3. Archive size, single-entry size, total expanded size and entry count are
 *    capped, so a "zip bomb" fails before it can exhaust device memory.
 * 4. Content is extracted into a hidden staging folder inside `mods/`, and
 *    `pack.json` is only accepted after it exists at the mod root and parses;
 *    the staging folder is then swapped into `mods/<folder>/`. A failed or
 *    interrupted import therefore never leaves a half-installed mod behind
 *    (or enables one).
 *
 * Enabling the mod (`modsList.txt`) is the caller's job, because it also owns
 * the UI reload - see `backend.Mods.registerInstalledMod`.
 */
class ModZipInstaller
{
	/** Largest `.zip` accepted, in bytes. */
	public static inline final MAX_ARCHIVE_BYTES:Int = 512 * 1024 * 1024;

	/** Largest single decompressed file accepted, in bytes. */
	public static inline final MAX_ENTRY_BYTES:Float = 128 * 1024 * 1024;

	/** Largest total decompressed size accepted, in bytes. */
	public static inline final MAX_EXPANDED_BYTES:Float = 1024 * 1024 * 1024;

	/** Largest number of central-directory entries accepted. */
	public static inline final MAX_ENTRY_COUNT:Int = 4096;

	/** Prefix of the hidden staging folder created inside `mods/`. */
	public static inline final STAGING_PREFIX:String = '.phoenix-import-';

	static inline final ZIP_LOCAL_HEADER:Int = 0x04034B50;
	static inline final ZIP_CENTRAL_HEADER:Int = 0x02014B50;
	static inline final ZIP_END_OF_CENTRAL_DIRECTORY:Int = 0x06054B50;
	static inline final ZIP64_EXTRA_FIELD:Int = 0x0001;
	static inline final ZIP_UNKNOWN_SIZE:Float = 4294967295.0;
	static inline final UNIX_FILE_TYPE_MASK:Int = 0xF000;
	static inline final UNIX_SYMBOLIC_LINK:Int = 0xA000;
	static inline final INFLATE_CHUNK:Int = 64 * 1024;

	/**
	 * Reads the central directory of `data` without touching the filesystem.
	 *
	 * @param data        raw `.zip` bytes
	 * @param displayName name of the picked file (used for the folder name)
	 * @param modsDirectory directory that will receive the mod (defaults to `mods`)
	 * @param folderName  explicit folder name, overriding the archive/file name
	 * @return dry-run metadata; `error` explains why an archive is rejected
	 */
	public static function inspect(data:Bytes, ?displayName:String, ?modsDirectory:String = 'mods', ?folderName:String = null):ModZipInspection
	{
		try
		{
			var plan:ModZipPlan = buildPlan(data, displayName, folderName);
			var directory:String = trimSlashes(modsDirectory == null || modsDirectory.length == 0 ? 'mods' : modsDirectory);
			var target:String = directory + '/' + plan.folder;
			var conflicts:Bool = FileSystem.exists(target) && FileSystem.isDirectory(target);
			return {
				ok: true,
				error: '',
				folder: plan.folder,
				files: countFiles(plan.entries),
				conflicts: conflicts
			};
		}
		catch(e:Dynamic)
		{
			return {ok: false, error: describeError(e), folder: '', files: 0, conflicts: false};
		}
	}

	/**
	 * Extracts `data` into `mods/<folder>/` and validates its `pack.json`.
	 *
	 * Extraction happens in a hidden staging folder, so a rejected archive
	 * never leaves a partial mod behind; only a fully validated mod is moved
	 * into place.
	 *
	 * @param data            raw `.zip` bytes, e.g. `PickedFile.data`
	 * @param displayName     picked file name, used to derive the folder name
	 * @param modsDirectory   destination root (defaults to `mods`)
	 * @param folderName      explicit folder name, overriding the archive/file name
	 * @param packValidator   extra `pack.json` check; `null` = plain JSON object check
	 * @param replaceExisting delete an existing `mods/<folder>/` after the new
	 *                        mod has been extracted and validated
	 */
	public static function importZip(data:Bytes, ?displayName:String, ?modsDirectory:String = 'mods', ?folderName:String = null,
		?packValidator:String->Bool = null, replaceExisting:Bool = false):ModZipInstallResult
	{
		var result:ModZipInstallResult = {ok: false, folder: '', name: '', files: 0, error: ''};
		var staging:String = '';

		try
		{
			var plan:ModZipPlan = buildPlan(data, displayName, folderName);
			var directory:String = trimSlashes(modsDirectory == null || modsDirectory.length == 0 ? 'mods' : modsDirectory);
			if(directory.length == 0) throw 'The mods directory is unavailable.';

			if(!FileSystem.exists(directory)) FileSystem.createDirectory(directory);
			if(!FileSystem.isDirectory(directory)) throw 'The mods directory is unavailable.';

			var target:String = directory + '/' + plan.folder;
			if(FileSystem.exists(target) && !replaceExisting)
				throw 'A mod named "${plan.folder}" is already installed. Replace it or remove it first.';

			staging = createStagingDirectory(directory);
			var files:Int = 0;
			for(entry in plan.entries)
			{
				var destination:Null<String> = ModPathPolicy.resolveInside(staging, entry.path);
				if(destination == null) throw 'Unsafe path in archive: "${entry.name}".';

				if(entry.directory)
				{
					if(!FileSystem.exists(destination)) FileSystem.createDirectory(destination);
					continue;
				}

				var parent:String = haxe.io.Path.directory(destination);
				if(parent.length > 0 && !FileSystem.exists(parent)) FileSystem.createDirectory(parent);
				extractEntry(data, entry, destination);
				files++;
			}

			var packPath:String = staging + '/pack.json';
			if(!FileSystem.exists(packPath) || FileSystem.isDirectory(packPath))
				throw 'The archive has no pack.json at its root, so it is not a mod.';

			var packText:String = File.getContent(packPath);
			if(!validatePack(packText, packValidator))
				throw 'The mod pack.json is not a valid JSON object. Fix the mod, then import it again.';

			if(FileSystem.exists(target)) deleteDirectory(target);
			try
			{
				FileSystem.rename(staging, target);
			}
			catch(e:Dynamic)
			{
				// rename() can fail across mount points or with a locked folder;
				// fall back to a plain copy so the import still completes.
				try
				{
					copyDirectory(staging, target);
					deleteDirectory(staging);
				}
				catch(copyError:Dynamic)
				{
					deleteDirectory(target); // never leave a half-copied mod behind
					throw copyError;
				}
			}
			staging = '';

			result.ok = true;
			result.folder = plan.folder;
			result.name = readPackName(packText);
			result.files = files;
		}
		catch(e:Dynamic)
		{
			if(staging.length > 0)
			{
				try
				{
					deleteDirectory(staging);
				}
				catch(cleanupError:Dynamic) {}
			}
			result.ok = false;
			result.error = describeError(e);
			trace('Mod import failed: ${result.error}');
		}

		return result;
	}

	/**
	 * Builds the entry list of a `.zip` from its central directory.
	 *
	 * Throws a descriptive String for malformed, oversized, encrypted or
	 * traversal-carrying archives. Exposed for tests; importers should use
	 * {@link importZip}.
	 */
	public static function readEntries(data:Bytes):Array<ModZipEntry>
	{
		if(data == null || data.length < 22) throw 'The selected file is not a valid .zip archive.';
		if(data.length > MAX_ARCHIVE_BYTES)
			throw 'The archive is too large (limit ${formatSize(MAX_ARCHIVE_BYTES)}).';

		var end:Int = findEndOfCentralDirectory(data);
		if(end < 0) throw 'The selected file is not a valid .zip archive.';

		var entryCount:Float = data.getUInt16(end + 10);
		var directorySize:Float = readUInt32LE(data, end + 12);
		var directoryOffset:Float = readUInt32LE(data, end + 16);

		if(entryCount >= 65535 || directorySize >= ZIP_UNKNOWN_SIZE || directoryOffset >= ZIP_UNKNOWN_SIZE)
			throw 'Zip64 archives are not supported. Re-save the mod as a standard .zip.';
		if(entryCount > MAX_ENTRY_COUNT) throw 'The archive contains too many files (limit $MAX_ENTRY_COUNT).';
		if(directoryOffset + directorySize > data.length) throw 'The archive is truncated or corrupted.';

		var entries:Array<ModZipEntry> = [];
		var position:Float = directoryOffset;
		var expanded:Float = 0;

		for(i in 0...Std.int(entryCount))
		{
			if(position + 46 > data.length) throw 'The archive central directory is truncated.';
			var offset:Int = Std.int(position);
			if(data.getInt32(offset) != ZIP_CENTRAL_HEADER) throw 'The archive central directory is corrupted.';

			var flags:Int = data.getUInt16(offset + 8);
			var compression:Int = data.getUInt16(offset + 10);
			var compressedSize:Float = readUInt32LE(data, offset + 20);
			var uncompressedSize:Float = readUInt32LE(data, offset + 24);
			var nameLength:Int = data.getUInt16(offset + 28);
			var extraLength:Int = data.getUInt16(offset + 30);
			var commentLength:Int = data.getUInt16(offset + 32);
			var externalAttributes:Float = readUInt32LE(data, offset + 38);
			var localOffset:Float = readUInt32LE(data, offset + 42);
			var nameStart:Int = offset + 46;
			var next:Float = position + 46 + nameLength + extraLength + commentLength;

			if(nameStart + nameLength > data.length || next > data.length)
				throw 'The archive central directory is truncated.';

			var rawName:String = data.getString(nameStart, nameLength);
			if(uncompressedSize >= ZIP_UNKNOWN_SIZE || compressedSize >= ZIP_UNKNOWN_SIZE)
			{
				var sizes:ModZipSizes = readZip64Sizes(data, nameStart + nameLength, extraLength, uncompressedSize, compressedSize);
				uncompressedSize = sizes.uncompressedSize;
				compressedSize = sizes.compressedSize;
			}

			if((flags & 0x0001) != 0) throw 'The archive is encrypted; encrypted mods are not supported.';
			if(compression != 0 && compression != 8)
				throw 'Unsupported compression method ($compression) for "${rawName}".';

			var unixMode:Int = Std.int(externalAttributes / 65536) & 0xFFFF;
			if((unixMode & UNIX_FILE_TYPE_MASK) == UNIX_SYMBOLIC_LINK)
				throw 'The archive contains a symbolic link ("$rawName"), which is not allowed.';

			var path:Null<String> = ModPathPolicy.normalizeRelative(rawName);
			if(path == null) throw 'Unsafe path in archive: "$rawName".';

			var isDirectory:Bool = rawName.endsWith('/') || rawName.endsWith('\\');
			if(!isDirectory && uncompressedSize > MAX_ENTRY_BYTES)
				throw '"$path" is too large (limit ${formatSize(MAX_ENTRY_BYTES)}).';

			expanded += uncompressedSize;
			if(expanded > MAX_EXPANDED_BYTES)
				throw 'The archive expands to more than ${formatSize(MAX_EXPANDED_BYTES)}.';

			entries.push({
				name: rawName,
				path: path,
				directory: isDirectory,
				compression: compression,
				compressedSize: compressedSize,
				uncompressedSize: uncompressedSize,
				localOffset: localOffset
			});
			position = next;
		}

		return entries;
	}

	/**
	 * Decides where the mod starts inside the archive.
	 *
	 * A `pack.json` at the archive root wins. Otherwise the archive must have
	 * exactly one top-level folder holding `pack.json` (the shape most mods are
	 * zipped in); plain files next to that folder (README, LICENSE, ...) are
	 * reported as `ignored`. Anything more ambiguous is rejected instead of
	 * guessing.
	 *
	 * @return the layout, or `null` when no mod root can be found
	 */
	public static function resolveLayout(entries:Array<ModZipEntry>):Null<ModZipLayout>
	{
		var hasRootPack:Bool = false;
		var candidates:Array<String> = [];

		for(entry in entries)
		{
			if(entry.directory) continue;

			var lower:String = entry.path.toLowerCase();
			if(lower == 'pack.json')
			{
				hasRootPack = true;
				continue;
			}

			var slash:Int = lower.indexOf('/');
			if(slash > 0 && slash == lower.lastIndexOf('/') && lower.substr(slash + 1) == 'pack.json')
			{
				var folder:String = entry.path.substr(0, slash);
				if(!candidates.contains(folder)) candidates.push(folder);
			}
		}

		if(hasRootPack) return {prefix: '', ignored: []};
		if(candidates.length != 1) return null;

		var prefix:String = candidates[0];
		var ignored:Array<String> = [];
		for(entry in entries)
		{
			if(entry.path == prefix) continue; // the wrapper folder itself
			if(entry.path.startsWith(prefix + '/')) continue; // part of the mod
			if(entry.directory || entry.path.indexOf('/') >= 0) return null; // ambiguous layout
			ignored.push(entry.path);
		}

		return {prefix: prefix, ignored: ignored};
	}

	/** Default `pack.json` check: plain JSON with an object at the top level. */
	public static function defaultValidatePack(text:String):Bool
	{
		if(text == null) return false;
		var trimmed:String = text.trim();
		if(trimmed.length < 2) return false;

		try
		{
			var parsed:Dynamic = haxe.Json.parse(trimmed);
			if(parsed == null) return false;
			return Reflect.isObject(parsed) && !Std.isOfType(parsed, Array);
		}
		catch(e:Dynamic)
		{
			return false;
		}
	}

	// ------------------------------------------------------------------
	// Planning
	// ------------------------------------------------------------------

	static function buildPlan(data:Bytes, displayName:Null<String>, folderName:Null<String>):ModZipPlan
	{
		var entries:Array<ModZipEntry> = readEntries(data);

		// macOS wraps zipped folders in __MACOSX/ resource forks; they are not
		// part of the mod and would otherwise break layout detection.
		var kept:Array<ModZipEntry> = [];
		var ignored:Array<String> = [];
		for(entry in entries)
		{
			var lower:String = entry.path.toLowerCase();
			var base:String = lower.substr(lower.lastIndexOf('/') + 1);
			if(lower == '__macosx' || lower.startsWith('__macosx/') || base == '.ds_store' || base.startsWith('._'))
			{
				ignored.push(entry.path);
				continue;
			}
			kept.push(entry);
		}

		var layout:Null<ModZipLayout> = resolveLayout(kept);
		if(layout == null)
			throw 'The archive must contain a pack.json at its root, or inside a single top-level folder.';
		for(name in layout.ignored)
			if(!ignored.contains(name)) ignored.push(name);

		var prefix:String = layout.prefix;
		var selected:Array<ModZipEntry> = [];
		var seen:Map<String, Bool> = new Map();
		for(entry in kept)
		{
			if(prefix.length > 0)
			{
				if(entry.path == prefix) continue;
				if(!entry.path.startsWith(prefix + '/')) continue;
				entry.path = entry.path.substr(prefix.length + 1);
			}

			var key:String = entry.path.toLowerCase();
			if(seen.exists(key)) throw 'The archive contains duplicate entries ("${entry.path}").';
			seen.set(key, true);

			// Defense in depth: the stripped path is what gets written to disk.
			if(ModPathPolicy.normalizeRelative(entry.path) != entry.path)
				throw 'Unsafe path in archive: "${entry.name}".';
			selected.push(entry);
		}

		return {folder: chooseFolderName(folderName, prefix, displayName), entries: selected, ignored: ignored.length};
	}

	static function chooseFolderName(requested:Null<String>, prefix:String, displayName:Null<String>):String
	{
		var candidates:Array<Null<String>> = [requested, prefix, displayName];
		for(candidate in candidates)
		{
			if(candidate == null || candidate.trim().length == 0) continue;
			var name:String = ModPathPolicy.sanitizeFolderName(candidate);
			if(ModPathPolicy.isSafeFolderName(name)) return name;
		}
		return 'imported_mod';
	}

	static function countFiles(entries:Array<ModZipEntry>):Int
	{
		var total:Int = 0;
		for(entry in entries)
			if(!entry.directory) total++;
		return total;
	}

	// ------------------------------------------------------------------
	// Extraction
	// ------------------------------------------------------------------

	static function extractEntry(data:Bytes, entry:ModZipEntry, destination:String):Void
	{
		var offset:Int = Std.int(entry.localOffset);
		if(offset < 0 || offset + 30 > data.length) throw 'Corrupt local header for "${entry.path}".';
		if(data.getInt32(offset) != ZIP_LOCAL_HEADER) throw 'Corrupt local header for "${entry.path}".';

		var nameLength:Int = data.getUInt16(offset + 26);
		var extraLength:Int = data.getUInt16(offset + 28);
		var nameStart:Int = offset + 30;
		var dataStart:Float = nameStart + nameLength + extraLength;
		if(nameStart + nameLength > data.length || dataStart > data.length)
			throw 'Corrupt local header for "${entry.path}".';

		// The central directory is authoritative; a local header that disagrees
		// means the archive was crafted to extract something else than validated.
		var localName:String = data.getString(nameStart, nameLength);
		if(localName != entry.name) throw 'Archive entry "${entry.name}" does not match its local header.';

		var compressedSize:Int = Std.int(entry.compressedSize);
		if(dataStart + compressedSize > data.length) throw 'The archive is truncated ("${entry.path}").';
		var start:Int = Std.int(dataStart);

		var contents:Bytes;
		if(entry.compression == 0)
		{
			if(entry.uncompressedSize != 0 && entry.compressedSize != entry.uncompressedSize)
				throw 'Stored entry "${entry.path}" has inconsistent sizes.';
			contents = Bytes.alloc(compressedSize);
			if(compressedSize > 0) contents.blit(0, data, start, compressedSize);
		}
		else
		{
			var input:BytesInput = new BytesInput(data, start, compressedSize);
			var inflate:InflateImpl = new InflateImpl(input, false, false);
			var buffer:BytesBuffer = new BytesBuffer();
			var chunk:Bytes = Bytes.alloc(INFLATE_CHUNK);
			var written:Float = 0;
			var done:Bool = false;

			while(!done)
			{
				var read:Int = 0;
				try
				{
					read = inflate.readBytes(chunk, 0, chunk.length);
				}
				catch(e:Dynamic)
				{
					throw 'Could not decompress "${entry.path}": ${describeError(e)}';
				}

				if(read > 0)
				{
					written += read;
					if(written > MAX_ENTRY_BYTES)
						throw '"${entry.path}" expands to more than ${formatSize(MAX_ENTRY_BYTES)}.';
					buffer.addBytes(chunk, 0, read);
				}
				if(read < chunk.length) done = true;
			}

			contents = buffer.getBytes();
			if(contents.length != Std.int(entry.uncompressedSize))
				throw 'Corrupt or truncated data for "${entry.path}".';
		}

		var parent:String = haxe.io.Path.directory(destination);
		if(parent.length > 0 && !FileSystem.exists(parent)) FileSystem.createDirectory(parent);
		File.saveBytes(destination, contents);
	}

	// ------------------------------------------------------------------
	// Filesystem helpers
	// ------------------------------------------------------------------

	static function createStagingDirectory(directory:String):String
	{
		// A timestamp keeps leftover folders readable on a device, the random
		// suffix avoids collisions between two imports in the same second.
		var now:Date = Date.now();
		var stamp:String = now.getFullYear()
			+ StringTools.lpad(Std.string(now.getMonth() + 1), '0', 2)
			+ StringTools.lpad(Std.string(now.getDate()), '0', 2) + '-'
			+ StringTools.lpad(Std.string(now.getHours()), '0', 2)
			+ StringTools.lpad(Std.string(now.getMinutes()), '0', 2)
			+ StringTools.lpad(Std.string(now.getSeconds()), '0', 2);
		var staging:String = directory + '/' + STAGING_PREFIX + stamp + '-' + Std.random(100000);

		var attempts:Int = 0;
		while(FileSystem.exists(staging) && attempts < 10)
		{
			staging = directory + '/' + STAGING_PREFIX + stamp + '-' + Std.random(100000);
			attempts++;
		}

		FileSystem.createDirectory(staging);
		return staging;
	}

	static function deleteDirectory(path:String):Void
	{
		if(!FileSystem.exists(path)) return;

		if(!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}

		for(name in FileSystem.readDirectory(path))
			deleteDirectory(path + '/' + name);
		FileSystem.deleteDirectory(path);
	}

	static function copyDirectory(from:String, to:String):Void
	{
		if(!FileSystem.exists(to)) FileSystem.createDirectory(to);

		for(name in FileSystem.readDirectory(from))
		{
			var source:String = from + '/' + name;
			var destination:String = to + '/' + name;
			if(FileSystem.isDirectory(source)) copyDirectory(source, destination);
			else File.copy(source, destination);
		}
	}

	static function trimSlashes(path:String):String
	{
		var value:String = path;
		while(value.endsWith('/') || value.endsWith('\\')) value = value.substr(0, value.length - 1);
		return value;
	}

	// ------------------------------------------------------------------
	// Archive parsing helpers
	// ------------------------------------------------------------------

	static function findEndOfCentralDirectory(data:Bytes):Int
	{
		var last:Int = data.length - 22;
		var earliest:Int = last - 65535;
		if(earliest < 0) earliest = 0;

		var position:Int = last;
		while(position >= earliest)
		{
			if(data.getInt32(position) == ZIP_END_OF_CENTRAL_DIRECTORY)
			{
				var commentLength:Int = data.getUInt16(position + 20);
				if(position + 22 + commentLength <= data.length) return position;
			}
			position--;
		}
		return -1;
	}

	static function readUInt32LE(data:Bytes, position:Int):Float
	{
		var low:Int = data.getUInt16(position);
		var high:Int = data.getUInt16(position + 2);
		return low + (high * 65536.0);
	}

	static function readUInt64LE(data:Bytes, position:Int):Float
		return readUInt32LE(data, position) + (readUInt32LE(data, position + 4) * 4294967296.0);

	/** Reads the Zip64 extra field when a size field overflowed to `0xFFFFFFFF`. */
	static function readZip64Sizes(data:Bytes, extraStart:Int, extraLength:Int, uncompressedSize:Float,
		compressedSize:Float):ModZipSizes
	{
		var position:Int = extraStart;
		var end:Int = extraStart + extraLength;

		while(position + 4 <= end)
		{
			var tag:Int = data.getUInt16(position);
			var length:Int = data.getUInt16(position + 2);
			position += 4;
			if(position + length > end) break;

			if(tag == ZIP64_EXTRA_FIELD)
			{
				var field:Int = position;
				if(uncompressedSize >= ZIP_UNKNOWN_SIZE && field + 8 <= position + length)
				{
					uncompressedSize = readUInt64LE(data, field);
					field += 8;
				}
				if(compressedSize >= ZIP_UNKNOWN_SIZE && field + 8 <= position + length)
					compressedSize = readUInt64LE(data, field);
			}

			position += length;
		}

		return {uncompressedSize: uncompressedSize, compressedSize: compressedSize};
	}

	static function validatePack(text:String, validator:String->Bool):Bool
	{
		if(text == null) return false;
		var trimmed:String = text.trim();
		if(trimmed.length < 2) return false;
		return validator != null ? validator(trimmed) : defaultValidatePack(trimmed);
	}

	static function readPackName(text:String):String
	{
		try
		{
			var parsed:Dynamic = haxe.Json.parse(text);
			var name:Dynamic = Reflect.field(parsed, 'name');
			if(Std.isOfType(name, String)) return (cast name:String).trim();
		}
		catch(e:Dynamic) {}

		return '';
	}

	static function formatSize(bytes:Float):String
	{
		if(bytes >= 1024.0 * 1024.0 * 1024.0) return '${Std.int(bytes / (1024.0 * 1024.0 * 1024.0))} GB';
		return '${Std.int(bytes / (1024.0 * 1024.0))} MB';
	}

	static function describeError(e:Dynamic):String
	{
		if(e == null) return 'Unknown error.';
		if(Std.isOfType(e, String)) return cast e;

		var message:Dynamic = Reflect.field(e, 'message');
		if(message != null && Std.isOfType(message, String)) return cast message;

		return Std.string(e);
	}
}

private typedef ModZipPlan =
{
	var folder:String;
	var entries:Array<ModZipEntry>;
	var ignored:Int;
}

private typedef ModZipSizes =
{
	var uncompressedSize:Float;
	var compressedSize:Float;
}
#else
/**
 * Stub for targets without a filesystem (html5/flash): mod folders cannot be
 * written there, so imports always fail with a readable message.
 */
class ModZipInstaller
{
	public static function inspect(data:Bytes, ?displayName:String, ?modsDirectory:String = 'mods', ?folderName:String = null):ModZipInspection
	{
		return {ok: false, error: 'Importing mod archives is not supported on this target.', folder: '', files: 0, conflicts: false};
	}

	public static function importZip(data:Bytes, ?displayName:String, ?modsDirectory:String = 'mods', ?folderName:String = null,
		?packValidator:String->Bool = null, replaceExisting:Bool = false):ModZipInstallResult
	{
		return {ok: false, folder: '', name: '', files: 0, error: 'Importing mod archives is not supported on this target.'};
	}
}
#end
