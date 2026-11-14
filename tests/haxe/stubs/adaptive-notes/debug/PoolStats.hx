package debug;
class PoolStats
{
  public static inline final NOTE:String = 'note';
  public static inline final SUSTAIN:String = 'sustain';
  public static inline final HOLD_SPLASH:String = 'hold';
  public static inline final NOTE_SPLASH:String = 'splash';
  public static inline final CROSS_FADE:String = 'crossfade';
  public static var spawns:Int = 0;
  public static function spawn(kind:String, reused:Bool):Void spawns++;
  public static function release(kind:String):Void {}
}
