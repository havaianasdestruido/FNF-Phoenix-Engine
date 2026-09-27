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
 * presence API. The system media session on Android is owned by
 * `PlayStateAndroidMedia` during gameplay; this class intentionally does
 * NOT touch it, so toggling Discord RPC in the options (which calls
 * shutdown) can never tear down or overwrite an active media session.
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
		// Only forget our own state. The media session belongs to
		// PlayStateAndroidMedia; releasing it here could kill playback
		// metadata mid-song when the RPC option is toggled.
		running = false;
	}

	/**
	 * Mirrors `DiscordClient.changePresence` on Android. Menu presence is
	 * not surfaced on Android (there is no Discord client); the session is
	 * only published for actual gameplay by `PlayStateAndroidMedia`.
	 */
	public static function changePresence(details:String, state:String, ?largeImageKey:String, ?durationMs:Float):Void
	{
		// Intentionally empty: see class docs.
	}
}
