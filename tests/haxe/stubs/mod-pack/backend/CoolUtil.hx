package backend;

import sys.io.File;

using StringTools;

/** `backend.CoolUtil` double for `ModPackHealthSpec`: the spec never reads a list. */
class CoolUtil
{
	public static function coolTextFile(path:String):Array<String>
	{
		var out:Array<String> = [];
		if(!sys.FileSystem.exists(path)) return out;
		for(line in File.getContent(path).split('\n')) out.push(line.trim());
		return out;
	}
}
