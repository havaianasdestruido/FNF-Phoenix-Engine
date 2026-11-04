package backend;

import flixel.util.FlxSave;
import flixel.FlxG;

class ClientPrefsSave {
    public static var instance:ClientPrefsSave = null;

    // Prefs data fields (mapped from ClientPrefs)
    public var showRamGraph:Bool = false;
    public var flashing:Bool = false;
    // ... other fields can be added if needed, but we bind the whole data object

    private var save:FlxSave = null;

    public function new() {
        save = new FlxSave();
        save.bind('prefs', CoolUtil.getSavePath());
        load();
    }

    public static function init() {
        if (instance == null) {
            instance = new ClientPrefsSave();
        }
    }

    public function load():Void {
        if (save.data.showRamGraph != null) {
            showRamGraph = save.data.showRamGraph;
        }
        if (save.data.flashing != null) {
            flashing = save.data.flashing;
        }
        // Note: ClientPrefs.loadPrefs() also iterates through fields and loads them into ClientPrefs class
        // We keep the data here for direct access if needed, or ClientPrefs can bind to this instance.
    }

    public function save():Void {
        save.data.showRamGraph = showRamGraph;
        save.data.flashing = flashing;
        save.flush();
    }

    public static function reset():Void {
        if (instance != null) {
            instance.showRamGraph = false;
            instance.flashing = false;
            instance.save();
        }
    }
}
