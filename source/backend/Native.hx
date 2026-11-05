package backend;

#if (lime_opengl || lime_opengles || lime_webgl)
import lime.graphics.opengl.GL;
#end
#if lime_openal
import lime.media.openal.AL;
#end

/**
 * Hardware information of the machine the game is running on.
 */
typedef HardwareInfo =
{
  /** GPU vendor, e.g. "NVIDIA". */
  var gpuVendor:String;
  /** GPU model, e.g. "NVIDIA GeForce RTX 3060". */
  var gpuModel:String;
  /** GPU driver version, e.g. "535.104.05". */
  var gpuDriver:String;
  /** CPU vendor, e.g. "Intel". */
  var cpuVendor:String;
  /** CPU model, e.g. "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz". */
  var cpuModel:String;
  /** Operating system, e.g. "Windows". */
  var osName:String;
  /** Operating system version, e.g. "10.0.19045". */
  var osVersion:String;
  /** Graphics API version, e.g. "OpenGL 4.6". */
  var graphicsApi:String;
  /** Audio backend, e.g. "OpenAL Soft | 1.23.1". */
  var audioApi:String;
}

/**
 * GPU / CPU / driver detection.
 *
 * The GPU sniffing is ported from the Psych Plus Engine
 * (`source/backend/Native.hx`, https://github.com/Psych-Plus-Team/FNF-PlusEngine)
 * — big thanks to the Psych Plus Team for the original implementation! The CPU
 * and operating system part is native (see `backend.NativeHardware`).
 *
 * The engine itself uses this to enrich crash reports: when something goes
 * wrong the log says which GPU, driver and CPU the player was running, which
 * turns "it is slow on my machine" into an actionable bug report. Mods can
 * read the same values through the scripting API (`getGPUName()` and friends).
 *
 * Every query degrades gracefully: on a target without a usable render context
 * (or without native CPU queries) the value is reported as "Unknown" instead
 * of throwing.
 */
class Native
{
  /** Reported whenever a value could not be determined. */
  public static inline var UNKNOWN:String = "Unknown";

  /** The OpenGL version prefix, e.g. "OpenGL ES 3.2 " or "OpenGL 4.6 ". */
  static final API_PREFIX_REGEX = ~/(OpenGL ES|OpenGL|WebGL)\s+[0-9.]+/g;

  /** Keywords that mark the start of a GPU model inside a renderer string. */
  static final GPU_KEYWORDS:Array<String> = [
    'NVIDIA',
    'GeForce',
    'Quadro',
    'RTX',
    'GTX',
    'AMD',
    'Radeon',
    'Intel',
    'Adreno',
    'Mali',
    'PowerVR',
    'SGX',
    'Tegra',
    'Vivante',
    'Apple'
  ];

  /** Trailing noise of a renderer string that is not part of the model. */
  static final RENDERER_NOISE:Array<String> = [' Direct3D', ' direct3D', ' vs_', ' ps_', ' (0x', ', D3D', ' OpenGL', ' Software Adapter'];

  /** Anything that looks like a driver version, e.g. "535.104.05". */
  static final VERSION_TOKEN_REGEX = ~/\d+\.\d+/;

  /** Human readable CPU vendor names for the identifiers the OS reports. */
  static final CPU_VENDOR_NAMES:Map<String, String> = [
    'GenuineIntel' => 'Intel',
    'AuthenticAMD' => 'AMD',
    'CentaurHauls' => 'Centaur',
    'HygonGenuine' => 'Hygon',
    'VIA VIA VIA' => 'VIA'
  ];

  static var resolved:Bool = false;
  static var cached:HardwareInfo = {
    gpuVendor: UNKNOWN,
    gpuModel: UNKNOWN,
    gpuDriver: UNKNOWN,
    cpuVendor: UNKNOWN,
    cpuModel: UNKNOWN,
    osName: UNKNOWN,
    osVersion: UNKNOWN,
    graphicsApi: UNKNOWN,
    audioApi: UNKNOWN
  };

  /**
   * The hardware information of this machine.
   *
   * The values are queried once and then cached, so calling this from a
   * script every frame is cheap.
   */
  public static function getSystemInfo():HardwareInfo
  {
    // The GPU can only be read while a render context exists, so the
    // detection runs again until it managed to read one.
    if (!resolved || (cached.gpuModel == UNKNOWN && hasRenderContext()))
    {
      cached = detect();
      resolved = true;
    }
    return cached;
  }

