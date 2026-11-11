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
      customCache:Null<String> = null, disableDefault:Bool = false, customDefine:Null<String> = null, compact:Bool = true,
      moddingLevel:Null<String> = null):Project
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
    if (compact) HXProject._userDefines.set("NO_BUILTIN_CONTENT", "1");
    if (disableDefault)
      HXProject._userDefines.set("NO_HXCPP_COMPILE_CACHE", "1");
    if (customDefine != null)
      HXProject._userDefines.set("HXCPP_COMPILE_CACHE", customDefine);
    // `-DMODDING_LEVEL=n` arrives as a user define, exactly like Lime does it.
    if (moddingLevel != null)
      HXProject._userDefines.set("MODDING_LEVEL", moddingLevel);
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

    // Inspect the actual packaged paths, not just the existence of source files.
    project = makeProject(host, [], "build");
    for (path in [
      "assets/weeks/tutorial.json", "assets/weeks/week1.json", "assets/weeks/weekList.txt",
      "assets/data/tutorial/tutorial.json", "assets/data/bopeebo/bopeebo.json",
      "assets/data/fresh/fresh.json", "assets/data/dad-battle/dad-battle.json",
      "assets/songs/tutorial/Inst.ogg", "assets/songs/bopeebo/Inst.ogg",
      "assets/songs/fresh/Inst.ogg", "assets/songs/dad-battle/Inst.ogg",
      "assets/characters/bf.json", "assets/characters/bf-dead.json", "assets/characters/gf.json", "assets/characters/dad.json",
      "assets/stages/stage.json", "assets/shared/images/characters/BOYFRIEND.png",
      "assets/shared/images/characters/BOYFRIEND.xml", "assets/shared/images/characters/BOYFRIEND_DEAD.png",
      "assets/shared/images/characters/GF_assets.png", "assets/shared/images/characters/DADDY_DEAREST.png",
      "assets/shared/images/stageback.png", "assets/shared/images/stagefront.png", "assets/shared/images/stagecurtains.png",
      "assets/shared/images/stage_light.png", "assets/shared/images/spotlight.png", "assets/shared/images/smoke.png",
      "assets/images/icons/icon-bf.png", "assets/images/icons/icon-dad.png", "assets/images/icons/icon-gf.png",
      "assets/images/menucharacters/Menu_BF.png", "assets/images/storymenu/week1.png", "assets/images/gfDanceTitle.png"
    ])
    {
      var found = [for (asset in project.assets) if (asset.targetPath == path) asset];
      assertEquals(1, found.length, 'compact build asset $path');
      if (path == "assets/weeks/weekList.txt")
        assertEquals("setup/ci-weekList.txt", found[0].sourcePath, "compact week list");
    }
    // A normal (unflagged) project includes later weeks and their assets.
    project = makeProject(host, [], "build", null, false, null, false);
    assertEquals(false, project.defines.exists("NO_BUILTIN_CONTENT"), "normal build defaults to full content");
    for (path in ["assets/weeks/week2.json", "assets/data/spookeez/spookeez.json",
      "assets/songs/spookeez/Inst.ogg", "assets/week2/images/halloween_bg.png"])
      assertEquals(1, [for (asset in project.assets) if (asset.targetPath == path) asset].length, 'full build asset $path');
    project = makeProject(host, [], "build");
    for (path in ["assets/weeks/week2.json", "assets/data/spookeez/spookeez.json",
      "assets/songs/spookeez/Inst.ogg", "assets/week2/images/halloween_bg.png"])
      assertEquals(0, [for (asset in project.assets) if (asset.targetPath == path) asset].length, 'compact build excludes $path');
    // -----------------------------------------------------------------
    // Script modding level 2 (Lua + Python) is the default on every native
    // target. Lime's `cpp` target flag is deliberately NOT set for a plain
    // per-platform build, which is exactly the case that regressed before.
    // -----------------------------------------------------------------
    // A native build always defines LUA_ALLOWED/PYTHON_ALLOWED and puts both
    // interpreters on the classpath. Lime needs an explicit `cpp` flag only
    // to cross-compile to another desktop OS; that case is covered too.
    function checkNative(target:Platform, flags:Map<String, String>, label:String):Void
    {
      var project = makeProject(target, flags, "build", null, false, null, true);
      assertEquals("cpp", project.defines.get("targetType"), 'native target type for $label');
      assertEquals(true, project.haxedefs.exists("LUA_ALLOWED"), 'Lua is on by default for $label');
      assertEquals(true, project.haxedefs.exists("PYTHON_ALLOWED"), 'Python is on by default for $label');
      assertEquals(1, [for (lib in project.haxelibs) if (lib.name == "hxluajit") lib].length,
        'hxluajit is on the classpath for $label');
      assertEquals(1, [for (lib in project.haxelibs) if (lib.name == "hython") lib].length,
        'hython is on the classpath for $label');
    }

    // The host's own platform build, exactly how `lime build <host>` runs.
    checkNative(host, [], '$host (host, no flags)');
    // Mobile needs no flag at all; it is not a desktop cross-compile.
    for (target in [Platform.ANDROID, Platform.IOS])
      checkNative(target, [], '$target (no flags)');
    // Cross-compiling another desktop OS: Lime only makes it C++ with -cpp,
    // which is the flag that used to gate (and so disable) Lua.
    for (target in [Platform.WINDOWS, Platform.LINUX, Platform.MAC])
      if (target != host)
        checkNative(target, ["cpp" => ""], '$target (cross-compiled with -cpp)');

    // The level flag still overrides the default, in both directions.
    var level0 = makeProject(host, [], "build", null, false, null, true, "0");
    assertEquals(false, level0.haxedefs.exists("LUA_ALLOWED"), "level 0 removes Lua");
    assertEquals(false, level0.haxedefs.exists("PYTHON_ALLOWED"), "level 0 removes Python");
    assertEquals(0, [for (lib in level0.haxelibs) if (lib.name == "hxluajit") lib].length,
      "level 0 removes the Lua bindings");
    var level1 = makeProject(host, [], "build", null, false, null, true, "1");
    assertEquals(true, level1.haxedefs.exists("LUA_ALLOWED"), "level 1 keeps Lua");
    assertEquals(false, level1.haxedefs.exists("PYTHON_ALLOWED"), "level 1 drops Python");
    assertEquals(1, [for (lib in level1.haxelibs) if (lib.name == "hxluajit") lib].length,
      "level 1 keeps the Lua bindings");

    // Web/Flash/AIR cannot link LuaJIT and must stay without Lua/Python even
    // though they are not desktop or mobile.
    for (target in [Platform.HTML5, Platform.FLASH, Platform.AIR])
    {
      var project = makeProject(target, [], "build", null, false, null, true);
      assertEquals(false, project.haxedefs.exists("LUA_ALLOWED"), 'no Lua on $target');
      assertEquals(false, project.haxedefs.exists("PYTHON_ALLOWED"), 'no Python on $target');
    }

    Sys.putEnv("HXCPP_COMPILE_CACHE", null);
    Sys.println("Project build-cache and script-modding configuration: OK");
  }
}
