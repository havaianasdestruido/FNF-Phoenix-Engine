package shaders;

import flixel.system.FlxAssets.FlxShader;
#if (!flash)
import flixel.addons.display.FlxRuntimeShader;
import lime.graphics.opengl.GLProgram;
#end
#if !flash
import lime.app.Application;
#end

class ErrorHandledShader extends FlxShader implements IErrorHandler
{
	public var shaderName:String = '';

	/**
	 * Executes the `onError` operation.
	 * @param error Input value for `error`.
	 */
	public dynamic function onError(error:Dynamic):Void
	{
	}

	/**
	 * Executes the `new` operation.
	 * @param shaderName Input value for `shaderName`.
	 */
	public function new(?shaderName:String)
	{
		this.shaderName = shaderName;
		super();
	}

#if !flash
	/**
	 * Executes the `__createGLProgram` operation.
	 * @param vertexSource Input value for `vertexSource`.
	 * @param fragmentSource Input value for `fragmentSource`.
	 * @return Result produced by `__createGLProgram`, when applicable.
	 */
	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
		try
		{
			final res = super.__createGLProgram(vertexSource, fragmentSource);
			return res;
		}
		catch (error)
		{
			ErrorHandledShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
	#end

	/**
	 * Executes the `crashSave` operation.
	 * @param shaderName Input value for `shaderName`.
	 * @param error Input value for `error`.
	 * @param onError Input value for `onError`.
	 * @return Result produced by `crashSave`, when applicable.
	 */
	public static function crashSave(shaderName:String, error:Dynamic, onError:Dynamic) // prevent the app from dying immediately
	{
		if (shaderName == null)
			shaderName = 'unnamed';
		var alertTitle:String = 'Error on Shader: "$shaderName"';

		trace(error);

		#if (!debug && sys)
		// Save a crash log on Release builds
		var errMsg:String = "";
		var dateNow:String = Date.now().toString().replace(" ", "_").replace(":", "'");

		if (!FileSystem.exists('./logs/'))
			FileSystem.createDirectory('./logs/');

		var crashLogPath:String = './logs/shader_${shaderName}_${dateNow}.txt';
		File.saveContent(crashLogPath, error);
		#if !flash
		Application.current.window.alert('Error log saved at: $crashLogPath', alertTitle);
		#end
		#elseif !flash
		Application.current.window.alert('Error logs aren\'t created on debug builds, check the trace log instead.', alertTitle);
		#end

		onError(error);
	}
}

#if (SHADERS_ALLOWED && !flash && !neko)
class ErrorHandledRuntimeShader extends FlxRuntimeShader implements IErrorHandler
{
	public var shaderName:String = '';

	/**
	 * Executes the `onError` operation.
	 * @param error Input value for `error`.
	 */
	public dynamic function onError(error:Dynamic):Void
	{
	}

	/**
	 * Executes the `new` operation.
	 * @param shaderName Input value for `shaderName`.
	 * @param fragmentSource Input value for `fragmentSource`.
	 * @param vertexSource Input value for `vertexSource`.
	 */
	public function new(?shaderName:String, ?fragmentSource:String, ?vertexSource:String)
	{
		this.shaderName = shaderName;
		super(fragmentSource, vertexSource);
	}

	/**
	 * Executes the `__createGLProgram` operation.
	 * @param vertexSource Input value for `vertexSource`.
	 * @param fragmentSource Input value for `fragmentSource`.
	 * @return Result produced by `__createGLProgram`, when applicable.
	 */
	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
		try
		{
			final res = super.__createGLProgram(vertexSource, fragmentSource);
			return res;
		}
		catch (error)
		{
			ErrorHandledShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
}
#else
class ErrorHandledRuntimeShader implements IErrorHandler
{
	public var shaderName:String = '';

	/**
	 * Executes the `onError` operation.
	 * @param error Input value for `error`.
	 */
	public dynamic function onError(error:Dynamic):Void
	{
	}

	/**
	 * Executes the `new` operation.
	 * @param shaderName Input value for `shaderName`.
	 * @param fragmentSource Input value for `fragmentSource`.
	 * @param vertexSource Input value for `vertexSource`.
	 */
	public function new(?shaderName:String, ?fragmentSource:String, ?vertexSource:String)
	{
		this.shaderName = shaderName;
	}

	/**
	 * Executes the `setFloat` operation.
	 * @param name Input value for `name`.
	 * @param value Input value for `value`.
	 */
	public function setFloat(name:String, value:Float):Void
	{
	}

	/**
	 * Executes the `setBool` operation.
	 * @param name Input value for `name`.
	 * @param value Input value for `value`.
	 */
	public function setBool(name:String, value:Bool):Void
	{
	}
}
#end

interface IErrorHandler
{
	public var shaderName:String;
	/**
	 * Executes the `onError` operation.
	 * @param error Input value for `error`.
	 */
	public dynamic function onError(error:Dynamic):Void;
}