  /** The GPU model, e.g. "NVIDIA GeForce RTX 3060". */
  public static function getGPUName():String
    return getSystemInfo().gpuModel;

  /** The GPU vendor, e.g. "NVIDIA". */
  public static function getGPUVendor():String
    return getSystemInfo().gpuVendor;

  /** The GPU driver version, e.g. "535.104.05". */
  public static function getGPUDriverVersion():String
    return getSystemInfo().gpuDriver;

  /** The CPU model, e.g. "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz". */
  public static function getCPUName():String
    return getSystemInfo().cpuModel;

  /** The CPU vendor, e.g. "Intel". */
  public static function getCPUVendor():String
    return getSystemInfo().cpuVendor;

  /** The operating system, e.g. "Windows". */
  public static function getOSName():String
    return getSystemInfo().osName;

  /** The operating system version, e.g. "10.0.19045". */
  public static function getOSVersion():String
    return getSystemInfo().osVersion;

  /** The graphics API version, e.g. "OpenGL 4.6". */
  public static function getGraphicsApi():String
    return getSystemInfo().graphicsApi;

  /**
   * A short human readable report of the machine the game runs on.
   *
   * This is what ends up in the crash log, so a bug report carries the
   * hardware details without the user having to look them up.
   */
  public static function buildSystemInfo():String
  {
    var info:HardwareInfo = getSystemInfo();
    var lines:Array<String> = [];
    lines.push('GPU: ${info.gpuModel}');
    lines.push('GPU Vendor: ${info.gpuVendor}');
    lines.push('GPU Driver: ${info.gpuDriver}');
    lines.push('Graphics API: ${info.graphicsApi}');
    lines.push('CPU: ${info.cpuModel}');
    lines.push('CPU Vendor: ${info.cpuVendor}');
    lines.push('OS: ${info.osName} ${info.osVersion}');
    lines.push('Audio: ${info.audioApi}');
    return lines.join("\n");
  }

  /** The OpenGL version exactly as reported by the active driver. */
  public static function getOpenGLVersion():String
  {
    #if (lime_opengl || lime_opengles || lime_webgl)
    try
    {
      if (GL.context != null)
      {
        var version:Dynamic = GL.getParameter(GL.VERSION);
        if (version != null)
        {
          var text:String = StringTools.trim(Std.string(version));
          if (text.length > 0)
            return text;
        }
      }
    }
    catch (e:Dynamic) {}
    #end
    return 'Unable to detect';
  }

  /** Short runtime label used by debug overlays, e.g. "OpenGL ES 3.2". */
  public static function getOpenGLLabel():String
  {
    var api:String = parseGraphicsApi(getOpenGLVersion());
    if (api != UNKNOWN)
      return api;
    return 'OpenGL Unknown';
  }

  /** Reports the active OpenAL implementation and its exact runtime version. */
  public static function getOpenALSoftVersion():String
  {
    #if lime_openal
    try
    {
      var rawRenderer:Dynamic = AL.getString(AL.RENDERER);
      var rawVersion:Dynamic = AL.getString(AL.VERSION);
      var renderer:String = rawRenderer == null ? '' : StringTools.trim(Std.string(rawRenderer));
      var version:String = rawVersion == null ? '' : StringTools.trim(Std.string(rawVersion));
      if (renderer.length > 0 && version.length > 0)
        return version.indexOf(renderer) == -1 ? '$renderer | $version' : version;
      if (version.length > 0)
        return version;
      if (renderer.length > 0)
        return renderer;
    }
    catch (e:Dynamic) {}
    #end
    return 'Unable to detect';
  }

