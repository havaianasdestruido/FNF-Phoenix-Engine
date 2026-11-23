package data;

typedef SwagSection = {
  var sectionBeats:Float;
  var bpm:Float;
  var changeBPM:Bool;
  // Used by CoolUtil.getNoteAmount; optional so ConductorSpec's sections still build.
  @:optional var sectionNotes:Array<Array<Dynamic>>;
  @:optional var mustHitSection:Bool;
}

class Section
{
}
