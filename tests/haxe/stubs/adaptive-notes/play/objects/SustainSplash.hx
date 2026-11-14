package play.objects;
import objects.Note;
import objects.StrumNote;
class SustainSplash
{
  public static var setups:Int = 0;
  public function new() {}
  public function setupSusSplash(strum:StrumNote, note:Note, rate:Float):Void setups++;
}
