package backend;

import flixel.util.FlxSave;
import flixel.FlxG;

class ScoresSave {
    public static var instance:ScoresSave = null;

    public var songScores:Map<String, Int> = new Map();
    public var weekScores:Map<String, Int> = new Map();
    public var songRating:Map<String, Float> = new Map();

    private var save:FlxSave = null;

    public function new() {
        save = new FlxSave();
        save.bind('scores', CoolUtil.getSavePath());
        load();
    }

    public static function init() {
        if (instance == null) {
            instance = new ScoresSave();
        }
    }

    public function load():Void {
        if (save.data.weekScores != null) {
            weekScores = save.data.weekScores;
        }
        if (save.data.songScores != null) {
            songScores = save.data.songScores;
        }
        if (save.data.songRating != null) {
            songRating = save.data.songRating;
        }
    }

    public function save():Void {
        save.data.weekScores = weekScores;
        save.data.songScores = songScores;
        save.data.songRating = songRating;
        save.flush();
    }

    public static function reset():Void {
        if (instance != null) {
            instance.songScores = new Map();
            instance.weekScores = new Map();
            instance.songRating = new Map();
            instance.save();
        }
    }
}
