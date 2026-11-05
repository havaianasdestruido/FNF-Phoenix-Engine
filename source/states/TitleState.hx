package states;

import backend.ClientPrefs;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.Conductor;
import backend.CoolUtil;
import backend.Highscore;
import backend.MusicBeatState;
import backend.Paths;
import backend.UpdateChecker;
// import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;
import Main;
import objects.Alphabet;
import objects.ColorSwap;
import openfl.Assets;
import openfl.display.BitmapData;

import backend.Controls;
import data.Song;
import play.PlayState;

typedef TitleData =
{
  titlex:Float,
  titley:Float,
  startx:Float,
  starty:Float,
  gfx:Float,
  gfy:Float,
  backgroundSprite:String,
  bpm:Int,
  endY:Float,
}

class TitleState extends MusicBeatState
{
  public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
  public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
  public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

  public static var initialized:Bool = false;

  public var inCutscene:Bool = false;

  var canPause:Bool = true;

  var blackScreen:FlxSprite;
  var background:FlxSprite;
  var hasBackgroundArt:Bool = false;
  var layoutWidth:Int = 0;
  var credGroup:FlxGroup;
  var creditText:Alphabet;
  var textGroup:FlxGroup;
  var ngSpr:FlxSprite;

  var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
  var titleTextAlphas:Array<Float> = [1, .64];

  var curWacky:Array<String> = [];

  var mustUpdate:Bool = false;

