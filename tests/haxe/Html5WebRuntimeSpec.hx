import sys.FileSystem;
import sys.io.File;

/**
 * Regression guards for the HTML5 / WebGL browser runtime:
 *
 * 1. `FlxGame.getTimer()` must never divide `System.getPerformanceCounter()` by
 *    `System.getPerformanceFrequency()` unguarded: Lime returns `0` for both on
 *    HTML5, Flash and AIR (`!(lime_cffi && !macro)`), producing `0 / 0 = NaN`
 *    and freezing `FlxGame.onEnterFrame`'s `_accumulator` on the initial black
 *    fade transition forever.
 * 2. `Paths.initSplashConfig()` and `NoteSplash.setupNoteSplash()` must resolve
 *    note-splash configs from the OpenFL `shared` library on `#if !sys` and
 *    use the local `minFps` / `maxFps` fallback when `config` is null.
 * 3. `TextureBase.__setSamplerState()` must not pass desktop-only
 *    `GL_TEXTURE_LOD_BIAS` (`0x8501 = 34049`) to WebGL/GLES `texParameterf`.
 * 4. `CommitWatermark` and `UpdateChecker` must not set the forbidden
 *    `User-Agent` XHR header on `#if (js && html5)`.
 *
 * Run with `bash tests/haxe/run-html5-web-runtime.sh`.
 */
class Html5WebRuntimeSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	static function text(path:String):String
	{
		check(FileSystem.exists(path), 'missing file: $path');
		return File.getContent(path);
	}

	static function contains(source:String, needle:String, label:String):Void
	{
		check(source.indexOf(needle) >= 0, label);
	}

	static function slice(source:String, start:String, end:String):String
	{
		final from:Int = source.indexOf(start);
		check(from >= 0, 'missing source section: $start');
		final until:Int = source.indexOf(end, from + start.length);
		check(until > from, 'missing end of source section: $end');
		return source.substring(from, until);
	}

	static function flxGameTimerNeverProducesNaNOnWeb():Void
	{
		final flxGame:String = text('source/source-haxelib-patches/flixel/FlxGame.hx');
		final timerSection:String = slice(flxGame, 'static inline function getRawTime():Float', 'private class FlxIntroSplash');

		contains(timerSection, '#if (js && html5)', 'FlxGame timer branches explicitly on HTML5');
		contains(timerSection, 'js.Browser.window.performance.now()', 'FlxGame uses window.performance.now() on HTML5');
		contains(timerSection, '#elseif (lime_cffi && !macro)', 'System.getPerformanceFrequency() is restricted to lime_cffi targets');
		contains(timerSection, 'if (frequency > 0)', 'native counter guards against zero frequency before dividing');
		contains(timerSection, 'Lib.getTimer()', 'FlxGame falls back to openfl.Lib.getTimer() when high-res counters are unavailable');

		final ctorSection:String = slice(flxGame, '_accumulator = _stepMS;', '// Script-level ("global") filters');
		contains(ctorSection, '_startCounter = getRawTime();', 'FlxGame constructor seeds _startCounter from getRawTime()');
	}

	static function noteSplashWorksWithoutSysFilesystem():Void
	{
		final paths:String = text('source/backend/Paths.hx');
		final initCfg:String = slice(paths, 'public static function initSplashConfig(skin:String)', 'var configFile:Array<String> = CoolUtil.coolTextFile(path);');
		contains(initCfg, "Paths.getPath('images/' + skin + '.txt', TEXT, 'shared')",
			'Paths.initSplashConfig resolves noteSplash .txt through the shared OpenFL library on non-sys targets');

		final splash:String = text('source/objects/NoteSplash.hx');
		final setup:String = slice(splash, 'public function setupNoteSplash(', 'public static function getSplashSkinPostfix()');
		contains(setup, 'FlxG.random.int(minFps, maxFps)',
			'NoteSplash.setupNoteSplash uses null-safe minFps/maxFps locals rather than dereferencing config.minFps');
		check(setup.indexOf('FlxG.random.int(config.minFps') < 0,
			'NoteSplash.setupNoteSplash must not dereference config.minFps outside the config != null block');
	}

	static function webglAndXhrGuardsStayInPlace():Void
	{
		final texBase:String = text('source/source-haxelib-patches/openfl/display3D/textures/TextureBase.hx');
		final sampler:String = slice(texBase, 'private function __setSamplerState(state:SamplerState):Bool', 'if (__samplerState == null)');
		contains(sampler, '#if (!js && !html5 && !mobile)',
			'TextureBase guards GL_TEXTURE_LOD_BIAS (34049) away from WebGL and GLES');

		final watermark:String = slice(text('source/debug/CommitWatermark.hx'), 'function performRequest(', 'http.onStatus =');
		contains(watermark, '#if !(js && html5)', 'CommitWatermark skips forbidden User-Agent header on HTML5 XHR');

		final updater:String = slice(text('source/backend/UpdateChecker.hx'), 'final http:Http = new Http(', 'http.onStatus =');
		contains(updater, '#if !(js && html5)', 'UpdateChecker skips forbidden User-Agent header on HTML5 XHR');

		final crash:String = text('source/backend/CrashHandler.hx');
		contains(crash, 'js.Browser.console.error(errorMessage', 'CrashHandler mirrors uncaught errors to browser console on HTML5');
	}

	static function main():Void
	{
		flxGameTimerNeverProducesNaNOnWeb();
		noteSplashWorksWithoutSysFilesystem();
		webglAndXhrGuardsStayInPlace();
		Sys.println('Html5WebRuntimeSpec: PASS');
	}
}
