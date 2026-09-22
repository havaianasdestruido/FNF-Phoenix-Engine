package backend;

import play.PlayState;
import tjson.TJSON as Json;

import states.LoadingState;

typedef WeekFile =
{
  // JSON variables
  var songs:Array<Dynamic>;
  var weekCharacters:Array<String>;
  var weekBackground:String;
  var weekBefore:String;
  var storyName:String;
  var weekName:String;
  var freeplayColor:Array<Int>;
  var startUnlocked:Bool;
  var ?hiddenUntilUnlocked:Null<Bool>;
  var hideStoryMode:Bool;
  var hideFreeplay:Bool;
  var ?difficulties:String;
}

class WeekData
{
  public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
  public static var weeksList:Array<String> = [];

  public var folder:String = '';

  // JSON variables
  public var songs:Array<Dynamic>;
  public var weekCharacters:Array<String>;
  public var weekBackground:String;
  public var weekBefore:String;
  public var storyName:String;
  public var weekName:String;
  public var freeplayColor:Array<Int>;
  public var startUnlocked:Bool;
  public var hiddenUntilUnlocked:Null<Bool>;
  public var hideStoryMode:Bool;
  public var hideFreeplay:Bool;
  public var difficulties:String;

  public var fileName:String;

  /**
   * Executes the `createWeekFile` operation.
   * @return Result produced by `createWeekFile`, when applicable.
   */
  public static function createWeekFile():WeekFile
  {
    var weekFile:WeekFile =
      {
        songs: [
          ["Bopeebo", "dad", [146, 113, 253]],
          ["Fresh", "dad", [146, 113, 253]],
          ["Dad Battle", "dad", [146, 113, 253]]
        ],
        weekCharacters: ['dad', 'bf', 'gf'],
        weekBackground: 'stage',
        weekBefore: 'tutorial',
        storyName: 'Your New Week',
        weekName: 'Custom Week',
        freeplayColor: [146, 113, 253],
        startUnlocked: true,
        hiddenUntilUnlocked: false,
        hideStoryMode: false,
        hideFreeplay: false,
        difficulties: ''
      };
    return weekFile;
  }

  /**
   * Executes the `new` operation.
   * @param weekFile Input value for `weekFile`.
   * @param fileName Input value for `fileName`.
   */
  public function new(weekFile:WeekFile, fileName:String)
  {
    var template = createWeekFile();
    for (i in Reflect.fields(weekFile))
    {
      if (Reflect.hasField(template, i))
      { // just doing Reflect.hasField on itself doesnt work for some reason so we are doing it on a template
        Reflect.setProperty(this, i, Reflect.field(weekFile, i));
      }
    }

    if (hiddenUntilUnlocked == null)
    {
      hiddenUntilUnlocked = false;
    }

    this.fileName = fileName;
  }

