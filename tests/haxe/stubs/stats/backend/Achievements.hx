package backend;

import flixel.FlxG;

typedef Achievement =
{
  var name:String;
  var description:String;
  @:optional var hidden:Bool;
  @:optional var maxScore:Float;
  @:optional var maxDecimals:Int;
  @:optional var mod:String;
  @:optional var ID:Int;
}

class Achievements
{
  public static var achievements:Map<String, Achievement> = new Map();
  public static var achievementsUnlocked:Array<String> = [];
  public static var variables:Map<String, Float> = new Map();
  public static var unlocked:Map<String, Bool> = new Map();
  public static var addScoreCalls:Int = 0;

  public static function reset():Void
  {
    achievements = new Map();
    achievementsUnlocked = [];
    variables = new Map();
    unlocked = new Map();
    addScoreCalls = 0;
  }

  public static function registerPlaytimeBadge(score:Float = 0, isUnlockedNow:Bool = false):Void
  {
    achievements.set('lol', {
      name: 'Play 50 hours',
      description: 'Touch grass',
      hidden: false,
      maxScore: 50,
      maxDecimals: 2,
      ID: 0
    });
    variables.set('lol', score);
    if (isUnlockedNow) unlocked.set('lol', true);
  }

  public static function exists(name:String):Bool
    return achievements.exists(name);

  public static function isUnlocked(name:String):Bool
    return unlocked.exists(name) && unlocked.get(name) == true;

  public static function getScore(name:String):Float
    return variables.exists(name) ? variables.get(name) : 0;

  public static function addScore(name:String, value:Float = 1, saveIfNotUnlocked:Bool = true):Float
  {
    addScoreCalls++;
    if (!exists(name)) return -1;
    final next:Float = getScore(name) + value;
    final maxScore:Float = achievements.get(name).maxScore;
    final clamped:Float = (maxScore > 0 && next >= maxScore) ? maxScore : next;
    variables.set(name, clamped);
    if (maxScore > 0 && clamped >= maxScore && !isUnlocked(name))
    {
      unlocked.set(name, true);
      if (FlxG.save != null) FlxG.save.flush();
    }
    else if (saveIfNotUnlocked && FlxG.save != null)
    {
      FlxG.save.flush();
    }
    return clamped;
  }

  public static function forget(name:String):Void
    unlocked.remove(name);

  public static function setScore(name:String, value:Float, saveIfNotUnlocked:Bool = true):Float
  {
    variables.set(name, value);
    return value;
  }

  public static function save():Void {}
  public static function load():Void {}
}
