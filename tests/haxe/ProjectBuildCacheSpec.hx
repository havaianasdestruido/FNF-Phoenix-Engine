import hxp.System as HxpSystem;
import lime.tools.HXProject;
import lime.tools.Platform;

/** Exercises the real project.hxp with the pinned Lime API, without building the game. */
class ProjectBuildCacheSpec
{
  static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void
  {
    if (expected != actual)
      throw '$message: expected $expected, got $actual';
  }

  static function makeProject(target:Platform, flags:Map<String, String>, command:String = "build",
      customCache:Null<String> = null, disableDefault:Bool = false, customDefine:Null<String> = null):Project
  {
    // Project.setenv mutates the current process as well as the returned map.
    // Start each scenario with a fresh environment, just as a Lime invocation does.
    Sys.putEnv("HXCPP_COMPILE_CACHE", customCache);
    HXProject._command = command;
    HXProject._debug = false;
    HXProject._target = target;
    HXProject._targetFlags = flags;
    HXProject._templatePaths = [];
    HXProject._environment = Sys.environment();
    HXProject._userDefines = [];
    if (disableDefault)
      HXProject._userDefines.set("NO_HXCPP_COMPILE_CACHE", "1");
    if (customDefine != null)
      HXProject._userDefines.set("HXCPP_COMPILE_CACHE", customDefine);
    return new Project();
  }

  static function checkDefault(target:Platform, flags:Map<String, String>, command:String):Void
  {
    var project = makeProject(target, flags, command);
    var expected = sys.FileSystem.fullPath(".") + "/.hxcpp_cache";
    assertEquals("cpp", project.defines.get("targetType"), 'target type for $target');
    assertEquals(expected, project.environment.get("HXCPP_COMPILE_CACHE"), 'default cache for $target/$command');
    // Lime evaluates project.hxp in a subprocess and serializes it back.
    var copy:HXProject = cast haxe.Unserializer.run(haxe.Serializer.run(project));
    assertEquals(expected, copy.environment.get("HXCPP_COMPILE_CACHE"), "cache survives Lime serialization");
  }

  static function main():Void
  {
    var host:Platform = cast HxpSystem.hostPlatform;
    // The normal `lime build windows/linux/mac` has no explicit "cpp" flag.
    checkDefault(host, [], "build");
    checkDefault(host, [], "test");
    for (target in [Platform.ANDROID, Platform.IOS])
      checkDefault(target, [], "build");
    // Explicit cross-compilation to Windows from non-Windows hosts.
    checkDefault(Platform.WINDOWS, ["cpp" => ""], "build");

    var custom = sys.FileSystem.fullPath(".") + "/custom cache path";
    var project = makeProject(host, [], "build", custom);
    assertEquals(custom, project.environment.get("HXCPP_COMPILE_CACHE"), "caller-supplied cache");
    project = makeProject(host, [], "build", null, false, custom);
    assertEquals(null, project.environment.get("HXCPP_COMPILE_CACHE"), "explicit define suppresses default");
    assertEquals(custom, project.defines.get("HXCPP_COMPILE_CACHE"), "caller-supplied cache define");

    project = makeProject(host, [], "build", null, true);
    assertEquals(null, project.environment.get("HXCPP_COMPILE_CACHE"), "opt out of the default cache");
    project = makeProject(host, [], "build", custom, true);
    assertEquals(custom, project.environment.get("HXCPP_COMPILE_CACHE"), "explicit cache still wins");

    for (command in ["display", "update", "clean"])
    {
      project = makeProject(host, [], command);
      assertEquals(null, project.environment.get("HXCPP_COMPILE_CACHE"), '$command does not enable caching');
    }
    for (target in [Platform.HTML5, Platform.FLASH, Platform.AIR])
    {
      project = makeProject(target, [], "build");
      assertEquals(null, project.environment.get("HXCPP_COMPILE_CACHE"), 'non-C++ target $target');
    }
    project = makeProject(host, ["neko" => ""], "build");
    assertEquals(null, project.environment.get("HXCPP_COMPILE_CACHE"), "Neko does not use hxcpp");

    Sys.putEnv("HXCPP_COMPILE_CACHE", null);
    Sys.println("Project build-cache configuration: OK");
  }
}
