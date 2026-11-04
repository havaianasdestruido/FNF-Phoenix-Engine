package shaders;


import flixel.system.FlxAssets.FlxShader;

class VCRDistortionShader extends FlxShader // https://www.shadertoy.com/view/ldjGzV and https://www.shadertoy.com/view/Ms23DR and https://www.shadertoy.com/view/MsXGD4 and https://www.shadertoy.com/view/Xtccz4
{
  @:glFragmentSource('
    #pragma header

    uniform float iTime;
    uniform bool vignetteOn;
    uniform bool perspectiveOn;
    uniform bool distortionOn;
    uniform bool scanlinesOn;
    uniform bool vignetteMoving;
    uniform float glitchModifier;
    uniform vec3 iResolution;

    float onOff(float a, float b, float c)
    {
    	return step(c, sin(iTime + a*cos(iTime*b)));
    }

    float ramp(float y, float start, float end)
    {
    	float inside = step(start,y) - step(end,y);
    	float fact = (y-start)/(end-start)*inside;
    	// FIX: 1. -> 1.0
    	return (1.0-fact) * inside;
    }

    // Time-only terms of getVideo()/random(), computed once per fragment in
    // main(). getVideo() runs seven times per pixel and re-derived all of
    // these (about ten sin/cos calls) on every invocation, even though none
    // of them depend on its uv argument. The multiplication order in
    // getVideo() is unchanged, so the distorted coordinates are identical.
    float windowPhase;
    float onOffDistort;
    float cosTimeFast;
    float glitchDouble;
    float vShiftAmt;
    float sinTimeSlow;

    vec4 getVideo(vec2 uv)
    {
    	vec2 look = uv;
        if(distortionOn){
        	float yTerm = look.y - windowPhase;
        	float window = 1.0/(1.0+20.0*yTerm*yTerm);
        	look.x = look.x + (sin(look.y*10.0 + iTime)/50.0*onOffDistort*cosTimeFast*window)*glitchDouble;
        	look.y = mod(look.y + vShiftAmt, 1.0);
        }
    	vec4 video = flixel_texture2D(bitmap,look);
    	return video;
    }

    vec2 screenDistort(vec2 uv)
    {
      if(perspectiveOn){
        uv = (uv - 0.5) * 2.0;
      	uv *= 1.1;
      	uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
      	uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
      	uv  = (uv / 2.0) + 0.5;
      	uv =  uv *0.92 + 0.04;
      	return uv;
      }
    	return uv;
    }

    float random(vec2 uv)
    {
     	return fract(sin(dot(uv, vec2(15.5151, 42.2561))) * 12341.14122 * sinTimeSlow);
    }

    float noise(vec2 uv)
    {
     	vec2 i = floor(uv);
        vec2 f = fract(uv);

        float a = random(i);
        // FIX: vec2(1.,0.) -> vec2(1.0,0.0), vec2(0.,1.) -> vec2(0.0,1.0), vec2(1.) -> vec2(1.0)
        float b = random(i + vec2(1.0, 0.0));
    	float c = random(i + vec2(0.0, 1.0));
        float d = random(i + vec2(1.0));

        // FIX: smoothstep(0.,1.,f) -> smoothstep(0.0,1.0,f)
        vec2 u = smoothstep(0.0, 1.0, f);

        return mix(a,b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
    }

    void main()
    {
      // Hoisted time-only terms (see the globals above getVideo()).
      windowPhase = mod(iTime/4.0,1.0);
      onOffDistort = onOff(4.0,4.0,0.3);
      cosTimeFast = 1.0+cos(iTime*80.0);
      glitchDouble = glitchModifier*2.0;
      vShiftAmt = 0.4*onOff(2.0,3.0,0.9)*(sin(iTime)*sin(iTime*20.0) +
      									 (0.5 + 0.1*sin(iTime*200.0)*cos(iTime)))*glitchModifier;
      sinTimeSlow = sin(iTime * 0.03);

    	vec2 uv = openfl_TextureCoordv;
      vec2 curUV = screenDistort(uv);
    	// scandistort() was called here, but it only computed two unused
    	// cosines and returned its input unchanged, so it is gone.
    	uv = curUV;
    	vec4 video = getVideo(uv);
      float x = 0.0;

      video.r = getVideo(vec2(x+uv.x+0.001,uv.y+0.001)).x+0.05;
      video.g = getVideo(vec2(x+uv.x+0.000,uv.y-0.002)).y+0.05;
      video.b = getVideo(vec2(x+uv.x-0.002,uv.y+0.000)).z+0.05;
      video.r += 0.08*getVideo(0.75*vec2(x+0.025, -0.027)+vec2(uv.x+0.001,uv.y+0.001)).x;
      // FIX: x+-0.022 -> x-0.022 (invalid operator combination)
      video.g += 0.05*getVideo(0.75*vec2(x-0.022, -0.02)+vec2(uv.x+0.000,uv.y-0.002)).y;
      // FIX: x+-0.02 -> x-0.02 (invalid operator combination)
      video.b += 0.08*getVideo(0.75*vec2(x-0.02, -0.018)+vec2(uv.x-0.002,uv.y+0.000)).z;

      video = clamp(video*0.6+0.4*video*video*1.0,0.0,1.0);
      // The vignette amount/coverage were computed even with vignetteOn off.
      if(vignetteOn)
      {
        float vigAmt = 1.0;
        if(vignetteMoving)
          vigAmt = 3.0+0.3*sin(iTime + 5.0*cos(iTime*5.0));

        float vignette = (1.0-vigAmt*(uv.y-0.5)*(uv.y-0.5))*(1.0-vigAmt*(uv.x-0.5)*(uv.x-0.5));
        video *= vignette;
      }

      // FIX: 75. -> 75.0, .05 -> 0.05
      gl_FragColor = mix(video, vec4(noise(uv * 75.0)), 0.05);

      // FIX: <0 -> <0.0, >1 -> >1.0 (integer comparisons with float)
      if(curUV.x<0.0 || curUV.x>1.0 || curUV.y<0.0 || curUV.y>1.0){
        // FIX: vec4(0,0,0,0) -> vec4(0.0,0.0,0.0,0.0) (integer args in vector constructor)
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
      }
    }
  ')
  public function new()
  {
    super();
  }
}

/*class VHSFilterAccurate extends FlxShader {
  @:glFragmentSource('// Automatically converted with https://github.com/TheLeerName/ShadertoyToFlixel
  // https://www.shadertoy.com/view/NdccR2

  #pragma header

  #define iResolution vec3(openfl_TextureSize, 0.)
  #define iChannel0 bitmap
  #define texture flixel_texture2D

  // end of ShadertoyToFlixel header

  #define PI 3.141592654f

  vec3 RGB_to_YIQ(vec3 RGB)
  {
    return mat3
    (
        0.299f, 0.587f, 0.114f,
        0.596f, -0.275f, -0.321f,
        0.212f, -0.523f, 0.311f
    ) * RGB;
  }

  vec3 YIQ_to_RGB(vec3 YIQ)
  {
    return mat3
    (
        1.f, 0.956f, 0.619f,
        1.f, -0.272f, -0.647f,
        1.f, -1.106f, 1.703f
    ) * YIQ;
  }

  // Converts color from RGB to YIQ, blur the I and Q, then apply a dot crawl effect
  vec3 VHS_effect(vec2 fragCoord, float colorDistortion)
  {
    vec2    IQ = vec2(0,0),
            blur_size = vec2(16, 4),
            focal_point = blur_size * 0.5f;

    float   smear_factor = blur_size.x * blur_size.y;

    vec2    UV_Y = fragCoord / iResolution.xy;

    // IQ blur
    for (int i = 0; i < int(smear_factor); i++)
    {
        vec2 uv_prime = vec2
        (
            (fragCoord.x + float(i % int(blur_size.x)) - focal_point.x) / iResolution.x,
            (fragCoord.y + float(i / int(blur_size.y)) - focal_point.y) / iResolution.y
        );
        IQ += RGB_to_YIQ(texture(iChannel0, uv_prime).xyz).yz;
    }
    IQ /= smear_factor;

    vec3 color = vec3
    (
        RGB_to_YIQ(texture(iChannel0, UV_Y).xyz).r,
        IQ * (1.f + colorDistortion)
    );

    // NTSC Dot Crawl
    color.x += (IQ.x*sin((fragCoord.x))) *
               (IQ.y*sin( fragCoord.y * PI * 0.5f));

    color = YIQ_to_RGB(color);

    return color;
  }



  void mainImage( out vec4 fragColor, in vec2 fragCoord )
  {
    //fragColor = vec4(vec3(sin(fragCoord.x)), texture(iChannel0, fragCoord / iResolution.xy).a);
    fragColor = vec4(VHS_effect(fragCoord, 0.2f),1.0);
    //fragColor = texture(iChannel0, fragCoord / iResolution.xy);
  }

  void main() {
  mainImage(gl_FragColor, openfl_TextureCoordv*openfl_TextureSize);
  }')
  public function new(lockAlpha:Bool)
  {
    super();
  }
}*/