  /**
   * Gets a hint about which features the detected GPU can handle.
   *
   * Ported from the Psych Plus Engine.
   */
  public static function getGPUEnhancements():String
  {
    var gpuName:String = getSystemInfo().gpuModel;
    if (gpuName == null || gpuName == UNKNOWN)
      return "Unknown GPU - Using standard settings";

    var gpu:String = gpuName.toLowerCase();

    // Mobile GPUs (Android/iOS)
    if (gpu.indexOf('adreno') != -1)
    {
      var modelMatch = ~/(\d{3})/;
      if (modelMatch.match(gpu))
      {
        var model = Std.parseInt(modelMatch.matched(1));
        if (model >= 700)
          return "High-end mobile GPU (Adreno 7xx+) - Full features enabled";
        if (model >= 600)
          return "Mid-range mobile GPU (Adreno 6xx) - Good performance";
        return "Entry-level mobile GPU - Consider lowering quality";
      }
      return "Qualcomm Adreno GPU detected";
    }

    if (gpu.indexOf('mali') != -1)
    {
      if (gpu.indexOf('g7') != -1 || gpu.indexOf('g8') != -1)
        return "High-end mobile GPU (Mali-G7x/G8x) - Full features enabled";
      if (gpu.indexOf('g5') != -1 || gpu.indexOf('g6') != -1)
        return "Mid-range mobile GPU (Mali-G5x/G6x) - Good performance";
      return "ARM Mali GPU detected - Standard mobile settings";
    }

    if (gpu.indexOf('powervr') != -1 || gpu.indexOf('sgx') != -1)
      return "PowerVR GPU detected - Standard mobile settings";

    if (gpu.indexOf('tegra') != -1)
      return "NVIDIA Tegra GPU detected - Good mobile performance";

    // Desktop GPUs
    if (gpu.indexOf('rtx') != -1 || gpu.indexOf('rx 7') != -1 || gpu.indexOf('rx 6') != -1)
      return "High-end GPU detected - All features enabled";

    if (gpu.indexOf('gtx 16') != -1 || gpu.indexOf('gtx 10') != -1 || gpu.indexOf('rx 5') != -1 || gpu.indexOf('vega') != -1)
      return "Mid-range GPU detected - Full shader support";

    if (gpu.indexOf('intel') != -1 || gpu.indexOf('uhd') != -1 || gpu.indexOf('iris') != -1)
      return "Integrated GPU detected - Consider lowering quality for better performance";

    return "GPU detected - Standard features enabled";
  }

  /* ------------------------------------------------------------------ */
  /* Detection                                                          */
  /* ------------------------------------------------------------------ */

  static function detect():HardwareInfo
  {
    var vendor:String = '';
    var renderer:String = '';
    var version:String = '';

    #if (lime_opengl || lime_opengles || lime_webgl)
    if (hasRenderContext())
    {
      vendor = readGLString(GL.VENDOR);
      renderer = readGLString(GL.RENDERER);
      version = readGLString(GL.VERSION);
    }
    #end

    return {
      gpuVendor: parseGPUVendor(renderer, vendor),
      gpuModel: parseGPUModel(renderer),
      gpuDriver: parseGPUDriver(version),
      cpuVendor: cleanCPUVendor(NativeHardware.cpuVendor()),
      cpuModel: valueOrUnknown(NativeHardware.cpuModel()),
      osName: cleanOSName(NativeHardware.osName()),
      osVersion: valueOrUnknown(NativeHardware.osVersion()),
      graphicsApi: parseGraphicsApi(version),
      audioApi: getOpenALSoftVersion()
    };
  }

  /** Reads a string parameter (vendor, renderer, version) from the driver. */
  static function readGLString(parameter:Int):String
  {
    #if (lime_opengl || lime_opengles || lime_webgl)
    try
    {
      if (GL.context != null)
      {
        var value:Dynamic = GL.getParameter(parameter);
        if (value != null)
          return StringTools.trim(Std.string(value));
      }
    }
    catch (e:Dynamic) {}
    #end
    return '';
  }

  /** Whether a render context is available to ask the driver for the GPU. */
  static function hasRenderContext():Bool
  {
    #if (lime_opengl || lime_opengles || lime_webgl)
    return GL.context != null;
    #else
    return false;
    #end
  }

