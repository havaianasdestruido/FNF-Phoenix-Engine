package backend;

/** Minimal stand-in: the difficulty table and the file-suffix resolution. */
class CoolUtil
{
  public static var defaultDifficulties:Array<String> = ['Easy', 'Normal', 'Hard'];
  public static var defaultDifficulty:String = 'Normal';
  public static var difficulties:Array<String> = ['Easy', 'Normal', 'Hard'];

  /** Empty for the default difficulty, `-<name>` otherwise, mirroring production. */
  public static function getDifficultyFilePath(?num:Null<Int>):String
  {
    var i = num != null ? num : 1;
    var suffix = difficulties[i].toLowerCase();
    return suffix == defaultDifficulty.toLowerCase() ? '' : '-' + suffix;
  }
}
