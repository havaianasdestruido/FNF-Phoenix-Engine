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
      customCache:Null<String> = null, disableDefault:Bool = false, customDefine:Null<String> = null, compact:Bool = true):Project
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
    var laterContent = ["assets/weeks/week2.json", "assets/data/spookeez/spookeez.json",
      "assets/songs/spookeez/Inst.ogg"];
    // Every later library must package the real source path into its matching
    // library, while compact builds must not include any of these files.
    var laterLibraries = [
      "week2" => "images/halloween_bg.png",
      "week3" => "images/philly/city.png",
      "week4" => "images/gore/coldHeartKiller.png",
      "week5" => "images/christmas/bgWalls.png",
      "week6" => "images/weeb/animatedEvilSchool.png",
      "week7" => "images/cutscenes/guns.png",
      "weekend1" => "images/CanImpactParticle.png"
    ];
    for (library => relativePath in laterLibraries)
    {
      var path = 'assets/$library/$relativePath';
      laterContent.push(path);
      var found = [for (asset in project.assets) if (asset.targetPath == path) asset];
      assertEquals(1, found.length, 'full build asset $path');
      assertEquals(path, found[0].sourcePath, 'full build source for $path');
      assertEquals(library, found[0].library, 'full build library for $path');
    }
    for (path in laterContent)
      assertEquals(1, [for (asset in project.assets) if (asset.targetPath == path) asset].length, 'full build asset $path');
    project = makeProject(host, [], "build");
    for (path in laterContent)
      assertEquals(0, [for (asset in project.assets) if (asset.targetPath == path) asset].length, 'compact build excludes $path');
    Sys.putEnv("HXCPP_COMPILE_CACHE", null);
    Sys.println("Project build-cache configuration: OK");
  }
}
