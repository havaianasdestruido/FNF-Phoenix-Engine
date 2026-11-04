package objects;

typedef EventNote = {
  strumTime:Float,
  event:String,
  value1:String,
  value2:String
}

@:structInit class PreloadedChartNote
{
  public var strumTime:Float = 0;
  public var noteData:Int = 0;
  public var mustPress:Bool = false;
  public var oppNote:Bool = false;
  public var noteType:String = '';
  public var animSuffix:String = '';
  public var noteskin:Null<String> = null;
  public var texture:Null<String> = null;
  public var noAnimation:Bool = false;
  public var noMissAnimation:Bool = false;
  public var gfNote:Bool = false;
  public var isSustainNote:Bool = false;
  public var isSustainEnd:Bool = false;
  public var sustainLength:Float = 0;
  public var parentST:Float = 0;
  public var parentSL:Float = 0;
  public var hitHealth:Float = 0;
  public var missHealth:Float = 0;
  public var hitCausesMiss:Bool = false;
  public var wasHit:Bool = false;
  public var multSpeed:Float = 1;
  public var multAlpha:Float = 1;
  public var noteDensity:Float = 1;
  public var ignoreNote:Bool = false;
  public var blockHit:Bool = false;
  public var lowPriority:Bool = false;
}

class Note {}