  /**
   * Executes the `reloadWeekFiles` operation.
   * @param isStoryMode Input value for `isStoryMode`.
   * @return Result produced by `reloadWeekFiles`, when applicable.
   */
  public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
  {
    weeksList = [];
    weeksLoaded.clear();
    #if MODS_ALLOWED
    var directories:Array<String> = [Paths.mods(), Paths.getPreloadPath()];
    var originalLength:Int = directories.length;

    for (mod in Mods.parseList().enabled)
      directories.push(Paths.mods(mod + '/'));
    #else
    var directories:Array<String> = [Paths.getPreloadPath()];
    var originalLength:Int = directories.length;
    #end

    var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getPreloadPath('weeks/weekList.txt'));
    for (i in 0...sexList.length)
    {
      for (j in 0...directories.length)
      {
        var fileToCheck:String = directories[j] + 'weeks/' + sexList[i] + '.json';
        if (!weeksLoaded.exists(sexList[i]))
        {
          var week:WeekFile = getWeekFile(fileToCheck);
          if (week != null)
          {
            var weekFile:WeekData = new WeekData(week, sexList[i]);

            #if MODS_ALLOWED
            if (j >= originalLength)
            {
              weekFile.folder = directories[j].substring(Paths.mods().length, directories[j].length - 1);
            }
            #end

            if (weekFile != null
              && (isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay)))
            {
              weeksLoaded.set(sexList[i], weekFile);
              weeksList.push(sexList[i]);
            }
          }
        }
      }
    }

    #if MODS_ALLOWED
    for (i in 0...directories.length)
    {
      var directory:String = directories[i] + 'weeks/';
      if (FileSystem.exists(directory))
      {
        var listOfWeeks:Array<String> = CoolUtil.coolTextFile(directory + 'weekList.txt');
        for (daWeek in listOfWeeks)
        {
          var path:String = directory + daWeek + '.json';
          if (sys.FileSystem.exists(path))
          {
            addWeek(daWeek, path, directories[i], i, originalLength);
          }
        }

        for (file in FileSystem.readDirectory(directory))
        {
          var path = haxe.io.Path.join([directory, file]);
          if (!sys.FileSystem.isDirectory(path) && file.endsWith('.json'))
          {
            addWeek(file.substr(0, file.length - 5), path, directories[i], i, originalLength);
          }
        }
      }
    }
    #end
  }

  /**
   * Executes the `isValidWeekJson` operation.
   * @param data Input value for `data`.
   * @return Result produced by `isValidWeekJson`, when applicable.
   */
  private static function isValidWeekJson(data:Dynamic):Bool
  {
    if (data == null) return false;

    final requiredFields = ["songs", "weekCharacters", "weekName"];

    for (field in requiredFields)
    {
      if (!Reflect.hasField(data, field)) return false;
    }

    final songs = Reflect.field(data, "songs");
    final chars = Reflect.field(data, "weekCharacters");
    if (songs == null || chars == null || songs.length <= 0 || chars.length <= 0) return false;

    return true;
  }

  /**
   * Executes the `addWeek` operation.
   * @param weekToCheck Input value for `weekToCheck`.
   * @param path Input value for `path`.
   * @param directory Input value for `directory`.
   * @param i Input value for `i`.
   * @param originalLength Input value for `originalLength`.
   * @return Result produced by `addWeek`, when applicable.
   */
  private static function addWeek(weekToCheck:String, path:String, directory:String, i:Int, originalLength:Int)
  {
    if (!weeksLoaded.exists(weekToCheck))
    {
      var week:WeekFile = getWeekFile(path);
      if (week != null)
      {
        var weekFile:WeekData = new WeekData(week, weekToCheck);
        if (i >= originalLength)
        {
          #if MODS_ALLOWED
          weekFile.folder = directory.substring(Paths.mods().length, directory.length - 1);
          #end
        }
        if ((PlayState.isStoryMode && !weekFile.hideStoryMode) || (!PlayState.isStoryMode && !weekFile.hideFreeplay))
        {
          weeksLoaded.set(weekToCheck, weekFile);
          weeksList.push(weekToCheck);
        }
      }
    }
  }

  /**
   * Executes the `getWeekFile` operation.
   * @param path Input value for `path`.
   * @return Result produced by `getWeekFile`, when applicable.
   */
  private static function getWeekFile(path:String):WeekFile
  {
    var rawJson:String = null;
    #if MODS_ALLOWED
    if (FileSystem.exists(path))
    {
      rawJson = File.getContent(path);
    }
    #else
    if (OpenFlAssets.exists(path))
    {
      rawJson = Assets.getText(path);
    }
    #end

    if (rawJson != null && rawJson.length > 0)
    {
      var parsed:Dynamic = Json.parse(rawJson);
      if (isValidWeekJson(parsed)) return cast parsed;
      else
        return null; // Skip invalid week jsons
    }
    return null;
  }

  //   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE
  // To use on PlayState.hx or Highscore stuff
  /**
   * Executes the `getWeekFileName` operation.
   * @return Result produced by `getWeekFileName`, when applicable.
   */
  public static function getWeekFileName():String
  {
    return weeksList[PlayState.storyWeek];
  }

  // Used on LoadingState, nothing really too relevant
  /**
   * Executes the `getCurrentWeek` operation.
   * @return Result produced by `getCurrentWeek`, when applicable.
   */
  public static function getCurrentWeek():WeekData
  {
    return weeksLoaded.get(weeksList[PlayState.storyWeek]);
  }

  /**
   * Executes the `setDirectoryFromWeek` operation.
   * @param data Input value for `data`.
   * @return Result produced by `setDirectoryFromWeek`, when applicable.
   */
  public static function setDirectoryFromWeek(?data:WeekData = null)
  {
    Mods.currentModDirectory = '';
    if (data != null && data.folder != null && data.folder.length > 0)
    {
      Mods.currentModDirectory = data.folder;
    }
  }
}
