package tjson;

using StringTools;

/**
 * Minimal `tjson.TJSON` double for `ModPackHealthSpec`: accepts the relaxed JSON
 * the real library accepts (comments, trailing commas) and refuses a document
 * with a doubled or dangling comma, so the spec can exercise both the "parses"
 * and the "invalid pack.json" paths without pulling in the haxelib.
 */
class TJSON
{
	static inline function isSpace(code:Int):Bool
		return code == ' '.code || code == '\n'.code || code == '\t'.code || code == '\r'.code;

	public static function parse(text:String):Dynamic
	{
		var cleaned:StringBuf = new StringBuf();
		var inString:Bool = false;
		var escaped:Bool = false;
		var index:Int = 0;
		while(index < text.length)
		{
			var char:String = text.charAt(index);
			if(!inString && char == '/' && index + 1 < text.length)
			{
				var next:String = text.charAt(index + 1);
				if(next == '/')
				{
					while(index < text.length && text.charAt(index) != '\n') index++;
					continue;
				}
			}
			if(inString)
			{
				if(escaped) escaped = false;
				else if(char == '\\') escaped = true;
				else if(char == '"') inString = false;
			}
			else if(char == '"') inString = true;
			cleaned.add(char);
			index++;
		}

		var source:String = cleaned.toString();
		var out:StringBuf = new StringBuf();
		var previous:Int = -1;
		for(i in 0...source.length)
		{
			var code:Int = source.charCodeAt(i);
			if(code == ','.code)
			{
				if(previous == ','.code || previous == '{'.code || previous == '['.code) throw 'Unexpected comma';
			}
			if((code == '}'.code || code == ']'.code) && previous == ','.code)
			{
				// A trailing comma is legal in the real library: drop the comma
				// (and the whitespace between it and the bracket).
				var kept:String = out.toString();
				var end:Int = kept.length;
				while(end > 0 && isSpace(kept.charCodeAt(end - 1))) end--;
				out = new StringBuf();
				out.add(kept.substr(0, Std.int(Math.max(0, end - 1))));
			}
			if(!isSpace(code)) previous = code;
			out.add(source.charAt(i));
		}
		return haxe.Json.parse(out.toString());
	}
}
