package play.helpers;

import backend.Accessibility;
import backend.ClientPrefs;
import backend.Conductor;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import objects.StrumNote;
import play.PlayState;
import play.helpers.StageDimMath;

/**
 * Runtime gameplay overlays for the §16 accessibility preferences:
 *  - `laneGlyphs`: ASCII direction badges (`<`, `v`, `^`, `>`) locked to each receptor.
 *  - `visualBeatIndicator`: non-flashing screen-edge pulse on countdown ticks and beats.
 *  - `highContrast`: dark readability strip behind HUD score text, thicker HUD borders,
 *    and a minimum stage-contrast floor when `stageDim` is below 45%.
 *
 * Kept separate from `PlayStateStageDim` so `stageDimOverlay` remains the sole
 * owner of the top `camGame` slot tested by `StageDimSpec`.
 */
@:access(play.PlayState)
class PlayStateAccessibility
{
  static var _owner:PlayState = null;
  static var _glyphTexts:Array<FlxText> = [];
  static var _beatEdges:Array<FlxSprite> = [];
  static var _hcHudStrip:FlxSprite = null;
  static var _hcStageBackdrop:FlxSprite = null;

  static var _beatAlpha:Float = 0.0;
  static var _beatPeakAlpha:Float = 0.0;
  static var _beatColor:Int = Accessibility.BEAT_COLOR_NORMAL;
  static var _lastBeat:Int = -999999;
  static var _seeking:Bool = false;
  static var _appliedHighContrastBorders:Null<Bool> = null;

  /** Initializes accessibility overlays for `state` before `PlayStateStageDim.setup`. */
  public static function setup(state:PlayState):Void
  {
    clear(null);
    if (state == null) return;

    _owner = state;
    _beatAlpha = 0.0;
    _beatPeakAlpha = 0.0;
    _lastBeat = -999999;
    _seeking = false;
    _appliedHighContrastBorders = null;

    if (ClientPrefs.highContrast)
    {
      ensureHighContrastSprites(state);
      applyHudContrastBorders(state, true);
    }

    if (ClientPrefs.laneGlyphs)
      syncGlyphPool(state);

    if (ClientPrefs.visualBeatIndicator)
      ensureBeatEdges(state);

    sync(state, 0.0);
  }

  /** Updates active accessibility overlays after `PlayState` finishes its frame update. */
  public static function sync(state:PlayState, elapsed:Float):Void
  {
    if (state == null || state != _owner) return;

    syncHighContrast(state);
    syncLaneGlyphs(state);
    syncBeatIndicator(state, elapsed);
  }

  /** Pulses the visual beat indicator on countdown ticks (`0..3`, with `3` = "GO!"). */
  public static function countdownTick(state:PlayState, tick:Int):Void
  {
    if (state == null || state != _owner || tick < 0 || tick > 3) return;
    if (!Accessibility.allowsBeatPulse(
      ClientPrefs.visualBeatIndicator,
      true,
      state.paused,
      state.endingSong,
      state.isDead,
      state.transitioning,
      state.inCutscene,
      state.ffmpegMode,
      _seeking
    )) return;

    triggerPulse(state, tick == 3);
  }

  /** Pulses the visual beat indicator once per beat during gameplay. */
  public static function beatHit(state:PlayState):Void
  {
    if (state == null || state != _owner) return;

    final beat:Int = @:privateAccess state.curBeat;
    if (beat < 0 || beat == _lastBeat) return;
    if (!Accessibility.allowsBeatPulse(
      ClientPrefs.visualBeatIndicator,
      state.startedCountdown,
      state.paused,
      state.endingSong,
      state.isDead,
      state.transitioning,
      state.inCutscene,
      state.ffmpegMode,
      _seeking
    )) return;

    _lastBeat = beat;
    triggerPulse(state, beat % 4 == 0);
  }

  /** Clears transient beat-pulse state across song seeks/restarts. */
  public static function seek(state:PlayState):Void
  {
    if (state == null || state != _owner) return;
    _seeking = true;
    _beatAlpha = 0.0;
    _lastBeat = @:privateAccess state.curBeat;
    hideBeatEdges();
    _seeking = false;
  }

  /** Releases static references when `PlayState` is destroyed. */
  public static function clear(state:Null<PlayState>):Void
  {
    if (state != null && _owner != null && state != _owner) return;
    _owner = null;
    _glyphTexts = [];
    _beatEdges = [];
    _hcHudStrip = null;
    _hcStageBackdrop = null;
    _beatAlpha = 0.0;
    _beatPeakAlpha = 0.0;
    _lastBeat = -999999;
    _seeking = false;
    _appliedHighContrastBorders = null;
  }

