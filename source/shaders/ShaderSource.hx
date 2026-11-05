package shaders;

#if (sys && MODS_ALLOWED)
import sys.FileSystem;
import sys.io.File;
#end

import backend.Paths;
import backend.Mods;
import flixel.FlxG;

/** Loads mod GLSL sources and expands shader imports. */
class ShaderSource
{
	/**
	 * Loads a fragment and optional vertex shader from a mod's shaders folder.
	 * Imports use `#pragma include "file.glsl"` (also `#pragma import` or `#include`).
	 */
	public static function load(name:String):Array<String>
	{
		if (!isSafePath(name)) return null;

		#if (sys && MODS_ALLOWED)
		for (folder in getShaderFolders())
		{
			if (!FileSystem.exists(folder)) continue;

			final fragPath = folder + name + '.frag';
			final vertPath = folder + name + '.vert';
			final hasFrag = FileSystem.exists(fragPath);
			final hasVert = FileSystem.exists(vertPath);
			if (!hasFrag && !hasVert) continue;

			try
			{
				final frag = hasFrag ? expandImports(File.getContent(fragPath), folder, []) : null;
				final vert = hasVert ? expandImports(File.getContent(vertPath), folder, []) : null;
				return [frag, vert];
			}
			catch (error:Dynamic)
			{
				FlxG.log.warn('Could not load shader "$name": $error');
				return null;
			}
		}
		#end
		return null;
	}

	#if (sys && MODS_ALLOWED)
	static function getShaderFolders():Array<String>
	{
		final folders:Array<String> = [Paths.mods('shaders/')];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			folders.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for (mod in Mods.getGlobalMods())
			folders.insert(0, Paths.mods(mod + '/shaders/'));
		return folders;
	}

	static function expandImports(source:String, folder:String, stack:Array<String>):String
	{
		final importPattern = ~/^\s*#(?:pragma\s+(?:include|import)|include)\s+["<]([^">]+)[">].*$/gm;
		var result = source;
		var match = importPattern.match(result);
		while (match)
		{
			final importName = importPattern.matched(1);
			if (!isSafePath(importName)) throw 'Unsafe shader import path "$importName"';

			final candidates = [folder + importName, folder + 'include/' + importName];
			var importPath:String = null;
			for (candidate in candidates)
			{
				if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate))
				{
					importPath = candidate;
					break;
				}
			}
			if (importPath == null) throw 'Shader import "$importName" was not found';
			if (stack.indexOf(importPath) >= 0) throw 'Circular shader import "$importName"';

			final imported = expandImports(File.getContent(importPath), folder, stack.concat([importPath]));
			final line = importPattern.matched(0);
			result = StringTools.replace(result, line, imported);
			match = importPattern.match(result);
		}
		return result;
	}
	#end

	static function isSafePath(path:String):Bool
	{
		if (path == null || path.length == 0 || StringTools.startsWith(path, '/') || path.indexOf('\\') >= 0)
			return false;
		for (part in path.split('/'))
			if (part == '..' || part == '.') return false;
		return true;
	}
}
