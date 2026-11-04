package backend;

import flixel.util.FlxSave;
import flixel.FlxG;

class AchievementsSave {
    public static var instance:AchievementsSave = null;

    public var achievementsUnlocked:Array<String> = [];
    public var variables:Map<String, Float> = [];

    private var save:FlxSave = null;

    public function new() {
        save = new FlxSave();
        save.bind('achievements', CoolUtil.getSavePath());
        load();
    }

    public static function init() {
        if (instance == null) {
            instance = new AchievementsSave();
        }
    }

    public function load():Void {
        if (save.data.achievementsUnlocked != null) {
            achievementsUnlocked = save.data.achievementsUnlocked;
        }
        var savedMap:Map<String, Float> = cast save.data.achievementsVariables;
        if (savedMap != null) {
            for (key => value in savedMap) {
                variables.set(key, value);
            }
        }
    }

    public function save():Void {
        save.data.achievementsUnlocked = achievementsUnlocked;
        save.data.achievementsVariables = variables;
        save.flush();
    }

    public static function reset():Void {
        if (instance != null) {
            instance.achievementsUnlocked = [];
            instance.variables = [];
            instance.save();
        }
    }
}