  static function triggerPulse(state:PlayState, isDownbeat:Bool):Void
  {
    ensureBeatEdges(state);
    _beatPeakAlpha = Accessibility.beatPeakAlpha(isDownbeat, ClientPrefs.reducedMotion);
    _beatAlpha = _beatPeakAlpha;
    _beatColor = isDownbeat ? Accessibility.BEAT_COLOR_DOWNBEAT : Accessibility.BEAT_COLOR_NORMAL;
  }

  static function syncHighContrast(state:PlayState):Void
  {
    final hc:Bool = ClientPrefs.highContrast;
    if (_appliedHighContrastBorders != hc)
      applyHudContrastBorders(state, hc);

    if (!hc)
    {
      if (_hcHudStrip != null) _hcHudStrip.visible = false;
      if (_hcStageBackdrop != null) _hcStageBackdrop.visible = false;
      return;
    }

    ensureHighContrastSprites(state);

    if (_hcHudStrip != null)
    {
      final showScore:Bool = !ClientPrefs.hideHud && state.scoreTxt != null && state.scoreTxt.visible;
      _hcHudStrip.visible = showScore;
      if (showScore)
      {
        if (Std.int(_hcHudStrip.width) != FlxG.width)
        {
          _hcHudStrip.setGraphicSize(FlxG.width, 36);
          _hcHudStrip.updateHitbox();
        }
        _hcHudStrip.setPosition(0, state.scoreTxt.y - 6);
        _hcHudStrip.alpha = Accessibility.HUD_STRIP_ALPHA_HIGH_CONTRAST;
      }
    }

    if (_hcStageBackdrop != null && state.camGame != null)
    {
      final userDim:Float = StageDimMath.alpha(ClientPrefs.stageDim);
      final targetDim:Float = Accessibility.effectiveStageDim(userDim, true);
      final extraAlpha:Float = targetDim - userDim;
      if (extraAlpha <= 0.005)
      {
        _hcStageBackdrop.visible = false;
      }
      else
      {
        final cam:FlxCamera = state.camGame;
        final size = StageDimMath.coverageSize(cam.width, cam.height, cam.zoom, cam.angle);
        final pos = StageDimMath.coveragePosition(cam.width, cam.height, size);
        if (Std.int(_hcStageBackdrop.width) != size.width || Std.int(_hcStageBackdrop.height) != size.height)
        {
          _hcStageBackdrop.setGraphicSize(size.width, size.height);
          _hcStageBackdrop.updateHitbox();
        }
        _hcStageBackdrop.setPosition(pos.x, pos.y);
        // Combine multiplicatively with `PlayStateStageDim` so `(1 - extra) * (1 - userDim) == 1 - targetDim`.
        final denom:Float = 1.0 - userDim;
        _hcStageBackdrop.alpha = denom > 0.01 ? (extraAlpha / denom) : extraAlpha;
        _hcStageBackdrop.visible = true;
      }
    }
  }

  static function ensureHighContrastSprites(state:PlayState):Void
  {
    if (_hcStageBackdrop == null && state.camGame != null)
    {
      final backdrop:FlxSprite = new FlxSprite();
      backdrop.makeGraphic(1, 1, FlxColor.BLACK);
      backdrop.scrollFactor.set();
      backdrop.active = false;
      backdrop.visible = false;
      backdrop.cameras = [state.camGame];
      insertBeforeStageDim(state, backdrop);
      _hcStageBackdrop = backdrop;
    }

    if (_hcHudStrip == null && state.camHUD != null)
    {
      final strip:FlxSprite = new FlxSprite();
      strip.makeGraphic(1, 1, FlxColor.BLACK);
      strip.setGraphicSize(FlxG.width, 36);
      strip.updateHitbox();
      strip.scrollFactor.set();
      strip.active = false;
      strip.visible = false;
      strip.cameras = [state.camHUD];

      final scoreIdx:Int = state.scoreTxt != null ? state.members.indexOf(state.scoreTxt) : -1;
      if (scoreIdx >= 0)
        state.insert(scoreIdx, strip);
      else
        insertBeforeStageDim(state, strip);
      _hcHudStrip = strip;
    }
  }

  static function applyHudContrastBorders(state:PlayState, highContrast:Bool):Void
  {
    _appliedHighContrastBorders = highContrast;
    final border:Float = highContrast ? Accessibility.HUD_BORDER_HIGH_CONTRAST : Accessibility.HUD_BORDER_NORMAL;
    if (state.scoreTxt != null) state.scoreTxt.borderSize = border;
    if (state.timeTxt != null) state.timeTxt.borderSize = highContrast ? Accessibility.HUD_BORDER_HIGH_CONTRAST : 2.0;
    if (state.botplayTxt != null) state.botplayTxt.borderSize = border;
  }

