package mobile;

import flixel.util.FlxSave;
import flixel.FlxG;

class MobileControlsSave {
    public static var instance:MobileControlsSave = null;

    public var mobileCMode:String = 'Hitbox';
    public var buttons:Array<FlxPoint> = null;
    public var buttonsWidth:Int = 0;

    private var save:FlxSave = null;

    public function new() {
        save = new FlxSave();
        save.bind('mobile_controls', CoolUtil.getSavePath());
        load();
    }

    public static function init() {
        if (instance == null) {
            instance = new MobileControlsSave();
        }
    }

    public function load():Void {
        if (save.data.mobileCMode != null) {
            mobileCMode = save.data.mobileCMode;
        }
        if (save.data.buttons != null) {
            buttons = save.data.buttons;
        }
        if (save.data.buttonsWidth != null) {
            buttonsWidth = save.data.buttonsWidth;
        }
    }

    public function save():Void {
        save.data.mobileCMode = mobileCMode;
        save.data.buttons = buttons;
        save.data.buttonsWidth = buttonsWidth;
        save.flush();
    }

    public static function reset():Void {
        if (instance != null) {
            instance.mobileCMode = 'Hitbox';
            instance.buttons = null;
            instance.buttonsWidth = 0;
            instance.save();
        }
    }
}
