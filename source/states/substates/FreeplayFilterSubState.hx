package states.substates;

import backend.Controls;
import backend.FreeplayFilter;
import backend.MusicBeatSubstate;
import backend.Paths;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import objects.Alphabet;
import objects.AttachedText;

/** One line of the filter page: a label, a value, and what left/right/accept do. */
private typedef FreeplayFilterRow = {
  var name:String;
  var value:Void->String;
  var change:Int->Void;
  var confirm:Void->Void;
}

/**
 * What the filter page asks the Freeplay screen to do while the page is open.
 *
 * The page only edits the shared `FreeplayFilterState`; these four callbacks are
 * everything that needs the live song list (the highlight, its star, and the
 * random pick).
 */
typedef FreeplayFilterHost = {
  /** Star of the highlighted song right now. */
  var isStarred:Void->Bool;

  /** Flips that star and returns the new value. */
  var toggleStar:Void->Bool;

  /** Highlights a random song out of the current filter. */
  var randomSong:Void->Void;

  /** "Bopeebo (Base Game)" style label, `''` when the list is empty. */
  var currentSong:Void->String;
}

/**
 * The Freeplay filter page: order, mod, favourites and random pick in one list,
 * opened with F (or the FILTER button, or the right shoulder button) from
 * `states.FreeplayState`.
 *
 * Everything it changes lives in the `FreeplayFilterState` it is handed, so
 * there is nothing to confirm: the list is rebuilt (and the choice saved) when
 * the page closes, which `FreeplayState.closeSubState` does. Stars toggle at
 * once because they are what the "Favourites only" switch filters on.
 */
class FreeplayFilterSubState extends MusicBeatSubstate
{
  static inline var ROW_Y:Float = 360;
  static inline var ROW_X:Float = 170;
  static inline var VALUE_OFFSET:Float = 430;
  static inline var ROW_SCALE:Float = 0.8;

  var filter:FreeplayFilterState;
  var mods:Array<String>;
  var host:FreeplayFilterHost;

  var background:FlxSprite;
  var title:Alphabet;
  var grpRows:FlxTypedGroup<Alphabet>;
  var grpValues:FlxTypedGroup<AttachedText>;
  var rows:Array<FreeplayFilterRow> = [];
  var curSelected:Int = 0;

  var nowPlayingText:FlxText;
  var hintText:FlxText;

  var layoutWidth:Int = 0;

  public function new(filter:FreeplayFilterState, mods:Array<String>, host:FreeplayFilterHost)
  {
    super();

    this.filter = filter == null ? new FreeplayFilterState() : filter;
    this.mods = mods == null ? [] : mods;
    this.host = host;

    layoutWidth = FlxG.width;

    background = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    ViewportVisuals.fill(background);
    background.alpha = 0.7;
    add(background);

    title = new Alphabet(0, 100, 'Free Play Filter', true);
    title.screenCenter(X);
    add(title);

    grpRows = new FlxTypedGroup<Alphabet>();
    add(grpRows);
    grpValues = new FlxTypedGroup<AttachedText>();
    add(grpValues);

    buildRows();

    nowPlayingText = new FlxText(0, FlxG.height - 70, FlxG.width, '', 18);
    nowPlayingText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    nowPlayingText.scrollFactor.set();
    add(nowPlayingText);

    hintText = new FlxText(0, FlxG.height - 44, FlxG.width,
      'UP/DOWN select  -  LEFT/RIGHT change  -  ACCEPT confirm  -  BACK close', 16);
    hintText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    hintText.scrollFactor.set();
    add(hintText);

    changeSelection(0, false);
    refreshValues();

    addVirtualPad(LEFT_FULL, A_B);
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    ViewportVisuals.fill(background);
    final shift:Float = ScreenLayout.contentLeft(width) - ScreenLayout.contentLeft(layoutWidth);
    if (title != null) title.screenCenter(X);
    if (grpRows != null)
    {
      grpRows.forEach(row -> {
        row.startPosition.x += shift;
        row.x += shift;
      });
    }
    if (grpValues != null) grpValues.forEach(value -> value.x += shift);
    if (nowPlayingText != null)
    {
      nowPlayingText.fieldWidth = width;
      nowPlayingText.y = height - 70;
    }
    if (hintText != null)
    {
      hintText.fieldWidth = width;
      hintText.y = height - 44;
    }
    layoutWidth = width;
  }

