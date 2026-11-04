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

package ios.platform;

/**
 * Facade for the Phoenix iOS platform layer.
 *
 * Mirrors `android.platform.AndroidPlatform` so gameplay code can talk to
 * one platform API regardless of target. On every other target the calls
 * below are no-ops.
 *
 * iOS notes:
 *  - Video: hxvlc is desktop-only; iOS uses the engine's VideoSprite fallback
 *    (skips the cutscene) or a future AVPlayer bridge. VIDEOS_ALLOWED is
 *    still true on iOS so the fallback path is tested in CI.
 *  - Display: safe-area insets and refresh rate come from UIKit; the Haxe
 *    side polls them through IOSDisplay.
 *  - Storage: app sandbox uses `lime.system.System.documentsDirectory`
 *    (see `mobile.StorageUtil`).
 */
class IOSPlatform
{
	public static var initialized(default, null):Bool = false;

	/** Boots the iOS platform layer. Safe to call on any target. */
	public static function init():Void
	{
		#if ios
		if (initialized) return;
		initialized = true;
		IOSDisplay.init();
		#end
	}

	/** Whether this is an iOS build (compile-time check). */
	public static inline function isIOS():Bool
	{
		#if ios
		return true;
		#else
		return false;
		#end
	}
}
