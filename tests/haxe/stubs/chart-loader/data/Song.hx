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
  var ?extraVocals:Dynamic;
}

class Song
{
  public static var fixture:SwagSong;
  public static var lastLoaded:String;
  public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
  {
    lastLoaded = '$folder/$jsonInput';
    return fixture;
  }
}