  /**
   * Extracts a human readable GPU model out of the renderer string.
   *
   * Ported from the Psych Plus Engine (`parseGPUName`), with a few extra
   * cases for the ANGLE strings Windows and Chrome report.
   */
  static function parseGPUModel(renderer:String):String
  {
    var info:String = cleanRenderer(renderer);
    if (info.length == 0)
      return UNKNOWN;

    // Mobile GPUs report a short marketing name, desktop ones the full device.
    if (info.indexOf('Adreno') != -1)
    {
      var adreno = ~/[Aa]dreno[^\d]*(\d{3})/;
      return adreno.match(info) ? 'Qualcomm Adreno ' + adreno.matched(1) : 'Qualcomm Adreno';
    }
    if (info.indexOf('Mali') != -1)
    {
      var mali = ~/Mali-?([GT]\w+)/;
      return mali.match(info) ? 'ARM Mali-' + mali.matched(1) : 'ARM Mali';
    }
    if (info.indexOf('PowerVR') != -1 || info.indexOf('SGX') != -1)
      return 'Imagination PowerVR';
    if (info.indexOf('Tegra') != -1)
      return 'NVIDIA Tegra';
    if (info.indexOf('Vivante') != -1)
      return 'Vivante GPU';

    var start:Int = findGPUKeyword(info);
    if (start == -1)
      return UNKNOWN;

    var model:String = cutRendererNoise(info.substring(start));
    return model.length > 0 ? model : UNKNOWN;
  }

  /** Works out the GPU vendor from the renderer, falling back to the vendor string. */
  static function parseGPUVendor(renderer:String, glVendor:String):String
  {
    var info:String = cleanRenderer(renderer);
    if (info.indexOf('NVIDIA') != -1 || info.indexOf('GeForce') != -1 || info.indexOf('RTX') != -1 || info.indexOf('GTX') != -1 || info.indexOf('Tegra') != -1)
      return 'NVIDIA';
    if (info.indexOf('AMD') != -1 || info.indexOf('Radeon') != -1)
      return 'AMD';
    if (info.indexOf('Intel') != -1)
      return 'Intel';
    if (info.indexOf('Adreno') != -1)
      return 'Qualcomm';
    if (info.indexOf('Mali') != -1)
      return 'ARM';
    if (info.indexOf('PowerVR') != -1 || info.indexOf('SGX') != -1)
      return 'Imagination Technologies';
    if (info.indexOf('Vivante') != -1)
      return 'Vivante';
    if (info.indexOf('Apple') != -1)
      return 'Apple';
    return cleanVendorName(glVendor);
  }

  /**
   * Pulls the driver version out of the OpenGL version string.
   *
   * "4.6.0 NVIDIA 535.104.05" -> "535.104.05"
   * "OpenGL ES 3.2 Mesa 23.2.1" -> "Mesa 23.2.1"
   */
  static function parseGPUDriver(glVersion:String):String
  {
    var text:String = cleanText(glVersion);
    if (text.length == 0)
      return UNKNOWN;

    var nvidia = ~/NVIDIA\s+([\d.]+)/;
    if (nvidia.match(text))
      return nvidia.matched(1);

    var mesa = ~/(Mesa\s+[\d.]+)/;
    if (mesa.match(text))
      return mesa.matched(1);

    var radeon = ~/(Radeon Software\s+[\d.]+)/;
    if (radeon.match(text))
      return radeon.matched(1);

    // Fall back to the last version looking token: the leading one is the
    // OpenGL version itself ("4.6.0 NVIDIA 535.104.05").
    var parts:Array<String> = API_PREFIX_REGEX.replace(text, ' ').split(' ');
    for (i in 0...parts.length)
    {
      var index:Int = parts.length - 1 - i;
      if (VERSION_TOKEN_REGEX.match(parts[index]))
        return parts[index];
    }
    return UNKNOWN;
  }

  /** Works out the graphics API version out of the OpenGL version string. */
  static function parseGraphicsApi(glVersion:String):String
  {
    var text:String = cleanText(glVersion);
    if (text.length == 0)
      return UNKNOWN;

    // The web reports "WebGL 1.0 (OpenGL ES 2.0 Chromium)", so WebGL has to
    // be checked before the OpenGL ES fallback.
    var webgl = ~/WebGL\s*([\d.]*)/;
    if (webgl.match(text))
      return 'WebGL ' + (webgl.matched(1).length > 0 ? webgl.matched(1) : '1.0');

    var es = ~/OpenGL ES\s+([\d.]+)/;
    if (es.match(text))
      return 'OpenGL ES ' + trimPatchVersion(es.matched(1));

    var gl = ~/(?:^|\s)([0-9]+(?:\.[0-9]+){1,2})/;
    if (gl.match(text))
      return 'OpenGL ' + trimPatchVersion(gl.matched(1));

    return UNKNOWN;
  }

