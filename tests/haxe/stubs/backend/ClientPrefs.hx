package backend;

class ClientPrefs
{
  public static var safeFrames:Int = 10;
  public static var noMarvJudge:Bool = false;
  // Alphabet rendering toggle, mirrors the defaults in source/backend/ClientPrefs.hx
  // (which take them from objects.AlphabetFont).
  public static var alphabetStyle:String = 'Font';
  public static var alphabetFont:String = 'VCR OSD Mono';
}