  static function syncLaneGlyphs(state:PlayState):Void
  {
    if (!ClientPrefs.laneGlyphs)
    {
      for (glyph in _glyphTexts)
        if (glyph != null) glyph.visible = false;
      return;
    }

    if (state.strumLineNotes == null || state.strumLineNotes.members == null)
      return;

    syncGlyphPool(state);

    final strums:Array<StrumNote> = state.strumLineNotes.members;
    final count:Int = _glyphTexts.length < strums.length ? _glyphTexts.length : strums.length;
    for (i in 0...count)
    {
      final strum:StrumNote = strums[i];
      final glyph:FlxText = _glyphTexts[i];
      if (glyph == null) continue;
      if (strum == null || !strum.exists || !strum.visible || strum.alpha <= 0.02)
      {
        glyph.visible = false;
        continue;
      }

      final expected:String = Accessibility.laneGlyph(strum.noteData);
      if (glyph.text != expected) glyph.text = expected;
      if (strum.cameras != null && strum.cameras.length > 0 && glyph.cameras != strum.cameras)
        glyph.cameras = strum.cameras;

      glyph.setPosition(
        strum.x + (strum.width - glyph.width) * 0.5,
        strum.y + (strum.height - glyph.height) * 0.5
      );
      glyph.alpha = strum.alpha * 0.95;
      glyph.visible = true;
    }
    for (j in count..._glyphTexts.length)
      if (_glyphTexts[j] != null) _glyphTexts[j].visible = false;
  }

  static function syncGlyphPool(state:PlayState):Void
  {
    if (state.strumLineNotes == null || state.strumLineNotes.members == null)
      return;

    final noteCam:FlxCamera = state.camNotes != null ? state.camNotes : state.camHUD;
    final needed:Int = state.strumLineNotes.members.length;
    while (_glyphTexts.length < needed)
    {
      final idx:Int = _glyphTexts.length;
      final strum:StrumNote = state.strumLineNotes.members[idx];
      final label:FlxText = new FlxText(0, 0, 0, Accessibility.laneGlyph(strum != null ? strum.noteData : idx), 28);
      label.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      label.borderSize = 2.5;
      label.scrollFactor.set();
      label.active = false;
      label.visible = false;
      if (noteCam != null) label.cameras = [noteCam];
      insertBeforeStageDim(state, label);
      _glyphTexts.push(label);
    }
  }

  static function syncBeatIndicator(state:PlayState, elapsed:Float):Void
  {
    if (!ClientPrefs.visualBeatIndicator || _beatAlpha <= 0.0)
    {
      _beatAlpha = 0.0;
      hideBeatEdges();
      return;
    }

    if (!state.paused)
    {
      _beatAlpha = Accessibility.decayBeatAlpha(
        _beatAlpha,
        elapsed,
        Conductor.crochet,
        state.playbackRate
      );
    }

    if (_beatAlpha <= 0.0)
    {
      hideBeatEdges();
      return;
    }

    ensureBeatEdges(state);
    final w:Int = FlxG.width;
    final h:Int = FlxG.height;
    final thick:Int = Accessibility.beatEdgeThickness(_beatAlpha, _beatPeakAlpha, ClientPrefs.reducedMotion);

    layoutEdge(_beatEdges[0], 0, 0, w, thick);
    layoutEdge(_beatEdges[1], 0, h - thick, w, thick);
    layoutEdge(_beatEdges[2], 0, thick, thick, h - thick * 2);
    layoutEdge(_beatEdges[3], w - thick, thick, thick, h - thick * 2);

    for (edge in _beatEdges)
    {
      if (edge == null) continue;
      edge.color = _beatColor;
      edge.alpha = _beatAlpha;
      edge.visible = true;
    }
  }

  static function ensureBeatEdges(state:PlayState):Void
  {
    if (_beatEdges.length == 4 || state.camHUD == null) return;
    _beatEdges = [];
    for (_ in 0...4)
    {
      final edge:FlxSprite = new FlxSprite();
      edge.makeGraphic(1, 1, FlxColor.WHITE);
      edge.scrollFactor.set();
      edge.active = false;
      edge.visible = false;
      edge.cameras = [state.camHUD];
      insertBeforeStageDim(state, edge);
      _beatEdges.push(edge);
    }
  }

  static function layoutEdge(edge:FlxSprite, x:Float, y:Float, width:Int, height:Int):Void
  {
    if (edge == null) return;
    final safeW:Int = width > 1 ? width : 1;
    final safeH:Int = height > 1 ? height : 1;
    if (Std.int(edge.width) != safeW || Std.int(edge.height) != safeH)
    {
      edge.setGraphicSize(safeW, safeH);
      edge.updateHitbox();
    }
    edge.setPosition(x, y);
  }

  static function hideBeatEdges():Void
  {
    for (edge in _beatEdges)
      if (edge != null) edge.visible = false;
  }

  static function insertBeforeStageDim(state:PlayState, member:flixel.FlxBasic):Void
  {
    if (state.stageDimOverlay != null)
    {
      final dimIdx:Int = state.members.indexOf(state.stageDimOverlay);
      if (dimIdx >= 0)
      {
        state.insert(dimIdx, member);
        return;
      }
    }
    state.add(member);
  }
}
