package backend;

import backend.ClientPrefs;
import backend.FramerateController;
import backend.Native;
import backend.Native.HardwareInfo;
import debug.system.SystemInfo;
import flixel.FlxG;

/**
 * Chooses and applies a one-time, editable starting performance setup.
 * The selector is deliberately pure so its hardware thresholds can be tested
 * without a Lime/Flixel runtime.
 */
typedef PerformancePreset =
{
  var name:String;
  var framerate:Int;
  var lowQuality:Bool;
  var shaders:Bool;
  var cacheOnGPU:Bool;
  var dynamicSpawnTime:Bool;
  var enableGC:Bool;
  var noRenderGC:Bool;
  var maxSplashLimit:Int;
};

class FirstRunPerformance
{
  /** Bump only when deliberately re-running the first-run setup for everyone. */
  public static inline var CURRENT_VERSION:Int = 1;

  static var notice:String = null;

  /**
   * Pure hardware-based selector. Zero RAM means unavailable; a zero CPU
   * count likewise contributes no evidence. Unknown GPUs are never assumed
   * fast, and GPU texture caching stays off in every preset for compatibility.
   */
  public static function choose(ramBytes:Float, logicalCpus:Int, gpuModel:String, gpuGuidance:String, mobile:Bool):PerformancePreset
  {
    final model:String = gpuModel == null ? '' : gpuModel.toLowerCase();
    final guidance:String = gpuGuidance == null ? '' : gpuGuidance.toLowerCase();
    final softwareGpu:Bool = containsAny(model, ['llvmpipe', 'swiftshader', 'software rasterizer', 'software adapter']);
    final weakGpu:Bool = softwareGpu || containsAny(guidance, ['entry-level']);
    final integratedGpu:Bool = guidance.indexOf('integrated gpu') >= 0;
    final lowMemory:Bool = ramBytes > 0 && ramBytes < 3.0 * 1024 * 1024 * 1024;
    final lowCpu:Bool = logicalCpus > 0 && logicalCpus <= 2;
    final entryPhone:Bool = mobile
      && ((ramBytes > 0 && ramBytes < 4.0 * 1024 * 1024 * 1024)
        || (logicalCpus > 0 && logicalCpus <= 4));

    if (lowMemory || lowCpu || weakGpu || entryPhone)
      return {
        name: 'Performance', framerate: 45, lowQuality: true, shaders: false,
        cacheOnGPU: false, dynamicSpawnTime: true, enableGC: true,
        noRenderGC: true, maxSplashLimit: 4
      };

    final constrainedMemory:Bool = ramBytes > 0 && ramBytes < 6.0 * 1024 * 1024 * 1024;
    final constrainedCpu:Bool = logicalCpus > 0 && logicalCpus <= 4;
    if (mobile || constrainedMemory || constrainedCpu || integratedGpu)
      return {
        name: 'Balanced', framerate: 60, lowQuality: false, shaders: true,
        cacheOnGPU: false, dynamicSpawnTime: true, enableGC: true,
        noRenderGC: false, maxSplashLimit: 12
      };

    final knownGpu:Bool = model.length > 0 && model != Native.UNKNOWN.toLowerCase();
    if (ramBytes >= 8.0 * 1024 * 1024 * 1024 && logicalCpus >= 6 && knownGpu)
      return {
        name: 'High quality', framerate: 120, lowQuality: false, shaders: true,
        cacheOnGPU: false, dynamicSpawnTime: true, enableGC: true,
        noRenderGC: false, maxSplashLimit: 24
      };

    return {
      name: 'Balanced', framerate: 60, lowQuality: false, shaders: true,
      cacheOnGPU: false, dynamicSpawnTime: true, enableGC: true,
      noRenderGC: false, maxSplashLimit: 12
    };
  }

  /**
   * Apply only on a genuinely empty settings file. Existing installs get the
   * marker but keep their choices. Called at the end of ClientPrefs.loadPrefs,
   * after save data and memory profiles have been restored.
   */
  public static function applyOnFirstRun():Bool
  {
    if (ClientPrefs.firstRunPerformanceVersion >= CURRENT_VERSION)
      return false;

    final hasExistingSettings:Bool = FlxG.save != null && FlxG.save.data != null && Reflect.fields(FlxG.save.data).length > 0;
    ClientPrefs.firstRunPerformanceVersion = CURRENT_VERSION;
    if (hasExistingSettings)
    {
      ClientPrefs.saveSettings();
      return false;
    }

    final hardware:HardwareInfo = Native.getSystemInfo();
    #if cpp
    final ramBytes:Float = SystemInfo.totalPhysicalMemory();
    final logicalCpus:Int = SystemInfo.logicalCPUCount();
    #else
    // Portable fallbacks intentionally report unknown rather than pretending
    // their conservative placeholder CPU count is a measured low-end device.
    final ramBytes:Float = 0;
    final logicalCpus:Int = 0;
    #end
    final preset:PerformancePreset = choose(
      ramBytes, logicalCpus, hardware.gpuModel,
      Native.getGPUEnhancements(),
      #if (android || ios) true #else false #end
    );

    ClientPrefs.framerate = preset.framerate;
    ClientPrefs.lowQuality = preset.lowQuality;
    ClientPrefs.shaders = preset.shaders;
    ClientPrefs.cacheOnGPU = preset.cacheOnGPU;
    ClientPrefs.dynamicSpawnTime = preset.dynamicSpawnTime;
    ClientPrefs.enableGC = preset.enableGC;
    ClientPrefs.noRenderGC = preset.noRenderGC;
    ClientPrefs.maxSplashLimit = preset.maxSplashLimit;
    FramerateController.apply(preset.framerate);

    notice = 'Applied the ${preset.name} first-run performance setup (${preset.framerate} FPS).\n'
      + 'You can edit every setting in Options: Graphics, Optimization and Visuals & UI.';
    ClientPrefs.saveSettings();
    return true;
  }

  /** Consume the optional title-screen notice once, without showing it again. */
  public static function takeNotice():String
  {
    final value:String = notice;
    notice = null;
    return value;
  }

  static function containsAny(text:String, values:Array<String>):Bool
  {
    for (value in values) if (text.indexOf(value) >= 0) return true;
    return false;
  }
}
