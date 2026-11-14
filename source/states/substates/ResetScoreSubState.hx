package states.substates;

import backend.CoolUtil;
import backend.ViewportVisuals;
import backend.Highscore;
import backend.MusicBeatSubstate;
import backend.Paths;
import backend.PlayerSettings;
import backend.WeekData;
import flixel.FlxG;
import objects.Alphabet;
import objects.HealthIcon;
import objects.HoldToConfirm;
import objects.TouchTarget;

import backend.Controls;
import data.Song;
import objects.Character;

class ResetScoreSubState extends MusicBeatSubstate
{
  var bg:FlxSprite;
  var alphabetArray:Array<Alphabet> = [];
  var icon:HealthIcon;
  var onYes:Bool = false;
  var yesText:Alphabet;
  var noText:Alphabet;

  var song:String;
  var difficulty:Int;
  var week:Int;

  /** Yes deletes saved scores: guarded by a held press / second confirmation. */
  var yesConfirm:HoldToConfirm;
  /** Enlarged, invisible hit area for the harmless No option. */
  var noTarget:TouchTarget;

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    ViewportVisuals.fill(bg);
    for (text in alphabetArray) text.screenCenter(X);
    if (week == -1 && alphabetArray.length > 1)
    {
      final scale:Float = alphabetArray[1].text.length > 18 ? 0.8 : 1;
      alphabetArray[1].x += 60 * scale;
      if (icon != null) icon.x = alphabetArray[1].x - icon.width + 10 * scale;
    }
    if (yesText != null) { yesText.screenCenter(X); yesText.x -= 200; }
    if (noText != null) { noText.screenCenter(X); noText.x += 200; }
  }

  // Week -1 = Freeplay
  public function new(song:String, difficulty:Int, character:String, week:Int = -1)
  {
    this.song = song;
    this.difficulty = difficulty;
    this.week = week;

    super();

    var name:String = song;
    if (week > -1)
    {
      name = WeekData.weeksLoaded.get(WeekData.weeksList[week]).weekName;
    }
    name += ' (' + CoolUtil.difficulties[difficulty] + ')?';

    bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    ViewportVisuals.fill(bg);
    bg.alpha = 0;
    bg.scrollFactor.set();
    add(bg);

    var tooLong:Float = (name.length > 18) ? 0.8 : 1; // Winter Horrorland has a long name.
    var text:Alphabet = new Alphabet(0, 180, "Reset the score of", true);
    text.screenCenter(X);
    alphabetArray.push(text);
    text.alpha = 0;
    add(text);
    var text:Alphabet = new Alphabet(0, text.y + 90, name, true);
    text.scaleX = tooLong;
    text.screenCenter(X);
    if (week == -1) text.x += 60 * tooLong;
    alphabetArray.push(text);
    text.alpha = 0;
    add(text);
    if (week == -1)
    {
      icon = new HealthIcon(character);
      icon.setGraphicSize(Std.int(icon.width * tooLong));
      icon.updateHitbox();
      icon.setPosition(text.x - icon.width + (10 * tooLong), text.y - 30);
      icon.alpha = 0;
      add(icon);
    }

    yesText = new Alphabet(0, text.y + 150, 'Yes', true);
    yesText.screenCenter(X);
    yesText.x -= 200;
    add(yesText);
    noText = new Alphabet(0, text.y + 150, 'No', true);
    noText.screenCenter(X);
    noText.x += 200;
    add(noText);
    updateOptions();

    addVirtualPad(LEFT_RIGHT, A_B);

    // "Yes" wipes the saved score/accuracy, so it is no longer one quick tap
    // of the virtual A button. The Yes/No art is untouched; only invisible,
    // padded hit areas are added on top.
    // `ACCEPT_P` is the held (PRESSED) twin of `ACCEPT`, which only reports the
    // first frame of a press and therefore cannot drive a hold.
    yesConfirm = new HoldToConfirm(yesText, confirmReset,
      () -> onYes && PlayerSettings.player1.controls.ACCEPT_P, 'HOLD TO RESET SCORE');
    add(yesConfirm);
    noTarget = new TouchTarget(noText, function() {
      FlxG.sound.play(Paths.sound('cancelMenu'), 1);
      close();
    });
    add(noTarget);
  }

  override function update(elapsed:Float)
  {
    bg.alpha += elapsed * 1.5;
    if (bg.alpha > 0.6) bg.alpha = 0.6;

    for (i in 0...alphabetArray.length)
    {
      var spr = alphabetArray[i];
      spr.alpha += elapsed * 2.5;
    }
    if (week == -1) icon.alpha += elapsed * 2.5;

    if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
    {
      FlxG.sound.play(Paths.sound('scrollMenu'), 1);
      onYes = !onYes;
      if (yesConfirm != null) yesConfirm.cancel();
      updateOptions();
    }
    if (controls.BACK)
    {
      if (yesConfirm != null) yesConfirm.cancel();
      FlxG.sound.play(Paths.sound('cancelMenu'), 1);
      close();
    }
    // ACCEPT on Yes is consumed by yesConfirm (held press or second press).
    // ACCEPT on No is harmless and stays a single press.
    else if (controls.ACCEPT && !onYes)
    {
      FlxG.sound.play(Paths.sound('cancelMenu'), 1);
      close();
    }
    super.update(elapsed);
  }

  /** Runs once after the guarded Yes gesture completes. */
  function confirmReset():Void
  {
    if (week == -1)
      Highscore.resetSong(song, difficulty);
    else
      Highscore.resetWeek(WeekData.weeksList[week], difficulty);
    FlxG.sound.play(Paths.sound('cancelMenu'), 1);
    close();
  }

  function updateOptions()
  {
    var scales:Array<Float> = [0.75, 1];
    var alphas:Array<Float> = [0.6, 1.25];
    var confirmInt:Int = onYes ? 1 : 0;

    yesText.alpha = alphas[confirmInt];
    yesText.scale.set(scales[confirmInt], scales[confirmInt]);
    noText.alpha = alphas[1 - confirmInt];
    noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
    if (week == -1) icon.animation.curAnim.curFrame = confirmInt;
  }
}