  /** Builds the six rows once; their labels stay, their values are read live. */
  function buildRows():Void
  {
    rows = [
      {
        name: 'Sort by',
        value: function() return FreeplaySort.label(filter.sort),
        change: function(step:Int) filter.cycleSort(step),
        confirm: function() filter.cycleSort(1)
      },
      {
        name: 'Show mod',
        value: function() return filter.mod == null ? 'All Mods' : FreeplayFilter.modLabel(filter.mod),
        change: function(step:Int) filter.cycleMod(mods, step),
        confirm: function() filter.cycleMod(mods, 1)
      },
      {
        name: 'Favourites only',
        value: function() return filter.favouritesOnly ? 'On' : 'Off',
        change: function(step:Int) filter.toggleFavouritesOnly(),
        confirm: function() filter.toggleFavouritesOnly()
      },
      {
        name: 'Star this song',
        value: function() return starValue(),
        change: function(step:Int) toggleStar(),
        confirm: function() toggleStar()
      },
      {
        name: 'Random song',
        value: function() return 'Press ACCEPT',
        change: function(step:Int) {},
        confirm: function() {
          if (host != null && host.randomSong != null) host.randomSong();
          close();
        }
      },
      {
        name: 'Reset filters',
        value: function() return filter.query.length > 0 ? 'Search: ' + filter.query : 'Press ACCEPT',
        change: function(step:Int) {},
        confirm: function() {
          filter.resetAll();
          FlxG.sound.play(Paths.sound('cancelMenu'));
        }
      }
    ];

    for (i in 0...rows.length)
    {
      final row:Alphabet = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + ROW_X, ROW_Y, rows[i].name, true);
      row.isMenuItem = true;
      row.setScale(ROW_SCALE);
      row.targetY = i;
      grpRows.add(row);

      final value:AttachedText = new AttachedText('', VALUE_OFFSET, 0, true, ROW_SCALE);
      value.sprTracker = row;
      value.copyAlpha = true;
      value.ID = i;
      grpValues.add(value);
    }
  }

  /** "Starred" / "Not starred", or a nudge when the filter hid every song. */
  function starValue():String
  {
    if (host == null || host.currentSong == null || host.currentSong().length == 0) return 'No song selected';
    return host.isStarred() ? 'Starred' : 'Not starred';
  }

  function toggleStar():Void
  {
    if (host == null || host.toggleStar == null) return;
    if (host.currentSong().length == 0) return;
    host.toggleStar();
    FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
  }

  /** Rewrites only the values whose text changed; `Alphabet.text` rebuilds letters. */
  function refreshValues():Void
  {
    for (i in 0...rows.length)
    {
      if (i >= grpValues.members.length) break;
      final label:Alphabet = grpValues.members[i];
      final text:String = rows[i].value();
      if (label.text != text) label.text = text;
    }

    if (nowPlayingText != null)
    {
      final song:String = (host != null && host.currentSong != null) ? host.currentSong() : '';
      final text:String = song.length == 0 ? 'No songs match this filter' : 'Highlighted: ' + song;
      if (nowPlayingText.text != text) nowPlayingText.text = text;
    }
  }

  function changeSelection(change:Int = 0, playSound:Bool = true):Void
  {
    if (rows.length == 0) return;

    curSelected += change;
    if (curSelected < 0) curSelected = rows.length - 1;
    if (curSelected >= rows.length) curSelected = 0;

    for (i in 0...grpRows.members.length)
    {
      final row:Alphabet = grpRows.members[i];
      row.targetY = i - curSelected;
      row.alpha = (i == curSelected) ? 1 : 0.6;
    }

    if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
  }

  override function update(elapsed:Float):Void
  {
    if (controls.UI_UP_P) changeSelection(-1);
    if (controls.UI_DOWN_P) changeSelection(1);

    if (rows.length > 0)
    {
      final row:FreeplayFilterRow = rows[curSelected];
      if (controls.UI_LEFT_P) row.change(-1)
      else if (controls.UI_RIGHT_P) row.change(1);

      if (controls.ACCEPT) row.confirm();
    }

    if (controls.BACK) close();

    refreshValues();
    super.update(elapsed);
  }
}
