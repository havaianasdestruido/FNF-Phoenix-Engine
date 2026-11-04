package data;

import data.Section.SwagSection;

typedef SwagSong = {
  var song:String;
  var notes:Array<SwagSection>;
  var events:Array<Dynamic>;
  var bpm:Float;
  var needsVoices:Bool;
  var speed:Float;
  var specialAudioName:String;
  var specialEventsName:String;
  var windowName:String;
}

class Song
{
  public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong return null;
}
