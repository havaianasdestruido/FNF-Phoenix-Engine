package backend;

class ClientPrefs
{
  public static var safeFrames:Int = 10;
  public static var noMarvJudge:Bool = false;
  // Alphabet rendering toggle, mirrors the defaults in source/backend/ClientPrefs.hx
  // (which take them from objects.AlphabetFont).
  public static var alphabetStyle:String = 'Font';
  public static var alphabetFont:String = 'VCR OSD Mono';
  public static var alphabetAntialiasing:Bool = true;
  // Quant/RGB colour style settings read by CoolUtil.checkNoteQuant and the RGB
  // palette helpers. Defaults match the engine ('Quant-Based' is opt-in).
  public static var noteColorStyle:String = 'RGB';
  public static var showNotes:Bool = true;
  public static var enableColorShader:Bool = true;
}
