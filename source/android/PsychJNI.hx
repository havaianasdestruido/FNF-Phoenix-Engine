/*
 * Copyright (C) 2025 Mobile Porting Team
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

package android;

/**
 * ...
 * @author Homura Akemi (HomuHomu833)
 */
#if android
import lime.system.JNI;

class PsychJNI #if (lime >= "8.0.0") implements JNISafety #end
{
	public static final SDL_ORIENTATION_UNKNOWN:Int = 0;
	public static final SDL_ORIENTATION_LANDSCAPE:Int = 1;
	public static final SDL_ORIENTATION_LANDSCAPE_FLIPPED:Int = 2;
	public static final SDL_ORIENTATION_PORTRAIT:Int = 3;
	public static final SDL_ORIENTATION_PORTRAIT_FLIPPED:Int = 4;

	/**
	 * Executes the `setOrientation` operation.
	 * @param width Input value for `width`.
	 * @param height Input value for `height`.
	 * @param resizeable Input value for `resizeable`.
	 * @param hint Input value for `hint`.
	 * @return Result produced by `setOrientation`, when applicable.
	 */
	public static inline function setOrientation(width:Int, height:Int, resizeable:Bool, hint:String):Dynamic
		return setOrientation_jni(width, height, resizeable, hint);

	/**
	 * Executes the `getCurrentOrientationAsString` operation.
	 * @return Result produced by `getCurrentOrientationAsString`, when applicable.
	 */
	public static inline function getCurrentOrientationAsString():String
	{
		return switch (getCurrentOrientation_jni())
		{
			case SDL_ORIENTATION_PORTRAIT: "Portrait";
			case SDL_ORIENTATION_LANDSCAPE: "LandscapeRight";
			case SDL_ORIENTATION_PORTRAIT_FLIPPED: "PortraitUpsideDown";
			case SDL_ORIENTATION_LANDSCAPE_FLIPPED: "LandscapeLeft";
			default: "Unknown";
		}
	}

	/**
	 * Executes the `isScreenKeyboardShown` operation.
	 * @return Result produced by `isScreenKeyboardShown`, when applicable.
	 */
	public static inline function isScreenKeyboardShown():Dynamic
		return isScreenKeyboardShown_jni();

	/**
	 * Executes the `clipboardHasText` operation.
	 * @return Result produced by `clipboardHasText`, when applicable.
	 */
	public static inline function clipboardHasText():Dynamic
		return clipboardHasText_jni();

	/**
	 * Executes the `clipboardGetText` operation.
	 * @return Result produced by `clipboardGetText`, when applicable.
	 */
	public static inline function clipboardGetText():Dynamic
		return clipboardGetText_jni();

	/**
	 * Executes the `clipboardSetText` operation.
	 * @param string Input value for `string`.
	 * @return Result produced by `clipboardSetText`, when applicable.
	 */
	public static inline function clipboardSetText(string:String):Dynamic
		return clipboardSetText_jni(string);

	/**
	 * Executes the `manualBackButton` operation.
	 * @return Result produced by `manualBackButton`, when applicable.
	 */
	public static inline function manualBackButton():Dynamic
		return manualBackButton_jni();

	/**
	 * Executes the `setActivityTitle` operation.
	 * @param title Input value for `title`.
	 * @return Result produced by `setActivityTitle`, when applicable.
	 */
	public static inline function setActivityTitle(title:String):Dynamic
		return setActivityTitle_jni(title);

	@:noCompletion private static var setOrientation_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'setOrientation',
		'(IIZLjava/lang/String;)V');
	@:noCompletion private static var getCurrentOrientation_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'getCurrentOrientation', '()I');
	@:noCompletion private static var isScreenKeyboardShown_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'isScreenKeyboardShown', '()Z');
	@:noCompletion private static var clipboardHasText_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'clipboardHasText', '()Z');
	@:noCompletion private static var clipboardGetText_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'clipboardGetText',
		'()Ljava/lang/String;');
	@:noCompletion private static var clipboardSetText_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'clipboardSetText',
		'(Ljava/lang/String;)V');
	@:noCompletion private static var manualBackButton_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'manualBackButton', '()V');
	@:noCompletion private static var setActivityTitle_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'setActivityTitle',
		'(Ljava/lang/String;)Z');
}
#end
