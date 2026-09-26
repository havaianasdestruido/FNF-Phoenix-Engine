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

package android.platform;

/**
 * Android stand-in for Discord Rich Presence.
 *
 * Discord's RPC SDK is desktop-only and Android has no native rich
 * presence API, so on Android the engine's "presence" is exposed through
 * the system media session instead: the same details/state strings that
 * would go to Discord show up on the lock screen, media controls and
 * Bluetooth/Android Auto clients (see `AndroidMedia`).
 *
 * This keeps `DiscordClient` callers platform-agnostic behind one API
 * (the platform abstraction described in the roadmap).
 */
class AndroidDiscord
{
	static var running:Bool = false;

	public static function initialize():Void
	{
		running = true;
	}

	public static function shutdown():Void
	{
		running = false;
		AndroidMedia.stop();
	}

	/**
	 * Mirrors `DiscordClient.changePresence` on Android by publishing the
	 * presence strings as media metadata. Playback state/position is owned
	 * by `PlayStateAndroidMedia` during gameplay, so this only refreshes
	 * the title/artist text.
	 */
	public static function changePresence(details:String, state:String, ?largeImageKey:String, ?durationMs:Float):Void
	{
		if (!running)
			return;

		AndroidMedia.updateNowPlaying(details ?? "Friday Night Funkin'", state ?? "");
	}
}