  public static var titleJSON:TitleData;

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    if (hasBackgroundArt) ViewportVisuals.cover(background);
    else ViewportVisuals.fill(background);
    ViewportVisuals.fill(blackScreen);
    final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(layoutWidth);
    for (sprite in [logoBl, gfDance, titleText]) if (sprite != null) sprite.x += shift;
    if (ngSpr != null) ngSpr.screenCenter(X);
    if (creditText != null) creditText.screenCenter(X);
    if (textGroup != null)
      for (item in textGroup.members)
        if (Std.isOfType(item, Alphabet)) (cast item : Alphabet).screenCenter(X);
    layoutWidth = FlxG.width;
  }

  override public function create():Void
  {
    layoutWidth = FlxG.width;
    Paths.clearStoredMemory();
    Paths.clearUnusedMemory();

    MusicBeatState.windowNameSuffix = " - Title Screen";

    MusicBeatState.windowNamePrefix = backend.RuntimeFlags.windowTitle(Assets.getText(Paths.txt("windowTitleBase", "preload")));

    curWacky = FlxG.random.getObject(getIntroText());

    // DEBUG NONSENSE

    swagShader = new ColorSwap();
    super.create();

    #if CHECK_FOR_UPDATES
    if (ClientPrefs.checkForUpdates && !closedState && !Main.askedToUpdate)
    {
      UpdateChecker.check(function(result) {
        switch (result)
        {
          case Available(release):
            if (FlxG.state == this)
              mustUpdate = true;
            else if (Std.isOfType(FlxG.state, MainMenuState) && !Main.askedToUpdate)
            {
              // The player may reach the menu before a slow request finishes.
              Main.askedToUpdate = true;
              FlxG.switchState(() -> new OutdatedState(release));
            }
          default: {}
        }
      });
    }
    #end

    Highscore.load();

    // IGNORE THIS!!!
    var rawTitleJson:String = Paths.getTextFromFile('images/gfDanceTitle.json');
    if (rawTitleJson != null)
      titleJSON = Json.parse(rawTitleJson);
    else
      // No title config shipped (e.g. content-stripped builds drop the GF
      // dancer + its JSON): fall back to the stock layout values.
      titleJSON = {titlex: -150, titley: 1500, startx: 100, starty: 576, gfx: 512, gfy: 40, backgroundSprite: '', bpm: 102, endY: -100};

    if (!initialized)
    {
      persistentUpdate = true;
      persistentDraw = true;
    }

    if (FlxG.save.data.weekCompleted != null)
    {
      StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
    }

    FlxG.mouse.visible = false;

    if (FlxG.save.data.flashing == null && !FlashingState.leftState)
    {
      FlxTransitionableState.skipNextTransIn = true;
      FlxTransitionableState.skipNextTransOut = true;
      FlxG.switchState(FlashingState.new);
    }
    else
    {
      if (initialized) startIntro();
      else
      {
        new FlxTimer().start(1, function(tmr:FlxTimer) {
          startIntro();
        });
      }
    }

    addVirtualPad(NONE, A);
    // startIntro() adds a fullscreen bg after create() on first launch, keep the pad above it.
    addVirtualPadCamera();

    #if android
    // If Android killed the process mid-song (low memory etc.), offer to
    // resume the interrupted song. No-op when there's nothing to recover.
    checkRecoveryState();
    #end
  }

  #if android
  function checkRecoveryState():Void
  {
    var blob:String = android.platform.AndroidSystem.consumeRecoveryState();
    if (blob == null || blob == "")
      return;

    var data:Dynamic = null;
    try
    {
      data = Json.parse(blob);
    }
    catch (e:Dynamic)
    {
      return;
    }

    if (data == null || data.type != "song" || data.song == null)
      return;

    var songLowercase:String = Paths.formatToSongPath(Std.string(data.song));

    // Restore the mod directory so mod-scoped charts resolve.
    if (data.mod != null && Std.string(data.mod).length > 0)
      Mods.currentModDirectory = Std.string(data.mod);

    // Difficulty list preference: the persisted one (may include custom
    // mod difficulties), then whatever the menus set up, then the engine
    // defaults. It must be in CoolUtil.difficulties before formatSong,
    // because Highscore.formatSong/getDifficultyFilePath index into it.
    var diffNames:Array<String> = null;
    if (data.difficulties != null && Std.isOfType(data.difficulties, Array) && (data.difficulties : Array<Dynamic>).length > 0)
      diffNames = [for (d in (data.difficulties : Array<Dynamic>)) Std.string(d)];
    else if (CoolUtil.difficulties.length > 0)
      diffNames = CoolUtil.difficulties;
    else
      diffNames = CoolUtil.defaultDifficulties.copy();

    CoolUtil.difficulties = diffNames;

    function findDifficulty(name:String):Int
    {
      for (i in 0...diffNames.length)
      {
        if (diffNames[i].toLowerCase() == name.toLowerCase())
          return i;
      }
      return -1;
    }

    var diffIndex:Int = findDifficulty(CoolUtil.defaultDifficulty);
    if (diffIndex < 0)
      diffIndex = 0;

    if (data.difficulty != null)
    {
      var wanted:Int = findDifficulty(Std.string(data.difficulty));
      if (wanted >= 0)
        diffIndex = wanted;
    }

    var poop:String = Highscore.formatSong(songLowercase, diffIndex);

    var exists:Bool = false;
    #if sys
    exists = sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) || sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop))
      || OpenFlAssets.exists(Paths.modsJson(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop));
    #else
    exists = OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop));
    #end

    if (!exists)
      return;

    // Extract resume state — validated and clamped.
    var resumePosition:Null<Float> = null;
    var resumeRate:Null<Float> = null;
    var resumeHealth:Null<Float> = null;
    var resumePractice:Null<Bool> = null;
    var resumeBotplay:Null<Bool> = null;
    try
    {
      if (data.songPosition != null)
      {
        var pos:Float = Std.parseFloat(Std.string(data.songPosition));
        if (Math.isFinite(pos) && pos > 2000 && pos < 10 * 60 * 1000)
          resumePosition = pos;
      }
      if (data.playbackRate != null)
      {
        var rate:Float = Std.parseFloat(Std.string(data.playbackRate));
        if (Math.isFinite(rate) && rate > 0.25 && rate < 4.0)
          resumeRate = rate;
      }
      if (data.health != null)
      {
        var h:Float = Std.parseFloat(Std.string(data.health));
        if (Math.isFinite(h) && h >= 0 && h <= 2.5)
          resumeHealth = h;
      }
      if (data.practiceMode != null) resumePractice = (data.practiceMode == true);
      if (data.botplay != null) resumeBotplay = (data.botplay == true);
    }
    catch (e:Dynamic) {}

    // Engine version check — reject blobs from another build so a renamed
    // field or migrated chart does not half-apply and corrupt the session.
    if (data.engineVersion != null)
    {
      var blobVersion:String = Std.string(data.engineVersion);
      if (blobVersion.length > 0 && blobVersion != backend.PhoenixVersion.current && blobVersion != backend.PhoenixVersion.FALLBACK)
      {
        trace('Recovery: rejecting blob from different engine version ($blobVersion vs ${backend.PhoenixVersion.current})');
        return;
      }
    }

    var detail:String = '${data.song}';
    if (resumePosition != null && resumePosition > 5000)
      detail += ' @ ${formatRecoveryTime(resumePosition)}';

    openSubState(new objects.Prompt('The game was interrupted during "' + detail + '".\n\nResume ' + (resumePosition != null ? "where you left off" : "from the start") + '?', 0, function()
    {
      PlayState.SONG = Song.loadFromJson(poop, songLowercase);
      PlayState.storyDifficulty = diffIndex;
      PlayState.isStoryMode = false;
      PlayState.wasOriginallyFreeplay = true;
      CoolUtil.currentDifficulty = CoolUtil.difficultyString();
      if (resumePosition != null)
        PlayState.startOnTime = resumePosition;
      if (resumeRate != null)
        PlayState.startOnTimeRate = resumeRate;
      if (resumeHealth != null)
        PlayState.startOnTimeHealth = resumeHealth;
      if (resumePractice != null)
        PlayState.startOnTimePractice = resumePractice;
      if (resumeBotplay != null)
        PlayState.startOnTimeBotplay = resumeBotplay;
      LoadingState.loadAndSwitchState(PlayState.new);
    }, null, true));
  }

  static function formatRecoveryTime(ms:Float):String
  {
    var total:Int = Std.int(ms / 1000);
    var m:Int = Std.int(total / 60);
    var s:Int = total % 60;
    return '' + m + ':' + StringTools.lpad("" + s, "0", 2);
  }
  #end

  var logoBl:FlxSprite;
  var gfDance:FlxSprite;
  var danceLeft:Bool = false;
  var titleText:FlxSprite;
  var swagShader:ColorSwap = null;

  var deepLinkReady:Bool = false;

  function startIntro()
  {
    if (!initialized)
    {
      Paths.playMenuMusic(true, 0);
    }

    switch (ClientPrefs.daMenuMusic) // change this if you're making a source mod, like add your own or something
    {
      case 'Mashup' | 'VS Impostor':
        Conductor.changeBPM(102);
      case 'Dave & Bambi':
        Conductor.changeBPM(148);
      case 'Dave & Bambi (Old)':
        Conductor.changeBPM(150);
      case 'DDTO+':
        Conductor.changeBPM(120);
      case 'Anniversary':
        Conductor.changeBPM(115);
      case 'Base Game' | 'Default' | 'None' | 'Christmas': // just in case you're not making a source mod & wanna change this
        Conductor.changeBPM(titleJSON.bpm);
      default: // fallback
        Conductor.changeBPM(titleJSON.bpm);
    }
    persistentUpdate = true;

    background = new FlxSprite();
    hasBackgroundArt = titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != "none";
    if (hasBackgroundArt)
    {
      background.loadGraphic(Paths.image(titleJSON.backgroundSprite));
      ViewportVisuals.cover(background);
    }
    else
    {
      background.makeGraphic(1, 1, FlxColor.BLACK);
      ViewportVisuals.fill(background);
    }
    add(background);

    logoBl = new FlxSprite(ScreenLayout.contentLeft(FlxG.width) + titleJSON.titlex, titleJSON.titley);
    logoBl.frames = Paths.getSparrowAtlas('logoBumpin');

    logoBl.antialiasing = ClientPrefs.globalAntialiasing;
    logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
    logoBl.animation.play('bump');
    logoBl.updateHitbox();

    swagShader = new ColorSwap();
    // The title dancer is optional: content-stripped builds ship no
    // gfDanceTitle art. (beatHit() already null-checks gfDance.)
    // Both the image and the Sparrow atlas must exist: getSparrowAtlas
    // would treat a missing .xml path as literal XML and fail to parse it.
    if (Paths.image('gfDanceTitle') != null && Paths.fileExists('images/gfDanceTitle.xml', TEXT))
    {
      gfDance = new FlxSprite(ScreenLayout.contentLeft(FlxG.width) + titleJSON.gfx, titleJSON.gfy);

      gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
      gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
      gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
      gfDance.antialiasing = ClientPrefs.globalAntialiasing;

      add(gfDance);
      gfDance.shader = swagShader.shader;
    }
    add(logoBl);
    logoBl.shader = swagShader.shader;

    titleText = new FlxSprite(ScreenLayout.contentLeft(FlxG.width) + titleJSON.startx, titleJSON.starty);
	titleText.frames = Paths.getSparrowAtlas('titleEnter');
    var animFrames:Array<FlxFrame> = [];
    @:privateAccess {
      titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
      titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
    }

    if (animFrames.length > 0)
    {
      newTitle = true;

      titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
      titleText.animation.addByPrefix('press', ClientPrefs.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
    }
    else
    {
      newTitle = false;

      titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
      titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
    }

    titleText.antialiasing = ClientPrefs.globalAntialiasing;
    titleText.animation.play('idle');
    titleText.updateHitbox();
    add(titleText);

    credGroup = new FlxGroup();
    add(credGroup);
    textGroup = new FlxGroup();

    blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    ViewportVisuals.fill(blackScreen);
    credGroup.add(blackScreen);

    creditText = new Alphabet(0, 0, "", true);
    creditText.screenCenter();

    creditText.visible = false;

    ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
    add(ngSpr);
    ngSpr.visible = false;
    ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
    ngSpr.updateHitbox();
    ngSpr.screenCenter(X);
    ngSpr.antialiasing = ClientPrefs.globalAntialiasing;

    FlxTween.tween(creditText, {y: creditText.y + 20}, 2.9, {ease: FlxEase.quadInOut, type: PINGPONG});

    if (initialized) skipIntro();
    else
      initialized = true;
    deepLinkReady = true;
  }

  function getIntroText():Array<Array<String>>
  {
    var fullText:String = Assets.getText(Paths.txt('introText'));

    var firstArray:Array<String> = fullText.split('\n');
    var swagGoodArray:Array<Array<String>> = [];

    for (i in firstArray)
    {
      swagGoodArray.push(i.split('--'));
    }

    return swagGoodArray;
  }

  var transitioning:Bool = false;

  var newTitle:Bool = false;
  var titleTimer:Float = 0;

  override function update(elapsed:Float)
  {
    if (deepLinkReady && !transitioning && backend.deeplink.DeepLinks.dispatch()) return;
    if (FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time;

    var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

    var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

    if (gamepad != null)
    {
      if (gamepad.justPressed.START) pressedEnter = true;
    }

    if (newTitle)
    {
      titleTimer += CoolUtil.boundTo(elapsed, 0, 1);
      if (titleTimer > 2) titleTimer -= 2;
    }

    if (initialized && !transitioning && skippedIntro)
    {
      if (newTitle && !pressedEnter)
      {
        var timer:Float = titleTimer;
        if (timer >= 1) timer = (-timer) + 2;

        timer = FlxEase.quadInOut(timer);

        titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
        titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
      }

      if (pressedEnter)
      {
        titleText.color = FlxColor.WHITE;
        titleText.alpha = 1;

        if (titleText != null) titleText.animation.play('press');

        FlxG.camera.flash(ClientPrefs.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
        FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

        transitioning = true;

        new FlxTimer().start(1, function(tmr:FlxTimer) {
          if (mustUpdate && UpdateChecker.latestRelease != null)
          {
            Main.askedToUpdate = true;
            final release = UpdateChecker.latestRelease;
            FlxG.switchState(() -> new OutdatedState(release));
          }
          else
          {
            FlxG.switchState(MainMenuState.new);
          }
          closedState = true;
        });
      }
    }

    if (initialized && pressedEnter && !skippedIntro)
    {
      skipIntro();
    }

    if (swagShader != null)
    {
      if (controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
      if (controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
    }

    super.update(elapsed);
  }

  function createCoolText(textArray:Array<String>, ?offset:Float = 0)
  {
    for (i in 0...textArray.length)
    {
      var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
      money.screenCenter(X);
      money.y += (i * 60) + 200 + offset;
      if (credGroup != null && textGroup != null)
      {
        credGroup.add(money);
        textGroup.add(money);
      }
    }
  }

  function addMoreText(text:String, ?offset:Float = 0)
  {
    if (textGroup != null && credGroup != null)
    {
      var coolText:Alphabet = new Alphabet(0, 0, text, true);
      coolText.screenCenter(X);
      coolText.y += (textGroup.length * 60) + 200 + offset;
      credGroup.add(coolText);
      textGroup.add(coolText);
    }
  }

  function deleteCoolText()
  {
    while (textGroup.members.length > 0)
    {
      credGroup.remove(textGroup.members[0], true);
      textGroup.remove(textGroup.members[0], true);
    }
  }

  private var sickBeats:Int = 0; // Basically curBeat but won't be skipped if you hold the tab or resize the screen

  public static var closedState:Bool = false;

  override function beatHit()
  {
    super.beatHit();

    FlxG.camera.zoom += 0.015;

    FlxTween.tween(FlxG.camera, {zoom: 1}, Conductor.crochet / 1200, {ease: FlxEase.quadOut});

    if (logoBl != null) logoBl.animation.play('bump', true);

    if (gfDance != null)
    {
      danceLeft = !danceLeft;
      if (danceLeft) gfDance.animation.play('danceRight');
      else
        gfDance.animation.play('danceLeft');
    }

    if (!closedState)
    {
      sickBeats++;
      switch (sickBeats)
      {
        case 1:
          FlxG.sound.music.fadeIn(4, 0, 0.7);
        case 2:
          createCoolText(['JS Engine by'], 15);
        case 4:
          addMoreText('Jordan Santiago', 15);
          addMoreText('Moxie', 15);
        case 5:
          deleteCoolText();
        case 6:
          createCoolText(['Not associated', 'with'], -40);
        case 8:
          addMoreText('newgrounds', -40);
          ngSpr.visible = true;
        case 9:
          deleteCoolText();
          ngSpr.visible = false;
        case 10:
          createCoolText([curWacky[0]]);
        case 12:
          addMoreText(curWacky[1]);
        case 13:
          deleteCoolText();
        case 14:
          addMoreText('Friday');
        case 15:
          addMoreText('Night');
        case 16:
          addMoreText('Funkin');

        case 17:
          skipIntro();
      }
    }
  }

  var skippedIntro:Bool = false;
  var increaseVolume:Bool = false;

  function skipIntro():Void
  {
    if (!skippedIntro)
    {
      FlxTween.tween(logoBl, {y: titleJSON.endY}, 1.4, {ease: FlxEase.expoInOut});

      logoBl.angle = -4;

      new FlxTimer().start(0.01, function(tmr:FlxTimer) {
        if (logoBl.angle == -4) FlxTween.angle(logoBl, logoBl.angle, 4, 4, {ease: FlxEase.quartInOut});
        if (logoBl.angle == 4) FlxTween.angle(logoBl, logoBl.angle, -4, 4, {ease: FlxEase.quartInOut});
      }, 0);

      remove(ngSpr);
      remove(credGroup);
      FlxG.camera.flash(FlxColor.WHITE, 4);
      skippedIntro = true;
    }
  }
}
