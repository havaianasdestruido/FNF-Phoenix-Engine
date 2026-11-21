package play.helpers;

import backend.ClientPrefs;
import backend.CoolUtil;
import backend.Paths;

import data.StageData.StageFile;
import data.StageEditorCore;

import flixel.FlxSprite;
import flixel.util.FlxColor;

import objects.StagePropSprite;

import play.BaseStage;
import play.PlayState;

/**
 * Spawns the Psych-compatible `objects` array from a stage JSON into
 * PlayState, interleaved with the girlfriend/dad/boyfriend groups so z-order
 * matches the Stage Editor.
 *
 * Vanilla stages keep an empty `objects` list, so this is a no-op besides
 * adding the three character groups in the historical order. Custom JSON
 * stages (and anything saved from the editor) get real props, registered
 * under their `name` for Lua/Python/HScript.
 */
class PlayStateStageObjects
{
  /**
   * Insert character groups (and any JSON props) into `state`.
   *
   * Always adds `gfGroup` / `dadGroup` / `boyfriendGroup` so blammed-lights
   * and scripts that index those groups keep working, even when
   * `hide_girlfriend` left GF empty.
   *
   * @param state Gameplay state whose groups already exist.
   * @param stageData Parsed stage file. `null` or a missing `objects` array
   *        falls back to the original add-gf-then-dad-then-bf order.
   */
  public static function spawn(state:PlayState, stageData:StageFile):Void
  {
    if (state == null) return;

    var objects:Array<Dynamic> = stageData != null ? stageData.objects : null;
    if (objects == null || objects.length < 1)
    {
      addDefaultGroups(state);
      return;
    }

    var addedGf:Bool = false;
    var addedDad:Bool = false;
    var addedBf:Bool = false;
    var props:Array<StagePropSprite> = [];
    var storyMode:Bool = PlayState.isStoryMode;
    var lowQuality:Bool = ClientPrefs.lowQuality;

    for (i in 0...objects.length)
    {
      var data:Dynamic = objects[i];
      if (data == null) continue;
      var type:String = StageEditorCore.canonicalType(data.type);

      switch (type)
      {
        case 'gf':
          state.add(state.gfGroup);
          addedGf = true;
        case 'dad':
          state.add(state.dadGroup);
          addedDad = true;
        case 'boyfriend':
          state.add(state.boyfriendGroup);
          addedBf = true;
        default:
          if (!StageEditorCore.isPropType(type)) continue;
          if (data.visible == false) continue;
          if (!StageEditorCore.validateVisibility(data.filters, lowQuality, storyMode))
            continue;
          var spr:StagePropSprite = buildSprite(data);
          if (spr == null) continue;
          spr.ID = i;
          state.add(spr);
          props.push(spr);
          register(state, spr);
      }
    }

    if (!addedGf) state.add(state.gfGroup);
    if (!addedDad) state.add(state.dadGroup);
    if (!addedBf) state.add(state.boyfriendGroup);

    if (props.length > 0)
      new JsonStage(props);
  }

  static function addDefaultGroups(state:PlayState):Void
  {
    state.add(state.gfGroup);
    state.add(state.dadGroup);
    state.add(state.boyfriendGroup);
  }

  static function register(state:PlayState, spr:StagePropSprite):Void
  {
    if (spr.objectName == null || spr.objectName.length < 1) return;
    state.variables.set(spr.objectName, spr);
    #if (LUA_ALLOWED || PYTHON_ALLOWED)
    state.modchartSprites.set(spr.objectName, spr);
    #end
  }

