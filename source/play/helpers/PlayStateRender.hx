package play.helpers;

import backend.ClientPrefs;
import backend.CoolUtil;
import backend.FFmpegLocator;
import backend.Paths;
import backend.RenderPaths;

import play.PlayState;

import utils.DateUtils;

@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateRender
{
	public static function initRender(state:PlayState, renderPath:String = "assets/gameRenders/", ?prefixName:String = null):Void
	{
		#if sys
		// The output folder comes first, before anything that can fail. Players
		// need it even when FFmpeg is missing (Classic Rendering Mode dumps its
		// frames there), and the old code returned early on Windows whenever
		// `ffmpeg.exe` was not in the working directory -- which is exactly why
		// the folder never appeared. `RenderPaths` also anchors relative paths
		// to the game's own folder and creates missing parent folders.
		final renderDirectory:Null<String> = RenderPaths.prepareRenderDirectory(renderPath);
		if (renderDirectory == null)
		{
			failRender('Video rendering was disabled for this song: the render folder "' + renderPath
				+ '" could not be created.\nCheck that the game folder is writable.');
			return;
		}

		// Classic Rendering Mode writes each frame through backend.Screenshot,
		// which creates the per-song folder itself.
		if (ClientPrefs.oldFFmpegMode) return;

		state.ffmpegExists = false;

		if (prefixName == null)
				prefixName = Paths.formatToSongPath(PlayState.SONG.song);
		else if (prefixName.startsWith('/'))
				prefixName = prefixName.substr(1);

		#if desktop
		// `locate()` checks the game folder, the working directory, PATH and the
		// usual package-manager install folders. Haxe quotes the command itself
		// on Windows, so a path with spaces is safe to pass as-is.
		final ffmpeg:Null<String> = FFmpegLocator.locate();
		#else
		// Mobile builds cannot spawn FFmpeg; Rendering Mode there only captures frames.
		final ffmpeg:Null<String> = null;
		#end

		if (ffmpeg == null)
		{
			#if desktop
			failRender('Rendering Mode needs FFmpeg, but it was not found.\n\n'
				+ 'Put ffmpeg.exe next to the game, install it so it lands on your PATH, '
				+ 'or point the PHOENIX_FFMPEG variable at it.\n\n'
				+ 'The song will play normally without being recorded. Renders are saved to:\n'
				+ renderDirectory, true);
			#else
			FlxG.log.warn('Video rendering needs FFmpeg, which is not available on this platform. Use Classic Rendering Mode.');
			#end
			return;
		}

		state.renderWidth = lime.app.Application.current.window.width;
		state.renderHeight = lime.app.Application.current.window.height;
		if (state.renderWidth <= 0 || state.renderHeight <= 0) return;

		var fileName = RenderPaths.joinPath(renderDirectory, prefixName);
		if(FileSystem.exists(fileName + '.mp4')) {
			FlxG.log.warn('Duplicate video found for "$prefixName", adding an anti-dupe suffix.');
			fileName += '-' + DateUtils.cleanedDate;
		}

		try{
			PlayState.process = new Process(ffmpeg, ['-v', 'quiet', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', state.renderWidth + 'x' + state.renderHeight, '-r', Std.string(state.targetFPS), '-i', '-', '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', '-c:v', ClientPrefs.vidEncoder, '-b:v', Std.string(ClientPrefs.renderBitrate * 1000000), fileName + '.mp4']);
			state.ffmpegExists = true;
			FlxG.autoPause = false;
			FlxG.log.add('Rendering with $ffmpeg -> $fileName.mp4');
		}catch(e:Dynamic){
			PlayState.process = null;
			state.ffmpegExists = false;
			failRender('FFmpeg was found at:\n' + ffmpeg
				+ '\n\nbut it could not be started, so video rendering was disabled:\n' + e);
		}
		#else
		trace('Video rendering is not supported on this platform.');
		#end
	}

	/** Set once a missing FFmpeg has been reported, so it does not nag every song. */
	static var warnedMissingFFmpeg:Bool = false;

	/**
	 * Reports a Rendering Mode problem that leaves the song unrecorded.
	 *
	 * This used to be a `trace()`, which is invisible in a release build: the
	 * song just played and no video showed up. A blocking popup is the least
	 * surprising option for something the player explicitly enabled.
	 *
	 * @param once show the popup only the first time the same problem happens.
	 */
	static function failRender(message:String, once:Bool = false):Void
	{
		FlxG.log.error(message);
		if (once && warnedMissingFFmpeg) return;
		if (once) warnedMissingFFmpeg = true;

		#if sys
		CoolUtil.coolError(message, 'Video Rendering');
		#end
	}

	public static function pipeFrame(state:PlayState):Void
	{
		#if sys
		if (!state.ffmpegExists || PlayState.process == null)
			return;

		final window = lime.app.Application.current.window;
		// FFmpeg's rawvideo stride is fixed at startup. The scale-mode game
		// dimensions are logical, NOT physical: capture the whole window at
		// exactly the -s dimensions, including 16:9 letterboxing when disabled.
		// Stop cleanly on a physical resize rather than feeding corrupt frames.
		if (window.width != state.renderWidth || window.height != state.renderHeight)
		{
			FlxG.log.warn('Window resized while recording; closing the current video to avoid corrupted frames.');
			state.ffmpegExists = false;
			stopRender();
			return;
		}

		debug.FrameProfiler.beginRender();
		state.img = window.readPixels();
		if (state.img == null || state.img.width != state.renderWidth || state.img.height != state.renderHeight)
		{
			debug.FrameProfiler.endRender();
			FlxG.log.warn('Unexpected video frame dimensions; stopping the render to avoid corrupted frames.');
			state.ffmpegExists = false;
			stopRender();
			return;
		}
		state.bytes = state.img.getPixels(new lime.math.Rectangle(0, 0, state.img.width, state.img.height));
		if (state.bytes.length != state.renderWidth * state.renderHeight * 4)
		{
			debug.FrameProfiler.endRender();
			FlxG.log.warn('Invalid RGBA frame size; stopping the render.');
			state.ffmpegExists = false;
			stopRender();
			return;
		}
		try
		{
			PlayState.process.stdin.writeBytes(state.bytes, 0, state.bytes.length);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('FFmpeg could not write the video frame: ' + e);
			state.ffmpegExists = false;
			stopRender();
		}
		debug.FrameProfiler.endRender();
		#end
	}

	public static function stopRender():Void
	{
		#if sys
		if (PlayState.process == null)
			return;

		final process = PlayState.process;
		PlayState.process = null;
		try
		{
			process.stdin.close(); // EOF lets FFmpeg finalize its MP4 index.
			process.exitCode();
		}
		catch (e:Dynamic) FlxG.log.warn('FFmpeg closed with an error: ' + e);
		process.close();
		FlxG.autoPause = ClientPrefs.autoPause;
		#end
	}
}