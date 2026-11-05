package shaders;

import play.PlayState;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

/** Mod-facing runtime shader factory. Shader files live in a mod's `shaders/` folder. */
class FunkinShader
{
	/**
	 * Loads and creates a runtime shader by file name, without the `.frag`/`.vert` suffix.
	 * The fragment file is required for rendering; a vertex file is optional.
	 */
	public static function fromFile(name:String):Dynamic
	{
		#if SHADERS_ALLOWED
		if (PlayState.instance == null || !PlayState.instance.initLuaShader(name)) return null;
		final sources = PlayState.instance.runtimeShaders.get(name);
		if (sources == null) return null;
		return new ErrorHandledRuntimeShader(name, sources[0], sources[1]);
		#else
		return null;
		#end
	}
}
