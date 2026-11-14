package psychlua.callbacks;

import backend.ClientPrefs;
import backend.CoolUtil;
import flixel.util.FlxColor;
import play.PlayState;
import psychlua.FunkinLua;
import headers.PsychLua;
import shaders.ChromaticAberrationEffect;
import shaders.ScanlineEffect;
import shaders.GrainEffect;
import shaders.TiltshiftEffect;
import shaders.VCRDistortionEffect;
import shaders.WiggleEffectLua;
import shaders.GlitchEffect;
import shaders.PulseEffect;
import shaders.DistortBGEffect;
import shaders.InvertColorsEffect;
import shaders.GreyscaleEffect;
import shaders.ThreeDEffect;
import shaders.BloomEffect;
import shaders.BlockedGlitchEffect;
import shaders.DistantNoteEffect;
// (TODO.md §23.2 "Shaders"): the generic Mario Madness shaders, Apache-2.0 and
// ported with credits. Each shader class names its upstream source and every
// local change; each effect here is reachable from Lua, Python and HScript.
import shaders.BrightnessContrastEffect;
import shaders.CRTEffect;
import shaders.MosaicEffect;
import shaders.OldTVEffect;
import shaders.RippleEffect;
import shaders.SilhouetteEffect;
import shaders.TVStaticEffect;
import shaders.VCRBorderEffect;
import shaders.VCRFuzzEffect;

