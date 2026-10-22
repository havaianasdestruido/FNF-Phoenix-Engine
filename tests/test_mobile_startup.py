"""Android cold-start regressions, without the game haxelibs or an Android SDK.

Source checks cover Main/manifest wiring. With Haxe installed, execute the
production StorageUtil and FlxGame.resizeGame against small boundary stubs;
this reproduces the pre-ADDED_TO_STAGE null-state crash without a renderer.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def resize_method() -> str:
    source = read("source/source-haxelib-patches/flixel/FlxGame.hx")
    start = source.index("function resizeGame(width:Int, height:Int):Void")
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    return source[start:end]


class MobileStartupTests(unittest.TestCase):
    def test_app_owned_storage_does_not_request_runtime_permissions(self):
        storage = read("source/mobile/StorageUtil.hx")
        main = read("source/Main.hx")
        for obsolete in ("AndroidPermissions", "requestPermissions(", "getGrantedPermissions(",
                         "expect a crash", "Press OK to see what happens"):
            with self.subTest(obsolete=obsolete):
                self.assertNotIn(obsolete, storage + main)
        self.assertIn("getAndroidStorageDirectory()", storage)
        self.assertIn("'quack.fnf.phoenix.android.PhoenixCore', 'getExternalFilesDir'", storage)
        self.assertIn("'()Ljava/lang/String;'", storage)
        core = read("source/android/src/quack/fnf/phoenix/android/PhoenixCore.java")
        native_getter = core.split("public static String getExternalFilesDir()", 1)[1].split(
            "public static String getExternalStorageDirectory()", 1
        )[0]
        self.assertIn("mainContext.getExternalFilesDir(null)", native_getter)
        self.assertRegex(native_getter, r'if \(dir == null\)\s*return "";')
        self.assertIn("Path.isAbsolute(directory)", storage)
        self.assertIn("FileSystem.isDirectory(directory)", storage)
        self.assertIn("Sys.setCwd(directory)", storage)

    def test_storage_failure_stops_before_game_or_asset_initialization(self):
        main = read("source/Main.hx")
        self.assertRegex(main, r"if \(!mobile\.StorageUtil\.initStorageDirectory\(\)\)\s*\{\s*"
                              r"lime\.system\.System\.exit\(1\);\s*return;\s*\}")
        self.assertLess(main.index("mobile.StorageUtil.initStorageDirectory()"), main.index("setupGame();"))
        self.assertNotIn("Sys.setCwd(", main)  # chdir belongs inside StorageUtil's error boundary

    def test_manifest_omits_broad_storage_and_media_permissions(self):
        project = read("project.hxp")
        self.assertIn('config.push("android.permission", permission, true);', project)
        permissions = set(re.findall(r'"android\.permission\.([A-Z_]+)"', project))
        self.assertFalse(permissions & {"READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE", "MANAGE_EXTERNAL_STORAGE",
                                       "ACCESS_MEDIA_LOCATION", "READ_MEDIA_IMAGES", "READ_MEDIA_VIDEO",
                                       "READ_MEDIA_AUDIO", "READ_MEDIA_VISUAL_USER_SELECTED"})
        self.assertTrue({"INTERNET", "VIBRATE", "WAKE_LOCK", "POST_NOTIFICATIONS",
                         "FOREGROUND_SERVICE", "FOREGROUND_SERVICE_MEDIA_PLAYBACK"} <= permissions)

    def test_platform_timers_start_after_the_initial_state_reset(self):
        main = read("source/Main.hx")
        self.assertRegex(main, r"postGameStart\.addOnce\(function\(\)\s*\{\s*"
                              r"android\.platform\.AndroidPlatform\.init\(\);\s*\}\);")
        self.assertEqual(main.count("android.platform.AndroidPlatform.init()"), 1)
        self.assertLess(main.index("new FunkinGame("), main.index("postGameStart.addOnce("))
        self.assertLess(main.index("postGameStart.addOnce("), main.index("addChild(funkinGame);"))

    def test_pre_state_resize_applies_viewport_but_defers_state_callbacks(self):
        method = resize_method()
        guard = re.search(r"if \(_state == null\)\s*(?:\{\s*)?return;", method)
        self.assertIsNotNone(guard)
        self.assertLess(method.index("FlxG.resizeGame(width, height)"), guard.start())
        for callback in ("_state.onResize", "_state.subState", "debugger.onResize", "FlxG.signals.gameResized.dispatch"):
            self.assertLess(guard.end(), method.index(callback))
        game = read("source/source-haxelib-patches/flixel/FlxGame.hx")
        create = game.split("function create(_):Void", 1)[1].split("function onFocus", 1)[0]
        self.assertLess(create.index("switchState();"), create.index("resizeGame(FlxG.stage.stageWidth"))

    def run_haxe(self, files: dict[str, str], main: str, *defines: str):
        haxe = os.environ.get("HAXE") or shutil.which("haxe")
        if not haxe:
            self.skipTest("Haxe unavailable; the Haxe CI job runs these behavioral tests")
        with tempfile.TemporaryDirectory(prefix="phoenix-startup-") as directory:
            root = Path(directory)
            for name, source in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source, encoding="utf-8")
            command = [haxe, "-cp", str(root), "-main", main, "--interp"]
            for define in defines:
                command.extend(["-D", define])
            result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("passed", result.stdout)

    def test_storage_first_launch_relaunch_and_unavailable_directory(self):
        self.run_haxe({
            "mobile/StorageUtil.hx": read("source/mobile/StorageUtil.hx"),
            "backend/CoolUtil.hx": """
