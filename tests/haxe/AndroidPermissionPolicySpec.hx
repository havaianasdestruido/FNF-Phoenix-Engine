import lime.tools.HXProject;
import lime.tools.Platform;
import sys.io.File;

/**
 * Exercises the real Android project configuration and manifest template.
 * The merged APK manifest is checked again by CI after Gradle runs, because
 * dependency manifests can contribute permissions that the HXP never lists.
 */
class AndroidPermissionPolicySpec
{
  static final REQUIRED_PERMISSIONS:Array<String> = [
    "android.permission.WAKE_LOCK",
    "android.permission.INTERNET",
    "android.permission.VIBRATE",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"
  ];

  static final BROAD_PERMISSIONS:Array<String> = [
    "android.permission.ACCESS_MEDIA_LOCATION",
    "android.permission.MANAGE_EXTERNAL_STORAGE",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_MEDIA_AUDIO",
    "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE"
  ];

  static function check(ok:Bool, message:String):Void
  {
    if (!ok) throw message;
  }

  static function makeProject(target:Platform):Project
  {
    HXProject._command = "build";
    HXProject._debug = false;
    HXProject._target = target;
    HXProject._targetFlags = [];
    HXProject._templatePaths = [];
    HXProject._environment = Sys.environment();
    HXProject._userDefines = [];
    return new Project();
  }

  static function contains(values:Array<String>, value:String):Bool
  {
    return values.indexOf(value) != -1;
  }

  static function renderManifest(project:HXProject):Xml
  {
    var context:Dynamic = {
      APP_BUILD_NUMBER: "1",
      APP_VERSION: project.meta.version,
      APP_PACKAGE: project.meta.packageName,
      ANDROID_INSTALL_LOCATION: "auto",
      ANDROID_PERMISSIONS: project.config.getArrayString("android.permission"),
      ANDROID_APPLICATION: project.config.getKeyValueArray("android.application", {
        "android:requestLegacyExternalStorage": "true",
        "android:preserveLegacyExternalStorage": "true"
      }),
      ANDROID_ACTIVITY: [{key: "android:name", value: "MainActivity"}],
      ANDROID_ACCEPT_FILE_INTENT: [],
      ANDROID_USE_ANDROIDX: true,
      SHARE_FILES: true,
      WIN_ORIENTATION: "landscape"
    };
    var source = File.getContent("source/templates/android/template/app/src/main/AndroidManifest.xml");
    return Xml.parse(new haxe.Template(source).execute(context)).firstElement();
  }

  static function hasRemoval(manifest:Xml, tag:String, permission:String):Bool
  {
    for (element in manifest.elementsNamed(tag))
      if (element.get("android:name") == permission && element.get("tools:node") == "remove") return true;
    return false;
  }

  static function main():Void
  {
    var project = makeProject(Platform.ANDROID);
    var permissions = project.config.getArrayString("android.permission");
    check(permissions.length == REQUIRED_PERMISSIONS.length, "Android permission allowlist has unexpected entries");
    for (permission in REQUIRED_PERMISSIONS)
      check(contains(permissions, permission), 'missing required permission: $permission');
    for (permission in BROAD_PERMISSIONS)
      check(!contains(permissions, permission), 'broad permission must not be requested: $permission');

    // Lime evaluates project.hxp in a subprocess and serializes the result.
    var copy:HXProject = cast haxe.Unserializer.run(haxe.Serializer.run(project));
    check(copy.config.getArrayString("android.permission").join(",") == permissions.join(","),
      "permission allowlist survives Lime serialization");
    check(copy.config.getString("android.application.android:requestLegacyExternalStorage") == "false",
      "requestLegacyExternalStorage must stay disabled");
    check(copy.config.getString("android.application.android:preserveLegacyExternalStorage") == "false",
      "preserveLegacyExternalStorage must stay disabled on upgrades");

    var manifest = renderManifest(copy);
    for (permission in BROAD_PERMISSIONS)
    {
      check(hasRemoval(manifest, "uses-permission", permission), 'missing uses-permission removal: $permission');
      check(hasRemoval(manifest, "uses-permission-sdk-23", permission), 'missing uses-permission-sdk-23 removal: $permission');
    }

    for (tag in ["uses-permission", "uses-permission-sdk-23"])
      for (element in manifest.elementsNamed(tag))
      {
        var name = element.get("android:name");
        if (contains(BROAD_PERMISSIONS, name))
          check(element.get("tools:node") == "remove", 'broad permission is declared instead of removed: $name');
      }

    for (permission in REQUIRED_PERMISSIONS)
    {
      var declarations = 0;
      for (element in manifest.elementsNamed("uses-permission"))
        if (element.get("android:name") == permission && element.get("tools:node") != "remove") declarations++;
      check(declarations == 1, 'required permission must be declared exactly once: $permission');
      check(!hasRemoval(manifest, "uses-permission", permission), 'required permission must not be removed: $permission');
    }

    var application:Xml = manifest.elementsNamed("application").next();
    check(application != null, "rendered manifest is missing <application>");
    check(application.get("android:requestLegacyExternalStorage") == "false", "rendered application enables legacy external storage");
    check(application.get("android:preserveLegacyExternalStorage") == "false", "rendered application preserves legacy external storage");
    check(application.get("android:banner") == "@drawable/tv_banner", "rendered application is missing Android TV banner");
    check(application.get("android:isGame") == "true", "rendered application is missing android:isGame=true");
    check(application.get("android:enableOnBackInvokedCallback") == "false", "rendered application must keep custom Back routing");

    var hasLeanbackFeature = false;
    for (element in manifest.elementsNamed("uses-feature"))
      if (element.get("android:name") == "android.software.leanback" && element.get("android:required") == "false")
        hasLeanbackFeature = true;
    check(hasLeanbackFeature, "rendered manifest must declare optional android.software.leanback feature");

    var activity:Xml = application.elementsNamed("activity").next();
    check(activity != null, "rendered manifest is missing <activity>");
    var hasLeanbackLauncher = false;
    for (filter in activity.elementsNamed("intent-filter"))
      for (category in filter.elementsNamed("category"))
        if (category.get("android:name") == "android.intent.category.LEANBACK_LAUNCHER")
          hasLeanbackLauncher = true;
    check(hasLeanbackLauncher, "rendered manifest is missing LEANBACK_LAUNCHER category");
    check(sys.FileSystem.exists("source/templates/android/template/app/src/main/res/drawable-xhdpi/tv_banner.png"),
      "Android TV banner drawable resource must exist");

    for (target in [Platform.WINDOWS, Platform.IOS, Platform.HTML5])
    {
      var other = makeProject(target);
      check(other.config.getArrayString("android.permission").length == 0, 'non-Android target has Android permissions: $target');
    }

    Sys.println("Android permission policy: OK");
  }
}