class EffectCallbacks
{
	public static function register(funk:FunkinLua):Void {
		@:privateAccess {
		//SHADER EFFECTS
		if (ClientPrefs.shaders) {
			FunkinLua.registerFunction("addChromaticAbberationEffect", function(camera:String,chromeOffset:Float = 0.005) {

				PlayState.instance.addShaderToCamera(camera, new ChromaticAberrationEffect(chromeOffset));

			});

			FunkinLua.registerFunction("addScanlineEffect", function(camera:String,lockAlpha:Bool=false) {

				PlayState.instance.addShaderToCamera(camera, new ScanlineEffect(lockAlpha));

			});
			FunkinLua.registerFunction("addGrainEffect", function(camera:String,grainSize:Float,lumAmount:Float,lockAlpha:Bool=false) {

				PlayState.instance.addShaderToCamera(camera, new GrainEffect(grainSize,lumAmount,lockAlpha));

			});
			FunkinLua.registerFunction("addTiltshiftEffect", function(camera:String,blurAmount:Float,center:Float) {

				PlayState.instance.addShaderToCamera(camera, new TiltshiftEffect(blurAmount,center));

			});
			FunkinLua.registerFunction("addVCREffect", function(camera:String,glitchFactor:Float = 0.0,distortion:Bool=true,perspectiveOn:Bool=true,vignetteMoving:Bool=true) {

				PlayState.instance.addShaderToCamera(camera, new VCRDistortionEffect(glitchFactor,distortion,perspectiveOn,vignetteMoving));

			});

			// shader clear

			FunkinLua.registerFunction("clearShadersFromCamera", function(cameraName)
			{
				LuaUtils.cameraFromString(cameraName).filters = [];
			});

			FunkinLua.registerFunction("addWiggleEffect", function(camera:String, effectType:String, waveSpeed:Float = 0.1,waveFrq:Float = 0.1,waveAmp:Float = 0.1, ?verticalStrength:Float = 1, ?horizontalStrength:Float = 1) {
				PlayState.instance.addShaderToCamera(camera, new WiggleEffectLua(effectType, waveSpeed, waveFrq, waveAmp,
					verticalStrength, horizontalStrength));
			});
			FunkinLua.registerFunction("addGlitchEffect", function(camera:String,waveSpeed:Float = 0.1,waveFrq:Float = 0.1,waveAmp:Float = 0.1) {
				PlayState.instance.addShaderToCamera(camera, new GlitchEffect(waveSpeed,waveFrq,waveAmp));
			});
			FunkinLua.registerFunction("addGlitchShader", function(camera:String,waveAmp:Float = 0.1,waveFrq:Float = 0.1,waveSpeed:Float = 0.1) {
				PlayState.instance.addShaderToCamera(camera, new GlitchEffect(waveSpeed,waveFrq,waveAmp));
			});
			FunkinLua.registerFunction("addPulseEffect", function(camera:String,waveSpeed:Float = 0.1,waveFrq:Float = 0.1,waveAmp:Float = 0.1) {

				PlayState.instance.addShaderToCamera(camera, new PulseEffect(waveSpeed,waveFrq,waveAmp));

			});
			FunkinLua.registerFunction("addDistortionEffect", function(camera:String,waveSpeed:Float = 0.1,waveFrq:Float = 0.1,waveAmp:Float = 0.1) {

				PlayState.instance.addShaderToCamera(camera, new DistortBGEffect(waveSpeed,waveFrq,waveAmp));

			});
			FunkinLua.registerFunction("addInvertEffect", function(camera:String,lockAlpha:Bool=false) {

				PlayState.instance.addShaderToCamera(camera, new InvertColorsEffect(lockAlpha));

			});
			FunkinLua.registerFunction("addGreyscaleEffect", function(camera:String) { //for dem funkies

				PlayState.instance.addShaderToCamera(camera, new GreyscaleEffect());

			});
			FunkinLua.registerFunction("addGrayscaleEffect", function(camera:String) { //for dem funkies

				PlayState.instance.addShaderToCamera(camera, new GreyscaleEffect());

			});
			FunkinLua.registerFunction("add3DEffect", function(camera:String,xrotation:Float=0,yrotation:Float=0,zrotation:Float=0,depth:Float=0) { //for dem funkies
				PlayState.instance.addShaderToCamera(camera, new ThreeDEffect(xrotation,yrotation,zrotation,depth));
			});
			FunkinLua.registerFunction("addBloomEffect", function(camera:String,intensity:Float = 0.35,blurSize:Float=1.0) {
				PlayState.instance.addShaderToCamera(camera, new BloomEffect(blurSize/512.0,intensity));
			});
			FunkinLua.registerFunction("addBlockedGlitchEffect", function(camera:String, res:Float = 1280, time:Float = 1, colorMult:Float = 1, colorTransform:Bool = true) {
				if (colorTransform) PlayState.instance.addShaderToCamera(camera, new BlockedGlitchEffect(res, time, colorMult, colorTransform));
			});
			FunkinLua.registerFunction("addDistantNoteEffect", function(camera:String, ?downscroll:Bool, pivot:Float = 0.42, spread:Float = 0.8) {
				if (downscroll == null) downscroll = ClientPrefs.downScroll;
				PlayState.instance.addShaderToCamera(camera, new DistantNoteEffect(downscroll, pivot, spread));
			});
			// Curved CRT television: screen warp, scanline reconstruction, an RGB
			// shadow mask and a corner vignette. Ported from Mario Madness, which
			// ports Timothy Lottes' public-domain CRT shader. `curve` 0 is a flat
			// screen, `scanlineHardness` and `pixelHardness` are negative (-8 and -2
			// are soft, -16 and -4 harder), `mask` and `vignette` run 0 to 1 and
			// `resolutionScale` is the emulated resolution as a fraction of the
			// screen (0.5 doubles the scanline grid). Costs eleven texture fetches
			// per pixel, so attach it to one camera instead of all of them.
			FunkinLua.registerFunction("addCRTEffect", function(camera:String, curve:Float = 1.0, scanlineHardness:Float = -8.0, pixelHardness:Float = -2.0, mask:Float = 1.0, vignette:Float = 0.25, resolutionScale:Float = 0.5) {
				PlayState.instance.addShaderToCamera(camera, new CRTEffect(curve, scanlineHardness, pixelHardness, mask, vignette, resolutionScale));
			});
			// Broken old television: a rolling picture-offset bar, black and white
			// sploches and analogue static. Ported from Mario Madness. `staticAmount`
			// is how much noise is mixed in (0.05 upstream), `damage` scales the bar
			// and the sploches from 0 (static only) to 1, `blur` is an optional smear
			// radius in pixels that defaults to 0 because it costs sixteen extra
			// fetches, and `bar`/`barOffset` control the rolling band.
			FunkinLua.registerFunction("addOldTVEffect", function(camera:String, staticAmount:Float = 0.05, damage:Float = 1.0, blur:Float = 0.0, bar:Bool = true, barOffset:Float = 0.01) {
				PlayState.instance.addShaderToCamera(camera, new OldTVEffect(staticAmount, damage, blur, bar, barOffset));
			});
			// Untuned-television static pulsing over the picture, the effect Mario
			// Madness runs on its title screen. Ported from its `TVStatic`.
			// `strength` multiplies the whole effect, `minStrength` and `maxStrength`
			// are the bounds it pulses between and `speed` is how fast the noise
			// field churns. Also works on a single sprite: pass its name as `camera`.
			FunkinLua.registerFunction("addTVStaticEffect", function(camera:String, strength:Float = 1.0, minStrength:Float = 0.3, maxStrength:Float = 0.8, speed:Float = 20.0) {
				PlayState.instance.addShaderToCamera(camera, new TVStaticEffect(strength, minStrength, maxStrength, speed));
			});
			// Water ripple: the picture is displaced by a scrolling simplex-noise
			// field. Ported from Mario Madness, after shadertoy XtsSzN. `strength` is
			// the displacement in thousandths of the screen (10 upstream), `speed`
			// how fast the water moves (0.5 upstream) and `scale` the size of the
			// ripples, where bigger means tighter waves.
			FunkinLua.registerFunction("addRippleEffect", function(camera:String, strength:Float = 10.0, speed:Float = 0.5, scale:Float = 1.0) {
				PlayState.instance.addShaderToCamera(camera, new RippleEffect(strength, speed, scale));
			});
			// Flat single-colour silhouette that keeps the sprite's shape. Ported
			// from Mario Madness. `color` takes a number (`0xFF0000`), a hex string
			// (`'#FF0000'`, `'0xFF0000'`) or a colour name (`'red'`); `amount` runs
			// from 0 (the untouched sprite) to 1 (a pure silhouette). Meant for a
			// character: pass `'boyfriend'`, `'dad'`, `'gf'` or a sprite name as
			// `camera` to shade one sprite instead of a whole camera.
			FunkinLua.registerFunction("addSilhouetteEffect", function(camera:String, color:Dynamic = 0x000000, amount:Float = 1.0) {
				PlayState.instance.addShaderToCamera(camera, new SilhouetteEffect(silhouetteColor(funk, color), amount));
			});
			// Pixelate the picture into blocks. Ported from Mario Madness'
			// `MosaicShader`. `blockSize` is the block size in screen pixels (1
			// changes nothing, 8 is a coarse mosaic) and `blockSizeY` overrides the
			// vertical axis when given. Cheapest of the effects here: one fetch.
			FunkinLua.registerFunction("addMosaicEffect", function(camera:String, blockSize:Float = 8.0, ?blockSizeY:Float) {
				PlayState.instance.addShaderToCamera(camera, new MosaicEffect(blockSize, blockSizeY));
			});
			// Alias of `addMosaicEffect` under the name Mario Madness' wrapper used,
			// so a port of its `SMWPixelBlurShader` code reads the same: `strengthX`
			// and `strengthY` are the block size in screen pixels on each axis.
			FunkinLua.registerFunction("addSMWPixelBlurEffect", function(camera:String, strengthX:Float = 8.0, ?strengthY:Float) {
				PlayState.instance.addShaderToCamera(camera, new MosaicEffect(strengthX, strengthY));
			});
			// Brightness and contrast, the dimmer for a camera or a sprite. Ported
			// from Mario Madness. `brightness` multiplies the result (1 is unchanged,
			// 0.6 dims a distracting stage) and `contrast` multiplies the distance
			// from mid grey (1 is unchanged). Attaching it to `game` leaves the notes
			// and the HUD bright, which is what the stage dim option wants.
			FunkinLua.registerFunction("addBrightnessContrastEffect", function(camera:String, brightness:Float = 1.0, contrast:Float = 1.0) {
				PlayState.instance.addShaderToCamera(camera, new BrightnessContrastEffect(brightness, contrast));
			});
			// The curved VCR frame on its own: screen warp, corner vignette and a
			// black bezel, with no glitch and no colour bleed. Ported from Mario
			// Madness' `VCRBorder`; use `addVCREffect` when the picture should also
			// glitch. `curve` 0 is a flat screen, `vignette` runs 0 to 1 and `border`
			// decides whether the off-screen area is black or a smeared edge.
			FunkinLua.registerFunction("addVCRBorderEffect", function(camera:String, curve:Float = 1.0, vignette:Float = 1.0, border:Bool = true) {
				PlayState.instance.addShaderToCamera(camera, new VCRBorderEffect(curve, vignette, border));
			});
			// Steady VHS tape fuzz: rows wobble smoothly, the channels split and a
			// hard scanline pattern darkens the picture. Ported from Mario Madness'
			// `VCRMario85`. `fuzz` scales the wobble (0 stops it), `split` is the
			// channel separation in UV units (0 also skips its two extra fetches),
			// `scanline` how dark the pattern is and `scanlineFrequency` how many
			// rows it has. Cheaper and calmer than `addVCREffect`.
			FunkinLua.registerFunction("addVCRFuzzEffect", function(camera:String, fuzz:Float = 1.0, split:Float = 0.003, scanline:Float = 0.04, scanlineFrequency:Float = 800.0) {
				PlayState.instance.addShaderToCamera(camera, new VCRFuzzEffect(fuzz, split, scanline, scanlineFrequency));
			});
			FunkinLua.registerFunction("clearEffects", function(camera:String) {
				PlayState.instance.clearShaderFromCamera(camera);
			});
		}
		}
	}

	/**
	 * Resolves the colour argument `addSilhouetteEffect` accepts: a number
	 * (`0xFF0000`), a hex string (`'#FF0000'`, `'0xFF0000'`) or a colour name
	 * (`'red'`), which is what `CoolUtil.colorFromString` already reads for the
	 * chart events. Anything else warns and falls back to black instead of
	 * throwing inside a script callback.
	 */
	static function silhouetteColor(funk:FunkinLua, color:Dynamic):FlxColor
	{
		if (Std.isOfType(color, String)) return CoolUtil.colorFromString(color);
		if (Std.isOfType(color, Int) || Std.isOfType(color, Float)) return FlxColor.fromInt(Std.int(color));
		LuaUtils.luaTrace(funk.lua, 'addSilhouetteEffect | Unsupported colour "$color", using black', false, false, FlxColor.RED);
		return FlxColor.BLACK;
	}
}