package backend;
class CoolUtil {
  public static var messages:Array<String> = [];
  public static function showPopUp(message:String, title:String):Void {
    messages.push(title + ": " + message);
  }
}
""",
            "lime/system/JNI.hx": """
package lime.system;
class JNI {
  public static var directory:String;
  public static var fail:Bool = false;
  public static function createStaticMethod(className:String, method:String, signature:String):Dynamic {
    if (className != "quack.fnf.phoenix.android.PhoenixCore" || method != "getExternalFilesDir"
        || signature != "()Ljava/lang/String;") throw "Incorrect storage JNI binding";
    return function():String {
      if (fail) throw new haxe.Exception("Storage lookup failed");
      return directory;
    };
  }
}
""",
            "StorageStartupSpec.hx": """
import lime.system.JNI;
import backend.CoolUtil;
import haxe.io.Path;
import mobile.StorageUtil;
import sys.FileSystem;
import sys.io.File;

class StorageStartupSpec {
  static function check(value:Bool, message:String):Void {
    if (!value) throw message;
  }

  static function main():Void {
    final original = Sys.getCwd();
    final storage = Path.join([original, "app-files"]);
    JNI.directory = storage;
    // There is deliberately no Permissions stub: startup must not use it,
    // regardless of Android version or previously granted/denied permissions.
    check(StorageUtil.initStorageDirectory(), "fresh installation");
    check(FileSystem.isDirectory(storage), "create app directory");
    check(Path.normalize(Sys.getCwd()) == Path.normalize(storage), "switch cwd");
    check(FileSystem.isDirectory("mods"), "create the mods directory the SAF root exposes");
    File.saveContent("mods/keep.txt", "keep existing mods");
    File.saveContent("player-data.txt", "keep existing data");
    Sys.setCwd(original);
    check(StorageUtil.initStorageDirectory(), "relaunch");
    check(File.getContent("player-data.txt") == "keep existing data", "preserve user data");
    check(File.getContent("mods/keep.txt") == "keep existing mods", "preserve existing mods");
    check(CoolUtil.messages.length == 0, "no first-run permission notice");
    Sys.setCwd(original);

    final blocker = Path.join([original, "not-a-directory"]);
    File.saveContent(blocker, "do not overwrite");
    final invalid:Array<String> = [null, "", "relative/path", blocker, blocker + "/child"];
    for (directory in invalid) {
      JNI.directory = directory;
      final previousErrors = CoolUtil.messages.length;
      check(!StorageUtil.initStorageDirectory(), "reject invalid path: " + directory);
      check(Sys.getCwd() == original, "failed init must preserve cwd");
      check(CoolUtil.messages.length == previousErrors + 1, "one useful storage error");
      check(StringTools.startsWith(CoolUtil.messages[previousErrors], "Storage unavailable:"), "error title");
    }
    JNI.fail = true;
    check(!StorageUtil.initStorageDirectory(), "handle native lookup exception");
    check(Sys.getCwd() == original, "lookup failure must preserve cwd");
    check(File.getContent(blocker) == "do not overwrite", "failure must not delete data");
    Sys.println("StorageStartupSpec passed");
  }
}
""",
        }, "StorageStartupSpec", "android", "mobile")

    def test_resize_before_first_state_and_normal_runtime_resize(self):
        self.run_haxe({
            "ResizeUnderTest.hx": """