  /**
   * Build one runtime sprite from a stage-JSON object. Missing images become
   * an invisible 2x2 stand-in so a stripped/CI build cannot crash the song.
   */
  public static function buildSprite(data:Dynamic):StagePropSprite
  {
    if (data == null) return null;
    data = StageEditorCore.normalizeObject(data);

    var spr:StagePropSprite = new StagePropSprite(data.x, data.y);
    spr.objectName = data.name != null ? Std.string(data.name) : '';
    spr.objectType = StageEditorCore.canonicalType(data.type);
    spr.danceEvery = data.danceEvery != null ? data.danceEvery : 0;
    spr.filters = data.filters != null ? data.filters : StageEditorCore.FILTER_BOTH_QUALITY;
    spr.firstAnimation = data.firstAnimation != null ? Std.string(data.firstAnimation) : '';

    switch (spr.objectType)
    {
      case 'square':
        spr.makeGraphic(1, 1, FlxColor.WHITE);
        spr.antialiasing = false;
      case 'animatedSprite':
        loadAtlas(spr, data.image);
        addAnimations(spr, data);
      default:
        loadImage(spr, data.image);
    }

    if (spr.objectType != 'square')
    {
      if (data.antialiasing != null) spr.antialiasing = data.antialiasing;
      if (!ClientPrefs.globalAntialiasing) spr.antialiasing = false;
      spr.flipX = data.flipX == true;
      spr.flipY = data.flipY == true;
    }

    var scale = StageEditorCore.pair(data.scale);
    if (spr.objectType == 'square')
    {
      spr.scale.set(scale[0], scale[1]);
      spr.updateHitbox();
    }
    else if (scale[0] != 1 || scale[1] != 1)
    {
      spr.scale.set(scale[0], scale[1]);
      spr.updateHitbox();
    }

    var scroll = StageEditorCore.pair(data.scroll);
    spr.scrollFactor.set(scroll[0], scroll[1]);
    spr.color = CoolUtil.colorFromString(StageEditorCore.colorToHex(StageEditorCore.parseColor(data.color)));
    if (data.alpha != null) spr.alpha = data.alpha;
    if (data.angle != null) spr.angle = data.angle;
    spr.wasAdded = true;
    return spr;
  }

  static function loadImage(spr:FlxSprite, image:String):Void
  {
    if (image == null || image.length < 1)
    {
      spr.makeGraphic(2, 2, 0, true);
      spr.active = false;
      return;
    }
    var loaded = Paths.image(image);
    if (loaded == null)
    {
      spr.makeGraphic(2, 2, 0, true);
      spr.active = false;
      return;
    }
    spr.loadGraphic(loaded);
    spr.active = false;
  }

  static function loadAtlas(spr:FlxSprite, image:String):Void
  {
    if (image == null || image.length < 1)
    {
      spr.makeGraphic(2, 2, 0, true);
      return;
    }
    var frames = Paths.getAtlas(image);
    if (frames == null)
    {
      spr.makeGraphic(2, 2, 0, true);
      return;
    }
    spr.frames = frames;
  }

  static function addAnimations(spr:StagePropSprite, data:Dynamic):Void
  {
    var anims:Array<Dynamic> = data.animations;
    if (anims == null) return;
    for (anim in anims)
    {
      if (anim == null || anim.anim == null) continue;
      var fps:Int = anim.fps != null ? anim.fps : 24;
      var loop:Bool = anim.loop == true;
      var prefix:String = anim.name != null ? Std.string(anim.name) : Std.string(anim.anim);
      var indices:Array<Int> = anim.indices;
      if (indices != null && indices.length > 0)
        spr.animation.addByIndices(anim.anim, prefix, indices, '', fps, loop);
      else
        spr.animation.addByPrefix(anim.anim, prefix, fps, loop);

      if (anim.offsets != null && anim.offsets.length > 1)
        spr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);

      if (spr.animation.curAnim == null || spr.firstAnimation == anim.anim)
        spr.playAnim(anim.anim, true);
    }
    if ((spr.firstAnimation == null || spr.firstAnimation.length < 1) && anims.length > 0)
      spr.firstAnimation = anims[0].anim;
  }
}

/**
 * Tiny stage hook so JSON props bop on the beat without a Lua script.
 * Constructed only when at least one prop actually spawned.
 */
private class JsonStage extends BaseStage
{
  var props:Array<StagePropSprite>;

  public function new(props:Array<StagePropSprite>)
  {
    this.props = props;
    super();
  }

  override function beatHit()
  {
    if (props == null) return;
    for (spr in props)
    {
      if (spr == null || !spr.exists) continue;
      if (StageEditorCore.shouldDance(spr.danceEvery, curBeat))
        spr.dance(true);
    }
  }
}
