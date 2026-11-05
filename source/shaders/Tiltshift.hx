package shaders;


import flixel.system.FlxAssets.FlxShader;

class Tiltshift extends FlxShader
{
  @:glFragmentSource('
		#pragma header

		// Modified version of a tilt shift shader from Martin Jonasson (http://grapefrukt.com/)
		// Read http://notes.underscorediscovery.com/ for context on shaders and this file
		// License : MIT

			/*
				Take note that blurring in a single pass (the two for loops below) is more expensive than separating
				the x and the y blur into different passes. This was used where bleeding edge performance
				was not crucial and is to illustrate a point.

				The reason two passes is cheaper?
				   texture2D is a fairly high cost call, sampling a texture.

				   So, in a single pass, like below, there are 3 steps, per x and y.

				   That means a total of 9 "taps", it touches the texture to sample 9 times.

				   Now imagine we apply this to some geometry, that is equal to 16 pixels on screen (tiny)
				   (16 * 16) * 9 = 2304 samples taken, for width * height number of pixels, * 9 taps
				   Now, if you split them up, it becomes 3 for x, and 3 for y, a total of 6 taps
				   (16 * 16) * 6 = 1536 samples

				   That\'s on a *tiny* sprite, let\'s scale that up to 128x128 sprite...
				   (128 * 128) * 9 = 147,456
				   (128 * 128) * 6 =  98,304

				   That\'s 33.33..% cheaper for splitting them up.
				   That\'s with 3 steps, with higher steps (more taps per pass...)

				   A really smooth, 6 steps, 6*6 = 36 taps for one pass, 12 taps for two pass
				   You will notice, the curve is not linear, at 12 steps it\'s 144 vs 24 taps
				   It becomes orders of magnitude slower to do single pass!
				   Therefore, you split them up into two passes, one for x, one for y.
			*/

		// I am hardcoding the constants like a jerk

		uniform float bluramount;
		uniform float center;
		const float stepSize    = 0.004;

		void main() {
			// Work out how much to blur based on the mid point
			// (pow(x, 2.0) replaced with the equivalent multiply)
			float midDist = (openfl_TextureCoordv.y * center) * 2.0 - 1.0;
			float amount = midDist * midDist * bluramount;

			// With no blur, all 9 taps below sample the same texel, so the
			// result is (vec4(0,0,0,1) + 9 * texel) / 9. Produce exactly
			// that value from a single fetch instead.
			if (amount == 0.0) {
				vec4 texel = texture2D(bitmap, openfl_TextureCoordv.xy);
				gl_FragColor = vec4(texel.rgb, (1.0 + 9.0 * texel.a) / 9.0);
				return;
			}

			// This is the accumulation of color from the surrounding pixels in the texture
			vec4 blurred = vec4(0.0, 0.0, 0.0, 1.0);

			// From minimum offset to maximum offset (steps = 3, so -1..1).
			// Integer loops and one hoisted offset scale replace the float
			// loop that recomputed amount * stepSize for every tap.
			float offsetScale = amount * stepSize;
			for (int offsX = -1; offsX <= 1; ++offsX) {
				for (int offsY = -1; offsY <= 1; ++offsY) {
					vec2 temp_tcoord = openfl_TextureCoordv.xy + vec2(float(offsX), float(offsY)) * offsetScale;

					// accumulate the sample
					blurred += texture2D(bitmap, temp_tcoord);
				}
			}

			// because we are doing an average, we divide by the amount (x AND y, hence steps * steps)
			blurred /= 9.0;

			// return the final blurred color
			gl_FragColor = blurred;
		}')
  public function new()
  {
    super();
    bluramount.value = [1.0];
    center.value = [1.0];
  }
}
