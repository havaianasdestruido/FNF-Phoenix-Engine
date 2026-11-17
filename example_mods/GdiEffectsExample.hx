package example_mods;

import backend.GDIEffects;
import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Haxe example showing how to use the GDIEffects API directly from Haxe.
 * 
 * This demonstrates the Windows GDI effects ported from Slushi Engine.
 * These effects draw directly on the desktop using raw GDI calls,
 * running on a dedicated background thread so they never lag the game.
 * 
 * Available effects (register first, then enable):
 * - "DrawIcons"       -- Error/warning icons follow the mouse cursor
 * - "ScreenBlink"     -- Invert desktop colors (flash)
 * - "ScreenGlitches"  -- Copy random rectangles to random positions
 * - "ScreenTunnel"    -- Recursive StretchBlt tunnel
 * - "ScreenShake"     -- Shake screen with small random offsets
 * - "SetTitleText"    -- Set custom text on all window title bars
 * 
 * One-shot triggers (run immediately, no registration needed):
 * - GDIEffects.drawIcons()
 * - GDIEffects.screenBlink()
 * - GDIEffects.screenGlitches()
 * - GDIEffects.screenTunnel()
 * - GDIEffects.screenShake()
 * - GDIEffects.setCustomTitleText(text)
 */
class GdiEffectsExample extends FlxState
{
	var statusText:FlxText;
	var glitchEnabled:Bool = false;
	var tunnelEnabled:Bool = false;
	var iconsEnabled:Bool = false;
	var elapsedTime:Float = 0;

	override public function create():Void
	{
		super.create();

		// Initialize the GDI subsystem
		if (!GDIEffects.init())
		{
			trace("GDIEffectsExample: GDI effects not available on this platform");
			statusText = new FlxText(0, 0, FlxG.width, "GDI Effects not available on this platform");
			statusText.setFormat(null, 24, FlxColor.WHITE, "center");
			statusText.screenCenter();
			add(statusText);
			return;
		}

		trace("GDIEffectsExample: GDI Effects initialized!");
		trace("Available effects: " + GDIEffects.availableEffects.join(", "));

		// Register the effects we want to use
		GDIEffects.registerEffect("ScreenGlitches");
		GDIEffects.registerEffect("ScreenTunnel");
		GDIEffects.registerEffect("DrawIcons");
		GDIEffects.registerEffect("SetTitleText");

		// Set wait times (ms between frames) to control speed/CPU usage
		GDIEffects.setEffectWait("ScreenGlitches", 50);  // 20 FPS
		GDIEffects.setEffectWait("ScreenTunnel", 30);    // ~33 FPS
		GDIEffects.setEffectWait("DrawIcons", 16);       // ~60 FPS

		// Set initial title text for the SetTitleText effect
		GDIEffects.setEffectTitleText("SetTitleText", "FNF Phoenix Engine");

		// UI for testing
		statusText = new FlxText(0, 0, FlxG.width, "GDI Effects Example\nPress 1/2/3/4 to toggle effects\nPress B for blink\nPress G for glitch\nPress T for tunnel\nPress S for shake\nPress C for custom title (one-shot)\nPress X for toggle effect (glitches)");
		statusText.setFormat(null, 18, FlxColor.WHITE, "center");
		statusText.screenCenter();
		add(statusText);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		elapsedTime += elapsed;

		// Example: Toggle effects with keyboard
		if (FlxG.keys.justPressed("ONE"))
		{
			glitchEnabled = !glitchEnabled;
			if (glitchEnabled)
				GDIEffects.enableEffect("ScreenGlitches");
			else
				GDIEffects.disableEffect("ScreenGlitches");
			updateStatus();
		}

		if (FlxG.keys.justPressed("TWO"))
		{
			tunnelEnabled = !tunnelEnabled;
			if (tunnelEnabled)
				GDIEffects.enableEffect("ScreenTunnel");
			else
				GDIEffects.disableEffect("ScreenTunnel");
			updateStatus();
		}

		if (FlxG.keys.justPressed("THREE"))
		{
			iconsEnabled = !iconsEnabled;
			if (iconsEnabled)
				GDIEffects.enableEffect("DrawIcons");
			else
				GDIEffects.disableEffect("DrawIcons");
			updateStatus();
		}

		// Toggle effect using new toggleEffect API
		if (FlxG.keys.justPressed("X"))
		{
			var newState = GDIEffects.toggleEffect("ScreenGlitches");
			glitchEnabled = newState;
			updateStatus();
		}

		// One-shot triggers
		if (FlxG.keys.justPressed("B"))
			GDIEffects.screenBlink();

		if (FlxG.keys.justPressed("G"))
			GDIEffects.screenGlitches();

		if (FlxG.keys.justPressed("T"))
			GDIEffects.screenTunnel();

		if (FlxG.keys.justPressed("S"))
			GDIEffects.screenShake();

		if (FlxG.keys.justPressed("C"))
			GDIEffects.setCustomTitleText("Custom Title from Haxe! Time: " + Std.int(elapsedTime));
	}

	function updateStatus():Void
	{
		if (statusText != null)
		{
			statusText.text = "GDI Effects Example\n" +
				"Press 1/2/3/4 to toggle effects\n" +
				"Press B for blink\n" +
				"Press G for glitch\n" +
				"Press T for tunnel\n" +
				"Press S for shake\n" +
				"Press C for custom title (one-shot)\n" +
				"Press X for toggle effect (glitches)\n\n" +
				"Glitches: " + (if (glitchEnabled) "ON" else "OFF") + "\n" +
				"Tunnel: " + (if (tunnelEnabled) "ON" else "OFF") + "\n" +
				"Icons: " + (if (iconsEnabled) "ON" else "OFF");
		}
	}

	override public function destroy():Void
	{
		// Clean up
		GDIEffects.setCustomTitleText("");  // Restore normal titles (one-shot)
		GDIEffects.setEffectTitleText("SetTitleText", "");  // Clear registered effect title
		GDIEffects.destroy();
		super.destroy();
	}
}