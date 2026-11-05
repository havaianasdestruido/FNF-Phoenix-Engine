package shaders;

// idc anymore
enum abstract RuntimeShaders(String) to String from String
{
	final pulseEffect:String = "
		#pragma header

		uniform float uAmplitude;
		uniform float uTime;
		uniform float uSpeed;
		uniform float uFrequency;
		uniform bool uEnabled;
		uniform float uWaveAmplitude;

		vec4 sineWave(vec4 pt)
		{
			if (uWaveAmplitude > 0.0 && uEnabled)
			{
				// Hoisted: uWaveAmplitude * uWaveAmplitude was recomputed for
				// each mix(), and every sin() re-derived its uTime/uFrequency
				// products. The channel update order below is unchanged
				// (weirdY/weirdZ read the already-updated pt.x, as before).
				float amp2 = uWaveAmplitude * uWaveAmplitude;
				float timeSpeed = uTime * uSpeed;

				// Calculate offsets
				float offsetX = sin(pt.y * uFrequency + timeSpeed);
				float offsetY = sin(pt.x * (uFrequency * 2.0) - timeSpeed * 0.5);
				float offsetZ = sin(pt.z * (uFrequency * 0.5) + timeSpeed / 3.0);

				// Use (0.5 * sin + 0.5) to keep values between 0.0 and 1.0
				// This prevents negative colors (Black Screen)
				float weirdX = 0.5 * sin(pt.x * 0.5 * pt.y + (5.0 * offsetX) * pt.z) + 0.5;
				pt.x = mix(pt.x, weirdX, amp2);

				float weirdY = 0.5 * sin(pt.y / 3.0 * pt.z + (2.0 * offsetZ) - pt.x) + 0.5;
				pt.y = mix(pt.y, weirdY, amp2);

				float weirdZ = 0.5 * sin(pt.z / 6.0 * (pt.x * offsetY) - (50.0 * offsetZ) * (pt.z * offsetX)) + 0.5;
				pt.z = mix(pt.z, weirdZ, amp2);
			}

			return pt;
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			gl_FragColor = sineWave(flixel_texture2D(bitmap, uv));
		}
	";
}
