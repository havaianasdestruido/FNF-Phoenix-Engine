package shaders;

import flixel.system.FlxAssets.FlxShader;

// Boing! by ThaeHan

class FuckingTriangle extends FlxShader
{
  // FIX: removed const arrays (arrays unsupported on some platforms)
  // FIX: removed default values from uniforms
  // FIX: replaced arrays with getVertex/getTexCoord lookup functions using if-else
  // FIX: unrolled the for loop (used arrays internally, now gone)
  // FIX: fixed many half-float literals
  @:glFragmentSource('

			#pragma header

			// FIX: replaced vec3 vertices[18] and vec2 texCoords[18] arrays with lookup functions
			vec3 getVertex(int idx) {
				if (idx == 0)  return vec3(-0.5, 0.0, -0.5);
				if (idx == 1)  return vec3( 0.5, 0.0, -0.5);
				if (idx == 2)  return vec3(-0.5, 0.0,  0.5);
				if (idx == 3)  return vec3(-0.5, 0.0,  0.5);
				if (idx == 4)  return vec3( 0.5, 0.0, -0.5);
				if (idx == 5)  return vec3( 0.5, 0.0,  0.5);
				if (idx == 6)  return vec3(-0.5, 0.0, -0.5);
				if (idx == 7)  return vec3( 0.5, 0.0, -0.5);
				if (idx == 8)  return vec3( 0.0, 1.0,  0.0);
				if (idx == 9)  return vec3(-0.5, 0.0,  0.5);
				if (idx == 10) return vec3( 0.5, 0.0,  0.5);
				if (idx == 11) return vec3( 0.0, 1.0,  0.0);
				if (idx == 12) return vec3(-0.5, 0.0, -0.5);
				if (idx == 13) return vec3(-0.5, 0.0,  0.5);
				if (idx == 14) return vec3( 0.0, 1.0,  0.0);
				if (idx == 15) return vec3( 0.5, 0.0, -0.5);
				if (idx == 16) return vec3( 0.5, 0.0,  0.5);
				if (idx == 17) return vec3( 0.0, 1.0,  0.0);
				return vec3(0.0, 0.0, 0.0);
			}

			// FIX: all half-float literals in texCoords expanded (e.g. 0. -> 0.0, 1. -> 1.0, .5 -> 0.5)
			vec2 getTexCoord(int idx) {
				if (idx == 0)  return vec2(0.0, 1.0);
				if (idx == 1)  return vec2(1.0, 1.0);
				if (idx == 2)  return vec2(0.0, 0.0);
				if (idx == 3)  return vec2(0.0, 0.0);
				if (idx == 4)  return vec2(1.0, 1.0);
				if (idx == 5)  return vec2(1.0, 0.0);
				if (idx == 6)  return vec2(0.0, 1.0);
				if (idx == 7)  return vec2(1.0, 1.0);
				if (idx == 8)  return vec2(0.5, 0.0);
				if (idx == 9)  return vec2(0.0, 1.0);
				if (idx == 10) return vec2(1.0, 1.0);
				if (idx == 11) return vec2(0.5, 0.0);
				if (idx == 12) return vec2(0.0, 1.0);
				if (idx == 13) return vec2(1.0, 1.0);
				if (idx == 14) return vec2(0.5, 0.0);
				if (idx == 15) return vec2(0.0, 1.0);
				if (idx == 16) return vec2(1.0, 1.0);
				if (idx == 17) return vec2(0.5, 0.0);
				return vec2(0.0, 0.0);
			}

			vec4 vertexShader(in vec3 vertex, in mat4 transform) {
				// FIX: 1. -> 1.0
				return transform * vec4(vertex, 1.0);
			}

			vec4 fragmentShader(in vec2 uv) {
				return flixel_texture2D(bitmap, uv);
			}

			// perspective()/translate()/rotateX()/rotateY()/bary()/baryLerp()/
			// uvLerp() were called below but never defined anywhere, so this
			// shader could not compile at all. Standard implementations:
			// fov and the rotation uniforms are in degrees (rotX/rotY default
			// to -25/45 from the Haxe constructor), matrices are the usual
			// OpenGL clip-space ones (column-major constructors).
			mat4 perspective(float fovDegrees, float aspect, float near, float far) {
				float f = 1.0 / tan(radians(fovDegrees) * 0.5);
				float nf = 1.0 / (near - far);
				return mat4(
					f / aspect, 0.0, 0.0, 0.0,
					0.0, f, 0.0, 0.0,
					0.0, 0.0, (far + near) * nf, -1.0,
					0.0, 0.0, 2.0 * far * near * nf, 0.0);
			}

			mat4 translate(vec3 t) {
				return mat4(
					1.0, 0.0, 0.0, 0.0,
					0.0, 1.0, 0.0, 0.0,
					0.0, 0.0, 1.0, 0.0,
					t.x, t.y, t.z, 1.0);
			}

			mat4 rotateX(float angleDegrees) {
				float c = cos(radians(angleDegrees));
				float s = sin(radians(angleDegrees));
				return mat4(
					1.0, 0.0, 0.0, 0.0,
					0.0, c, s, 0.0,
					0.0, -s, c, 0.0,
					0.0, 0.0, 0.0, 1.0);
			}

			mat4 rotateY(float angleDegrees) {
				float c = cos(radians(angleDegrees));
				float s = sin(radians(angleDegrees));
				return mat4(
					c, 0.0, -s, 0.0,
					0.0, 1.0, 0.0, 0.0,
					s, 0.0, c, 0.0,
					0.0, 0.0, 0.0, 1.0);
			}

			vec3 bary(vec2 a, vec2 b, vec2 c, vec2 p) {
				vec2 v0 = b - a;
				vec2 v1 = c - a;
				vec2 v2 = p - a;
				float den = v0.x * v1.y - v1.x * v0.y;
				float v = (v2.x * v1.y - v1.x * v2.y) / den;
				float w = (v0.x * v2.y - v2.x * v0.y) / den;
				return vec3(1.0 - v - w, v, w);
			}

			float baryLerp(float a, float b, float c, vec3 tri) {
				return a * tri.x + b * tri.y + c * tri.z;
			}

			vec2 uvLerp(vec2 a, vec2 b, vec2 c, vec3 tri) {
				return a * tri.x + b * tri.y + c * tri.z;
			}

			const float fov  = 70.0;
			const float near = 0.1;
			// FIX: 10. -> 10.0
			const float far  = 10.0;

			// FIX: vec3(0., 0.3, 2.) -> vec3(0.0, 0.3, 2.0)
			const vec3 cameraPos = vec3(0.0, 0.3, 2.0);

			// FIX: removed default values from uniforms, removed -25. -> will be set in constructor
			uniform float rotX;
			uniform float rotY;

			// The MVP matrix is built once in main() and passed in: pixel() used
			// to rebuild the projection/view/model matrices (two trig-based
			// rotations and two mat4*mat4 multiplies) for each of the six
			// triangles, even though the result never changes between calls.
			vec4 pixel(in vec2 ndc, in mat4 mvp, inout float depth, in int vertexIndex) {
				// FIX: use getVertex/getTexCoord instead of array indexing
				vec4 v0 = vertexShader(getVertex(vertexIndex  ), mvp);
				vec4 v1 = vertexShader(getVertex(vertexIndex+1), mvp);
				vec4 v2 = vertexShader(getVertex(vertexIndex+2), mvp);

				// FIX: 1. / v0.w -> 1.0 / v0.w
				vec2 t0 = getTexCoord(vertexIndex  ) / v0.w; float oow0 = 1.0 / v0.w;
				vec2 t1 = getTexCoord(vertexIndex+1) / v1.w; float oow1 = 1.0 / v1.w;
				vec2 t2 = getTexCoord(vertexIndex+2) / v2.w; float oow2 = 1.0 / v2.w;

				v0 /= v0.w;
				v1 /= v1.w;
				v2 /= v2.w;

				vec3 tri = bary(v0.xy, v1.xy, v2.xy, ndc);

				// FIX: 0. -> 0.0, 1. -> 1.0
				if(tri.x < 0.0 || tri.x > 1.0 || tri.y < 0.0 || tri.y > 1.0 || tri.z < 0.0 || tri.z > 1.0) {
					// FIX: vec4(0.) -> vec4(0.0)
					return vec4(0.0);
				}

				float triDepth = baryLerp(v0.z, v1.z, v2.z, tri);
				// FIX: -1. -> -1.0, 1. -> 1.0
				if(triDepth > depth || triDepth < -1.0 || triDepth > 1.0) {
					return vec4(0.0);
				}

				depth = triDepth;

				float oneOverW = baryLerp(oow0, oow1, oow2, tri);
				vec2 uv        = uvLerp(t0, t1, t2, tri) / oneOverW;
				return fragmentShader(uv);
			}

void main()
{
    // FIX: 2. -> 2.0, vec2(1.) -> vec2(1.0)
    vec2 ndc = ((gl_FragCoord.xy * 2.0) / openfl_TextureSize.xy) - vec2(1.0);
    float aspect = openfl_TextureSize.x / openfl_TextureSize.y;
    // FIX: vec3(.4,.6,.9) -> vec3(0.4, 0.6, 0.9)
    vec3 outColor = vec3(0.4, 0.6, 0.9);

    float depth = 1.0;

    mat4 mvp = perspective(fov, aspect, near, far) * translate(-cameraPos) * (rotateX(rotX) * rotateY(rotY));

    // FIX: replaced for(int i = 0; i < 18; i += 3) loop with unrolled calls
    // (loop used array indexing which is now replaced with getVertex/getTexCoord)
    vec4 triResult0 = pixel(ndc, mvp, depth, 0);
    outColor = mix(outColor.rgb, triResult0.rgb, triResult0.a);
    vec4 triResult1 = pixel(ndc, mvp, depth, 3);
    outColor = mix(outColor.rgb, triResult1.rgb, triResult1.a);
    vec4 triResult2 = pixel(ndc, mvp, depth, 6);
    outColor = mix(outColor.rgb, triResult2.rgb, triResult2.a);
    vec4 triResult3 = pixel(ndc, mvp, depth, 9);
    outColor = mix(outColor.rgb, triResult3.rgb, triResult3.a);
    vec4 triResult4 = pixel(ndc, mvp, depth, 12);
    outColor = mix(outColor.rgb, triResult4.rgb, triResult4.a);
    vec4 triResult5 = pixel(ndc, mvp, depth, 15);
    outColor = mix(outColor.rgb, triResult5.rgb, triResult5.a);

    // FIX: 1. -> 1.0
    gl_FragColor = vec4(outColor, 1.0);
}



	')
  public function new()
  {
    super();
    rotX.value = [-25.0];
    rotY.value = [45.0];
  }
}
