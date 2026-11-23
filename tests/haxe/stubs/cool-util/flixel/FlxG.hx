package flixel;

/**
 * Minimal FlxG stand-in: scriptable stage metadata for getSavePath, plus a
 * captured openURL so specs can verify CoolUtil.browserLoad.
 */
class FlxG
{
  /** Stage double with application/meta wiring for getSavePath. */
  public static var stage:FlxStage = new FlxStage();

  /** URLs passed to openURL, in call order. */
  public static var openedUrls:Array<String> = [];

  /** Records the URL instead of launching it. */
  public static function openURL(url:String):Void
  {
    openedUrls.push(url);
  }

  /** Restores the default stage and clears the captured URLs. */
  public static function reset():Void
  {
    stage = new FlxStage();
    openedUrls = [];
  }
}

/** Stage double: exposes an application with meta company/file keys. */
class FlxStage
{
  public var application:FlxApplication;

  public function new()
  {
    application = new FlxApplication();
  }
}

/** Application double with scripted meta values. */
class FlxApplication
{
  public var meta:FlxMeta;

  public function new()
  {
    meta = new FlxMeta();
  }
}

/** Meta double: get() answers from the values specs set on `values`. */
class FlxMeta
{
  /** Specapp company/file keys returned by get(); mutate freely in specs. */
  public var values:Map<String, String> = [
    'company' => 'com.example',
    'file' => 'My Game'
  ];

  public function new() {}

  /** Returns the scripted value for `key`, or null when unset. */
  public function get(key:String):String
    return values.get(key);
}