import flixel.FlxG;
class ResizeUnderTest {
  public var _state:Dynamic;
  public var debugger:Dynamic;
  public function new() {}
  public """ + resize_method() + "\n}\n",
            "flixel/FlxG.hx": """
package flixel;
class FlxG {
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var camera:Dynamic;
  public static var cameraResizes:Int = 0;
  public static var resizeSignals:Int = 0;
  public static var cameras = {
    list: new Array<Dynamic>(),
    resize: function() { cameraResizes++; }
  };
  public static var worldBounds:Dynamic = {
    x: -10, y: -10, width: 1300, height: 740,
    set: function(x:Int, y:Int, w:Int, h:Int) {
      worldBounds.x = x; worldBounds.y = y;
      worldBounds.width = w; worldBounds.height = h;
    }
  };
  public static var signals = {
    gameResized: {dispatch: function(w:Int, h:Int) { resizeSignals++; }}
  };
  public static function resizeGame(w:Int, h:Int):Void { width = w; height = h; }
}
""",
            "StartupResizeSpec.hx": """
import flixel.FlxG;
class StartupResizeSpec {
  static function check(value:Bool, message:String):Void {
    if (!value) throw message;
  }
  static function main():Void {
    // Both a fresh install and a relaunch install the scale mode before
    // ADDED_TO_STAGE, when neither _state nor debugger exists.
    for (launch in 0...2) {
      final cold = new ResizeUnderTest();
      cold.resizeGame(1600, 900);
      check(FlxG.width == 1600 && FlxG.height == 900, "early viewport application");
      check(FlxG.resizeSignals == 0 && FlxG.cameraResizes == 0, "defer callbacks");
      cold.resizeGame(0, 0);
      check(FlxG.width == 1600 && FlxG.height == 900, "ignore missing surface");
    }

    FlxG.width = 1280; FlxG.height = 720;
    FlxG.camera = {width: 1280, height: 720, scroll: {x: 0.0, y: 0.0},
      setSize: function(w:Int, h:Int) { FlxG.camera.width = w; FlxG.camera.height = h; }};
    FlxG.cameras.list.push(FlxG.camera);
    final game = new ResizeUnderTest();
    var stateCalls = 0;
    var subStateCalls = 0;
    var debugCalls = 0;
    game._state = {
      onResize: function(w:Int, h:Int) { stateCalls++; },
      subState: {onResize: function(w:Int, h:Int) { subStateCalls++; }}
    };
    game.debugger = {onResize: function(w:Int, h:Int) { debugCalls++; }};
    game.resizeGame(1600, 900);
    check(stateCalls == 1 && subStateCalls == 1 && debugCalls == 1, "live resize callbacks");
    check(FlxG.camera.width == 1600 && FlxG.camera.height == 900, "resize cameras");
    check(FlxG.camera.scroll.x == -160 && FlxG.camera.scroll.y == -90, "camera center");
    check(FlxG.worldBounds.width == 1620 && FlxG.worldBounds.height == 920, "world bounds");
    check(FlxG.resizeSignals == 1 && FlxG.cameraResizes == 1, "notify after state creation");
    game._state.subState = null;
    game.resizeGame(1600, 900);
    check(stateCalls == 2 && subStateCalls == 1, "resize without a substate");
    Sys.println("StartupResizeSpec passed");
  }
}
""",
        }, "StartupResizeSpec", "FLX_DEBUG")


if __name__ == "__main__":
    unittest.main()
