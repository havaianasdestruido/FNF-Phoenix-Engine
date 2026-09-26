package objects;

import backend.Paths;
import backend.Conductor;
import backend.ClientPrefs;
import play.PlayState;

import data.Song;

//A helper class for popups.
//This was added to fix issues with rating popups not disappearing correctly when Combo Stacking is turned on.

class Popup extends FlxSprite {
    public var popTime:Float = 0; //The song position that the popup was spawned at.
    final placement = FlxG.width * 0.35; //Offset for the popups.
    var playbackRate(get, null):Float = 1.0;
    var showRating(get, null):Bool = true;

    /**
     * Executes the `new` operation.
*/
    public function new() {
        super();
        try {
            playbackRate = PlayState.instance.playbackRate;
        }
        catch(e) { playbackRate = 1.0;}
    }

    /**
     * Executes the `get_playbackRate` operation.
     * @return Result produced by `get_playbackRate`, when applicable.
     */
    public function get_playbackRate():Float
    {
        try {
            playbackRate = PlayState.instance.playbackRate;
        }
        catch(e) { playbackRate = 1.0;}
        return playbackRate;
    }

    /**
     * Executes the `get_showRating` operation.
     * @return Result produced by `get_showRating`, when applicable.
     */
    public function get_showRating():Bool
    {
        try {
            showRating = PlayState.instance.showRating;
        }
        catch(e) { showRating = true;}
        return showRating;
    }

    /**
     * Executes the `setupRating` operation.
     * @param img Input value for `img`.
     * @return Result produced by `setupRating`, when applicable.
     */
    public function setupRating(img:String)
    {
        popTime = Conductor.songPosition;
        loadGraphic(Paths.image(img));
        screenCenter();
        x = placement - 40;
        y -= 60;
        acceleration.y = 550 * playbackRate * playbackRate;
        velocity.y -= FlxG.random.int(140, 175) * playbackRate;
        velocity.x -= FlxG.random.int(0, 10) * playbackRate;
        visible = (!ClientPrefs.hideHud && showRating);
        x += ClientPrefs.comboOffset[0];
        y -= ClientPrefs.comboOffset[1];
        antialiasing = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;
        setGraphicSize(Std.int(width * (PlayState.isPixelStage ? PlayState.daPixelZoom * 0.85 : 0.7)));
        updateHitbox();
    }

    /**
     * Executes the `setupNumber` operation.
     * @param img Input value for `img`.
     * @param daLoop Input value for `daLoop`.
     * @param combo Input value for `combo`.
     * @return Result produced by `setupNumber`, when applicable.
     */
    public function setupNumber(img:String, daLoop:Int, combo:Float)
    {
        popTime = Conductor.songPosition;
        loadGraphic(Paths.image(img));
        screenCenter();
        x = placement + (43 * daLoop) - 90;
        y += 80;
        acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
        velocity.y -= FlxG.random.int(140, 160) * playbackRate;
        velocity.x = FlxG.random.float(-5, 5) * playbackRate;
        visible = !ClientPrefs.hideHud;
        x += ClientPrefs.comboOffset[2];
		y -= ClientPrefs.comboOffset[3];
        antialiasing = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;
        setGraphicSize(Std.int(width * (PlayState.isPixelStage ? PlayState.daPixelZoom : 0.5)));
        updateHitbox();
    }

    /**
     * Executes the `alphaTween` operation.
     * @param isNumber Input value for `isNumber`.
     * @return Result produced by `alphaTween`, when applicable.
     */
    public function alphaTween(?isNumber:Bool = false)
    {
        FlxTween.tween(this, {alpha: 0}, 0.2 / playbackRate, {
            startDelay: (!isNumber ? 0.7 : 1.4) / playbackRate,
            onComplete: function(tween:FlxTween)
            {
                kill();
            }
        });
    }

    /**
     * Executes the `revive` operation.
     * @return Result produced by `revive`, when applicable.
     */
    override public function revive() {
        super.revive();
        initVars();
        acceleration.x = acceleration.y = velocity.x = velocity.y = x = y = 0;
        alpha = 1;
        visible = true;
    }
}