  /** Strips the API prefix and unwraps the ANGLE strings. */
  static function cleanRenderer(renderer:String):String
  {
    var info:String = cleanText(renderer);
    if (info.length == 0)
      return '';

    // "OpenGL ES 3.2 Adreno (TM) 650" -> "Adreno (TM) 650"
    info = API_PREFIX_REGEX.replace(info, '');

    // "ANGLE (Intel, Intel(R) UHD Graphics 620 (0x00005917) Direct3D11 vs_5_0 ps_5_0, D3D11)"
    //   -> "Intel(R) UHD Graphics 620 (0x00005917) Direct3D11 vs_5_0 ps_5_0"
    var angle:Int = info.indexOf('ANGLE (');
    if (angle != -1)
    {
      var inner:String = info.substring(angle + 7);
      var end:Int = inner.lastIndexOf(')');
      if (end != -1)
        inner = inner.substring(0, end);
      var parts:Array<String> = inner.split(',');
      info = StringTools.trim(parts.length > 1 ? parts[1] : inner);
    }
    return StringTools.trim(info);
  }

  /** Removes the parts of a renderer string that are not part of the model. */
  static function cutRendererNoise(text:String):String
  {
    var result:String = text;
    for (marker in RENDERER_NOISE)
    {
      var index:Int = result.indexOf(marker);
      if (index != -1)
        result = result.substring(0, index);
    }
    // The device path ("/PCIe/SSE2") is noise as well.
    var slash:Int = result.indexOf('/');
    if (slash != -1)
      result = result.substring(0, slash);
    return StringTools.trim(result);
  }

  /** Finds the first vendor keyword inside a renderer string. */
  static function findGPUKeyword(info:String):Int
  {
    var best:Int = -1;
    for (keyword in GPU_KEYWORDS)
    {
      var index:Int = info.indexOf(keyword);
      if (index == -1)
        continue;
      if (best == -1 || index < best)
        best = index;
    }
    return best;
  }

  /** Cleans up the vendor string the driver reports. */
  static function cleanVendorName(vendor:String):String
  {
    var value:String = cleanText(vendor);
    if (value.length == 0)
      return UNKNOWN;
    if (value.indexOf('NVIDIA') != -1)
      return 'NVIDIA';
    if (value.indexOf('AMD') != -1 || value.indexOf('ATI') != -1)
      return 'AMD';
    if (value.indexOf('Intel') != -1)
      return 'Intel';
    if (value.indexOf('Apple') != -1)
      return 'Apple';
    if (value.indexOf('Qualcomm') != -1)
      return 'Qualcomm';
    if (value.indexOf('ARM') != -1)
      return 'ARM';
    if (value.indexOf('Mesa') != -1)
      return 'Mesa';
    if (value.indexOf('Imagination') != -1)
      return 'Imagination Technologies';
    return value;
  }

  /** Turns the CPU vendor identifier into a readable name. */
  static function cleanCPUVendor(vendor:String):String
  {
    var value:String = cleanText(vendor);
    if (value.length == 0)
      return UNKNOWN;
    if (CPU_VENDOR_NAMES.exists(value))
      return CPU_VENDOR_NAMES.get(value);
    return value;
  }

  /** The operating system name, with the kernel name mapped to a real one. */
  static function cleanOSName(name:String):String
  {
    #if android
    // uname only knows the kernel, the engine runs on Android.
    return 'Android';
    #else
    var value:String = cleanText(name);
    if (value.length == 0)
      return UNKNOWN;
    if (value == 'Darwin')
      return 'macOS';
    return value;
    #end
  }

  /** Trims a value, an empty value stays empty. */
  static function cleanText(value:Null<String>):String
  {
    if (value == null)
      return '';
    return StringTools.trim(value);
  }

  /** Trims a value and falls back to "Unknown" when there is nothing left. */
  static function valueOrUnknown(value:Null<String>):String
  {
    var text:String = cleanText(value);
    return text.length > 0 ? text : UNKNOWN;
  }

  /** Drops a trailing ".0" so "4.6.0" is reported as "4.6". */
  static function trimPatchVersion(version:String):String
  {
    var parts:Array<String> = version.split('.');
    while (parts.length > 2 && parts[parts.length - 1] == '0')
      parts.pop();
    return parts.join('.');
  }
}
