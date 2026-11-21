package data;

/**
 * Renderer-free stage-editor rules: the Psych-compatible object graph,
 * undo stack, quality/story filters, camera helpers and JSON save shape.
 *
 * Gameplay (`play.helpers.PlayStateStageObjects`) and the visual editor
 * (`editors.StageEditorState`) both consume this so a JSON stage looks the
 * same in the editor as it does in PlayState. The Haxe interpreter spec in
 * `tests/haxe/StageEditorSpec.hx` runs this module without Flixel.
 */
class StageEditorCore
{
  /** Names that cannot be used for a prop because PlayState already owns them. */
  public static var reservedNames:Array<String> = [
    'gf', 'gfGroup', 'dad', 'dadGroup', 'boyfriend', 'boyfriendGroup'
  ];

  /** Character-slot type ids stored in `objects`. */
  public static var characterTypes:Array<String> = ['gf', 'dad', 'boyfriend'];
  /** Drawable prop type ids stored in `objects`. */
  public static var propTypes:Array<String> = ['sprite', 'animatedSprite', 'square'];

  public static inline var FILTER_LOW:Int = 1 << 0;
  public static inline var FILTER_HIGH:Int = 1 << 1;
  public static inline var FILTER_STORY:Int = 1 << 2;
  public static inline var FILTER_FREEPLAY:Int = 1 << 3;
  /** Visible in both quality modes (the editor/Psych default). */
  public static inline var FILTER_BOTH_QUALITY:Int = FILTER_LOW | FILTER_HIGH;

  public static inline var DEFAULT_ZOOM:Float = 0.9;
  public static inline var DEFAULT_CAMERA_SPEED:Float = 1;
  public static inline var MIN_ZOOM:Float = 0.1;
  public static inline var MAX_ZOOM:Float = 3;
  public static inline var UNDO_LIMIT:Int = 64;
  public static inline var NUDGE:Float = 1;
  public static inline var NUDGE_FAST:Float = 10;
  /** Visible rows in the editor sprite list. */
  public static inline var LIST_WINDOW:Int = 14;
  /** World-grid size in pixels when snap-to-grid is on. */
  public static inline var GRID_SIZE:Int = 10;

  /**
   * A stage JSON with the vanilla Week 1 character placements and no props.
   * Character slots are *not* injected here: runtime files stay compact until
   * the editor calls `ensureCharacterSlots`.
   */
  public static function dummyStage():Dynamic
  {
    return {
      directory: '',
      defaultZoom: DEFAULT_ZOOM,
      isPixelStage: false,
      stageUI: 'normal',
      boyfriend: [770, 100],
      girlfriend: [400, 130],
      opponent: [100, 100],
      hide_girlfriend: false,
      camera_boyfriend: [0.0, 0.0],
      camera_opponent: [0.0, 0.0],
      camera_girlfriend: [0.0, 0.0],
      camera_speed: DEFAULT_CAMERA_SPEED,
      shaders: [],
      objects: [],
      preload: {},
      _editorMeta: {gf: 'gf', dad: 'dad', boyfriend: 'bf'}
    };
  }

  /**
   * Fill every field PlayState and the editor read so a partial Psych JSON
   * cannot NPE. Mutates and returns `stage`.
   */
  public static function normalizeStage(stage:Dynamic):Dynamic
  {
    if (stage == null) return dummyStage();

    if (stage.directory == null) stage.directory = '';
    if (stage.defaultZoom == null || Math.isNaN(stage.defaultZoom))
      stage.defaultZoom = DEFAULT_ZOOM;
    if (stage.stageUI == null) stage.stageUI = '';
    if (stage.isPixelStage == null)
      stage.isPixelStage = stage.stageUI == 'pixel' || StringTools.endsWith(Std.string(stage.stageUI), '-pixel');
    if (stage.boyfriend == null) stage.boyfriend = [770, 100];
    if (stage.girlfriend == null) stage.girlfriend = [400, 130];
    if (stage.opponent == null) stage.opponent = [100, 100];
    if (stage.hide_girlfriend == null) stage.hide_girlfriend = false;
    if (stage.camera_boyfriend == null) stage.camera_boyfriend = [0.0, 0.0];
    if (stage.camera_opponent == null) stage.camera_opponent = [0.0, 0.0];
    if (stage.camera_girlfriend == null) stage.camera_girlfriend = [0.0, 0.0];
    if (stage.camera_speed == null || Math.isNaN(stage.camera_speed))
      stage.camera_speed = DEFAULT_CAMERA_SPEED;
    if (stage.shaders == null) stage.shaders = [];
    if (stage.preload == null) stage.preload = {};
    if (stage._editorMeta == null) stage._editorMeta = {gf: 'gf', dad: 'dad', boyfriend: 'bf'};
    else
    {
      if (stage._editorMeta.gf == null) stage._editorMeta.gf = 'gf';
      if (stage._editorMeta.dad == null) stage._editorMeta.dad = 'dad';
      if (stage._editorMeta.boyfriend == null) stage._editorMeta.boyfriend = 'bf';
    }
    if (stage.objects == null) stage.objects = [];
    else
    {
      var objects:Array<Dynamic> = cast stage.objects;
      for (i in 0...objects.length)
        objects[i] = normalizeObject(objects[i]);
    }
    return stage;
  }

  /** Fill one object so every editor/runtime field is safe to read. */
  public static function normalizeObject(obj:Dynamic):Dynamic
  {
    if (obj == null) return defaultObject('sprite', 'sprite1');

    var type:String = obj.type != null ? Std.string(obj.type) : 'sprite';
    obj.type = canonicalType(type);

    if (isCharacterType(obj.type))
    {
      obj.type = canonicalType(obj.type);
      return obj;
    }

    if (obj.name == null || Std.string(obj.name).length < 1)
      obj.name = 'sprite';
    if (obj.x == null || Math.isNaN(obj.x)) obj.x = 0;
    if (obj.y == null || Math.isNaN(obj.y)) obj.y = 0;
    if (obj.scale == null || !Std.isOfType(obj.scale, Array) || obj.scale.length < 2)
      obj.scale = obj.type == 'square' ? [200.0, 200.0] : [1.0, 1.0];
    if (obj.scroll == null || !Std.isOfType(obj.scroll, Array) || obj.scroll.length < 2)
      obj.scroll = [1.0, 1.0];
    if (obj.alpha == null || Math.isNaN(obj.alpha)) obj.alpha = 1;
    if (obj.angle == null || Math.isNaN(obj.angle)) obj.angle = 0;
    if (obj.color == null) obj.color = 'FFFFFF';
    else obj.color = colorToHex(parseColor(obj.color));
    if (obj.flipX == null) obj.flipX = false;
    if (obj.flipY == null) obj.flipY = false;
    if (obj.antialiasing == null) obj.antialiasing = true;
    if (obj.visible == null) obj.visible = true;
    if (obj.filters == null) obj.filters = FILTER_BOTH_QUALITY;
    if (obj.danceEvery == null || Math.isNaN(obj.danceEvery)) obj.danceEvery = 0;
    if (obj.image == null) obj.image = obj.type == 'square' ? '' : 'stageback';
    if (obj.animations == null) obj.animations = [];
    if (obj.firstAnimation == null) obj.firstAnimation = '';
    return obj;
  }

  /** Map `gfGroup` / `dadGroup` / `boyfriendGroup` onto the short ids. */
  public static function canonicalType(type:String):String
  {
    if (type == null) return 'sprite';
    return switch (type)
    {
      case 'gfGroup': 'gf';
      case 'dadGroup': 'dad';
      case 'boyfriendGroup': 'boyfriend';
      default: type;
    };
  }

  public static function isCharacterType(type:String):Bool
  {
    var canonical:String = canonicalType(type);
    return canonical == 'gf' || canonical == 'dad' || canonical == 'boyfriend';
  }

  public static function isReservedName(name:String):Bool
  {
    if (name == null) return true;
    return reservedNames.indexOf(name) != -1;
  }

  public static function isPropType(type:String):Bool
  {
    var canonical:String = canonicalType(type);
    return canonical == 'sprite' || canonical == 'animatedSprite' || canonical == 'square';
  }

  /**
   * Make sure the working copy has gf/dad/boyfriend markers so the editor can
   * reorder characters against props. Does not mutate a file that already has
   * every slot.
   */
  public static function ensureCharacterSlots(stage:Dynamic):Dynamic
  {
    normalizeStage(stage);
    var objects:Array<Dynamic> = cast stage.objects;
    var haveGf:Bool = false;
    var haveDad:Bool = false;
    var haveBf:Bool = false;
    for (obj in objects)
    {
      var type:String = canonicalType(obj.type);
      if (type == 'gf') haveGf = true;
      else if (type == 'dad') haveDad = true;
      else if (type == 'boyfriend') haveBf = true;
    }
    if (!haveGf) objects.push({type: 'gf'});
    if (!haveDad) objects.push({type: 'dad'});
    if (!haveBf) objects.push({type: 'boyfriend'});
    stage.objects = objects;
    return stage;
  }

  /** Default prop or character-slot object. */
  public static function defaultObject(type:String, name:String):Dynamic
  {
    var canonical:String = canonicalType(type);
    if (isCharacterType(canonical))
      return {type: canonical};

    var obj:Dynamic = {
      type: canonical,
      name: name,
      x: 0,
      y: 0,
      scale: canonical == 'square' ? [200.0, 200.0] : [1.0, 1.0],
      scroll: [1.0, 1.0],
      alpha: 1.0,
      angle: 0.0,
      color: 'FFFFFF',
      flipX: false,
      flipY: false,
      antialiasing: true,
      visible: true,
      filters: FILTER_BOTH_QUALITY,
      danceEvery: 0.0,
      image: canonical == 'square' ? '' : 'stageback',
      animations: [],
      firstAnimation: ''
    };
    return obj;
  }

  /**
   * Week 1's hardcoded layout as JSON objects, so a new custom stage can start
   * from the vanilla look without copying `stages.StageWeek1`.
   */
  public static function week1Template():Dynamic
  {
    var stage:Dynamic = dummyStage();
    stage.objects = [
      normalizeObject({
        type: 'sprite',
        name: 'stageback',
        image: 'stageback',
        x: -600,
        y: -200,
        scroll: [0.9, 0.9],
        filters: FILTER_BOTH_QUALITY
      }),
      normalizeObject({
        type: 'sprite',
        name: 'stagefront',
        image: 'stagefront',
        x: -650,
        y: 600,
        scroll: [0.9, 0.9],
        scale: [1.1, 1.1],
        filters: FILTER_BOTH_QUALITY
      }),
      normalizeObject({
        type: 'sprite',
        name: 'stageLight',
        image: 'stage_light',
        x: -125,
        y: -100,
        scroll: [0.9, 0.9],
        scale: [1.1, 1.1],
        filters: FILTER_HIGH
      }),
      normalizeObject({
        type: 'sprite',
        name: 'stageLight2',
        image: 'stage_light',
        x: 1225,
        y: -100,
        scroll: [0.9, 0.9],
        scale: [1.1, 1.1],
        flipX: true,
        filters: FILTER_HIGH
      }),
      normalizeObject({
        type: 'sprite',
        name: 'stageCurtains',
        image: 'stagecurtains',
        x: -500,
        y: -300,
        scroll: [1.3, 1.3],
        scale: [0.9, 0.9],
        filters: FILTER_HIGH
      }),
      {type: 'gf'},
      {type: 'dad'},
      {type: 'boyfriend'}
    ];
    stage.preload = buildPreload(stage.objects);
    return stage;
  }

  /** Deep copy via JSON so arrays/anims cannot alias the original. */
  public static function cloneStage(stage:Dynamic):Dynamic
  {
    return haxe.Json.parse(haxe.Json.stringify(normalizeStage(stage)));
  }

  public static function cloneObject(obj:Dynamic):Dynamic
  {
    return haxe.Json.parse(haxe.Json.stringify(normalizeObject(obj)));
  }

  /**
   * Unique `prefixN` that is not reserved and not used by `objects`.
   */
  public static function findUnoccupiedName(objects:Array<Dynamic>, prefix:String = 'sprite'):String
  {
    if (prefix == null || prefix.length < 1) prefix = 'sprite';
    var num:Int = 1;
    while (true)
    {
      var candidate:String = prefix + num;
      if (!isReservedName(candidate) && indexOfName(objects, candidate) == -1)
        return candidate;
      num++;
      if (num > 9999) return prefix + '_' + Std.string(Math.random());
    }
  }

  public static function indexOfName(objects:Array<Dynamic>, name:String):Int
  {
    if (objects == null || name == null) return -1;
    for (i in 0...objects.length)
    {
      if (objects[i] != null && Std.string(objects[i].name) == name)
        return i;
    }
    return -1;
  }

  /** Refuse reserved names and collisions; otherwise keep `wanted`. */
  public static function sanitizeName(objects:Array<Dynamic>, wanted:String, currentIndex:Int):String
  {
    var name:String = wanted != null ? wanted : 'sprite';
    name = StringTools.trim(name);
    if (name.length < 1) name = 'sprite';
    if (isReservedName(name))
      return findUnoccupiedName(objects, name + '_');
    for (i in 0...objects.length)
    {
      if (i == currentIndex) continue;
      if (objects[i] != null && Std.string(objects[i].name) == name)
        return findUnoccupiedName(objects, name + '_');
    }
    return name;
  }

  public static function insertObject(objects:Array<Dynamic>, obj:Dynamic, index:Int = -1):Array<Dynamic>
  {
    if (objects == null) objects = [];
    var item:Dynamic = normalizeObject(obj);
    if (!isCharacterType(item.type))
      item.name = sanitizeName(objects, item.name, -1);
    if (index < 0 || index >= objects.length) objects.push(item);
    else objects.insert(index, item);
    return objects;
  }

  public static function removeObject(objects:Array<Dynamic>, index:Int):Array<Dynamic>
  {
    if (objects == null || index < 0 || index >= objects.length) return objects;
    if (isCharacterType(objects[index].type)) return objects;
    objects.splice(index, 1);
    return objects;
  }

  public static function duplicateObject(objects:Array<Dynamic>, index:Int):Array<Dynamic>
  {
    if (objects == null || index < 0 || index >= objects.length) return objects;
    var src:Dynamic = objects[index];
    if (src == null || isCharacterType(src.type)) return objects;
    var copy:Dynamic = cloneObject(src);
    copy.name = findUnoccupiedName(objects, Std.string(src.name) + '_copy');
    objects.insert(index + 1, copy);
    return objects;
  }

  /**
   * Move `index` by `delta` slots. Character slots move too — that is how
   * z-order against props is edited.
   *
   * @return the new index, or the original index if the move was refused.
   */
  public static function moveObject(objects:Array<Dynamic>, index:Int, delta:Int):Int
  {
    if (objects == null || index < 0 || index >= objects.length || delta == 0)
      return index;
    var next:Int = index + delta;
    if (next < 0) next = 0;
    if (next > objects.length - 1) next = objects.length - 1;
    if (next == index) return index;
    var item:Dynamic = objects[index];
    objects.splice(index, 1);
    objects.insert(next, item);
    return next;
  }

  public static function labelFor(obj:Dynamic):String
  {
    if (obj == null) return '(none)';
    var type:String = canonicalType(obj.type);
    if (type == 'gf') return 'Girlfriend';
    if (type == 'dad') return 'Opponent';
    if (type == 'boyfriend') return 'Boyfriend';
    var name:String = obj.name != null ? Std.string(obj.name) : 'unnamed';
    return name + ' (' + type + ')';
  }

  /**
   * Sprite-list labels, front-most first (matches the on-screen stacking
   * the editor shows: last array entry draws on top).
   */
  public static function listLabels(objects:Array<Dynamic>):Array<String>
  {
    var labels:Array<String> = [];
    if (objects == null) return labels;
    var i:Int = objects.length - 1;
    while (i >= 0)
    {
      labels.push(labelFor(objects[i]));
      i--;
    }
    return labels;
  }

  /** Convert a front-first list index back to the objects-array index. */
  public static function listIndexToObject(objects:Array<Dynamic>, listIndex:Int):Int
  {
    if (objects == null || listIndex < 0 || listIndex >= objects.length) return -1;
    return objects.length - 1 - listIndex;
  }

  /** Front-first index of `objectIndex` (the row the sprite list would show). */
  public static function objectToListIndex(objects:Array<Dynamic>, objectIndex:Int):Int
  {
    if (objects == null || objectIndex < 0 || objectIndex >= objects.length) return -1;
    return objects.length - 1 - objectIndex;
  }

  /** Clamp a sprite-list scroll offset so a window of `windowSize` rows stays in range. */
  public static function clampListScroll(total:Int, scroll:Int, windowSize:Int):Int
  {
    if (windowSize < 1) windowSize = 1;
    if (total <= windowSize) return 0;
    var max:Int = total - windowSize;
    if (scroll < 0) return 0;
    if (scroll > max) return max;
    return scroll;
  }

  /**
   * Keep `frontIndex` inside the visible window, moving `scroll` the shortest
   * distance that does so.
   */
  public static function scrollToShow(total:Int, frontIndex:Int, scroll:Int, windowSize:Int):Int
  {
    scroll = clampListScroll(total, scroll, windowSize);
    if (frontIndex < 0) return scroll;
    if (frontIndex < scroll) return clampListScroll(total, frontIndex, windowSize);
    if (frontIndex >= scroll + windowSize)
      return clampListScroll(total, frontIndex - windowSize + 1, windowSize);
    return scroll;
  }

  /**
   * Safe `mods/<mod>/stages/<name>.json` (or `mods/stages/` when no mod is
   * loaded). Rejects `..` and path separators so a typed name cannot escape
   * the mods folder.
   */
  public static function modStagePath(modDirectory:String, stageName:String):String
  {
    var file:String = sanitizeStageFileName(stageName) + '.json';
    var mod:String = sanitizeModFolder(modDirectory);
    if (mod.length < 1) return 'mods/stages/' + file;
    return 'mods/' + mod + '/stages/' + file;
  }

  /** File stem: letters, digits, dash, underscore. Strips `.json`. */
  public static function sanitizeStageFileName(name:String):String
  {
    if (name == null) return 'stage';
    var out:String = StringTools.trim(name);
    if (StringTools.endsWith(out.toLowerCase(), '.json'))
      out = out.substr(0, out.length - 5);
    var buf = new StringBuf();
    for (i in 0...out.length)
    {
      var c:String = out.charAt(i);
      var code:Int = c.charCodeAt(0);
      var ok:Bool = (code >= 97 && code <= 122) || (code >= 65 && code <= 90)
        || (code >= 48 && code <= 57) || c == '-' || c == '_';
      if (ok) buf.add(c);
    }
    var result:String = buf.toString();
    return result.length < 1 ? 'stage' : result;
  }

  /** Mod folder name with no `..` or slashes. Empty means "no mod loaded". */
  public static function sanitizeModFolder(mod:String):String
  {
    if (mod == null) return '';
    var out:String = StringTools.trim(mod);
    if (out.length < 1) return '';
    if (out.indexOf('..') != -1) return '';
    if (out.indexOf('/') != -1 || out.indexOf('\\') != -1) return '';
    return out;
  }

  /**
   * Combine the four editor filter checkboxes into a Psych bit mask.
   *
   * Quality: if neither Low nor High is ticked, both quality bits are set
   * (same as a missing `filters` field). Mode: Story *or* Freeplay sets
   * that bit; ticking both (or neither) means "every mode" and writes no
   * mode bit, because Psych treats `STORY` as taking precedence over
   * `FREEPLAY` when both are set.
   */
  public static function packFilters(low:Bool, high:Bool, story:Bool, freeplay:Bool):Int
  {
    var mask:Int = 0;
    if (low) mask |= FILTER_LOW;
    if (high) mask |= FILTER_HIGH;
    if ((mask & FILTER_BOTH_QUALITY) == 0) mask |= FILTER_BOTH_QUALITY;
    if (story && !freeplay) mask |= FILTER_STORY;
    else if (freeplay && !story) mask |= FILTER_FREEPLAY;
    return mask;
  }

  /** Whether `mask` has `bit` set. Null masks behave as both-quality. */
  public static function hasFilter(mask:Null<Int>, bit:Int):Bool
  {
    var m:Int = mask == null ? FILTER_BOTH_QUALITY : mask;
    return (m & bit) == bit;
  }

  /** Tick the Story checkbox? Neither mode bit means "shows in every mode". */
  public static function showsInStory(mask:Null<Int>):Bool
  {
    var m:Int = mask == null ? FILTER_BOTH_QUALITY : mask;
    if ((m & FILTER_STORY) == FILTER_STORY) return true;
    if ((m & FILTER_FREEPLAY) == FILTER_FREEPLAY) return false;
    return true;
  }

  /** Tick the Freeplay checkbox? Neither mode bit means "shows in every mode". */
  public static function showsInFreeplay(mask:Null<Int>):Bool
  {
    var m:Int = mask == null ? FILTER_BOTH_QUALITY : mask;
    if ((m & FILTER_FREEPLAY) == FILTER_FREEPLAY) return true;
    if ((m & FILTER_STORY) == FILTER_STORY) return false;
    return true;
  }

  /**
   * Whether a prop with `filters` should spawn, given the current quality
   * and story/freeplay mode. A zero/null filter mask is treated as "both
   * qualities" so older files without the field still show up.
   */
  public static function validateVisibility(filters:Null<Int>, lowQuality:Bool, storyMode:Bool):Bool
  {
    var mask:Int = filters == null ? FILTER_BOTH_QUALITY : filters;
    if ((mask & FILTER_STORY) == FILTER_STORY)
    {
      if (!storyMode) return false;
    }
    else if ((mask & FILTER_FREEPLAY) == FILTER_FREEPLAY)
    {
      if (storyMode) return false;
    }

    var low:Bool = (mask & FILTER_LOW) == FILTER_LOW;
    var high:Bool = (mask & FILTER_HIGH) == FILTER_HIGH;
    if (!low && !high) return true;
    if (lowQuality) return low;
    return high;
  }

  /**
   * Editor preview: a sprite is shown when at least one of its quality bits
   * matches an enabled checkbox, and its story/freeplay bit (if any) matches
   * the mode checkboxes. A mask with neither quality bit is always shown
   * quality-wise. `showStory` / `showFreeplay` default to true so older
   * 3-argument call sites keep working.
   */
  public static function previewVisible(filters:Null<Int>, showLow:Bool, showHigh:Bool, showStory:Bool = true, showFreeplay:Bool = true):Bool
  {
    var mask:Int = filters == null ? FILTER_BOTH_QUALITY : filters;
    if ((mask & FILTER_STORY) == FILTER_STORY)
    {
      if (!showStory) return false;
    }
    else if ((mask & FILTER_FREEPLAY) == FILTER_FREEPLAY)
    {
      if (!showFreeplay) return false;
    }

    var low:Bool = (mask & FILTER_LOW) == FILTER_LOW;
    var high:Bool = (mask & FILTER_HIGH) == FILTER_HIGH;
    if (!low && !high) return true;
    return (low && showLow) || (high && showHigh);
  }

  /**
   * Replay the idle/first animation on this beat?
   *
   * `danceEvery <= 0` means "never, the atlas loops on its own".
   * Values below 1 count as every beat (the usual "bop on the beat" request).
   * Values `>= 1` dance every N beats, like GF's `danceEveryNumBeats = 2`.
   */
  public static function shouldDance(danceEvery:Float, curBeat:Int):Bool
  {
    if (danceEvery <= 0) return false;
    if (curBeat < 0) return false;
    var interval:Int = danceEvery < 1 ? 1 : Std.int(danceEvery);
    if (interval < 1) interval = 1;
    return curBeat % interval == 0;
  }

  /** Snap `value` to a grid. `grid <= 0` leaves it untouched. */
  public static function snap(value:Float, grid:Float):Float
  {
    if (grid <= 0) return value;
    return Math.round(value / grid) * grid;
  }

  public static function nudge(value:Float, direction:Int, fast:Bool, grid:Float = 0):Float
  {
    var step:Float = fast ? NUDGE_FAST : NUDGE;
    var next:Float = value + direction * step;
    return grid > 0 ? snap(next, grid) : next;
  }

  public static function clampZoom(zoom:Float):Float
  {
    if (zoom != zoom) return DEFAULT_ZOOM;
    if (zoom < MIN_ZOOM) return MIN_ZOOM;
    if (zoom > MAX_ZOOM) return MAX_ZOOM;
    return zoom;
  }

  /**
   * Camera-follow offset for a character target, from the stage JSON.
   * The editor adds the live sprite's midpoint on top of this.
   */
  public static function cameraOffset(stage:Dynamic, target:String):Array<Float>
  {
    if (stage == null) return [0.0, 0.0];
    return switch (target)
    {
      case 'dad' | 'opponent': pair(stage.camera_opponent);
      case 'gf' | 'girlfriend': pair(stage.camera_girlfriend);
      default: pair(stage.camera_boyfriend);
    };
  }

  public static function characterPosition(stage:Dynamic, target:String):Array<Float>
  {
    if (stage == null) return [0.0, 0.0];
    return switch (target)
    {
      case 'dad' | 'opponent': pair(stage.opponent);
      case 'gf' | 'girlfriend': pair(stage.girlfriend);
      default: pair(stage.boyfriend);
    };
  }

  public static function setCharacterPosition(stage:Dynamic, target:String, x:Float, y:Float):Void
  {
    if (stage == null) return;
    switch (target)
    {
      case 'dad' | 'opponent':
        stage.opponent = [x, y];
      case 'gf' | 'girlfriend':
        stage.girlfriend = [x, y];
      default:
        stage.boyfriend = [x, y];
    }
  }

  public static function setCameraOffset(stage:Dynamic, target:String, x:Float, y:Float):Void
  {
    if (stage == null) return;
    switch (target)
    {
      case 'dad' | 'opponent':
        stage.camera_opponent = [x, y];
      case 'gf' | 'girlfriend':
        stage.camera_girlfriend = [x, y];
      default:
        stage.camera_boyfriend = [x, y];
    }
  }

  public static function pair(value:Dynamic):Array<Float>
  {
    if (value != null && Std.isOfType(value, Array) && value.length > 1)
      return [Std.parseFloat(Std.string(value[0])), Std.parseFloat(Std.string(value[1]))];
    return [0.0, 0.0];
  }

  /**
   * Parse a Psych color (`"FFFFFF"`, `"#FFFFFF"`, `"0xFFFFFFFF"`, or an int)
   * into a 0xRRGGBB integer. Invalid input becomes white.
   */
  public static function parseColor(color:Dynamic):Int
  {
    if (color == null) return 0xFFFFFF;
    if (Std.isOfType(color, Int))
    {
      var n:Int = cast color;
      return n & 0xFFFFFF;
    }
    var text:String = StringTools.trim(Std.string(color));
    text = StringTools.replace(text, '#', '');
    if (StringTools.startsWith(text.toLowerCase(), '0x'))
    {
      if (text.length >= 8) text = text.substr(text.length - 6);
      else text = text.substr(2);
    }
    if (text.length > 6) text = text.substr(text.length - 6);
    var parsed:Null<Int> = Std.parseInt('0x' + text);
    if (parsed == null) return 0xFFFFFF;
    return parsed & 0xFFFFFF;
  }

  public static function colorToHex(color:Int):String
  {
    var hex:String = StringTools.hex(color & 0xFFFFFF, 6);
    return hex;
  }

  /**
   * Psych `preload` map: image path -> filter mask. Built from the objects
   * so the loading screen can warm the same art the stage will draw.
   */
  public static function buildPreload(objects:Array<Dynamic>):Dynamic
  {
    var map:Dynamic = {};
    if (objects == null) return map;
    for (obj in objects)
    {
      if (obj == null || isCharacterType(obj.type)) continue;
      if (obj.type == 'square') continue;
      var image:String = obj.image != null ? Std.string(obj.image) : '';
      if (image.length < 1) continue;
      var key:String = image.indexOf('images/') == 0 ? image : 'images/' + image;
      var filters:Int = obj.filters != null ? obj.filters : FILTER_BOTH_QUALITY;
      Reflect.setField(map, key, filters);
    }
    return map;
  }

  public static function shadersFromString(text:String):Array<String>
  {
    if (text == null) return [];
    var parts:Array<String> = text.split(',');
    var out:Array<String> = [];
    for (part in parts)
    {
      var name:String = StringTools.trim(part);
      if (name.length > 0) out.push(name);
    }
    return out;
  }

  public static function shadersToString(shaders:Array<String>):String
  {
    if (shaders == null || shaders.length < 1) return '';
    return shaders.join(', ');
  }

  /**
   * Pretty JSON matching what the other editors write. Empty optional
   * collections are omitted so a stage with no props stays compact.
   */
  public static function stringify(stage:Dynamic):String
  {
    return haxe.Json.stringify(toSaveObject(stage), null, '\t');
  }

  public static function parse(raw:String):Dynamic
  {
    if (raw == null || StringTools.trim(raw).length < 1) return dummyStage();
    try
    {
      return normalizeStage(haxe.Json.parse(raw));
    }
    catch (e:Dynamic)
    {
      return dummyStage();
    }
  }

  public static function toSaveObject(stage:Dynamic):Dynamic
  {
    var src:Dynamic = normalizeStage(stage);
    var objects:Array<Dynamic> = cast src.objects;
    var saveObjects:Array<Dynamic> = [];
    for (obj in objects)
      saveObjects.push(toSaveObjectItem(obj));

    var out:Dynamic = {
      directory: src.directory,
      defaultZoom: src.defaultZoom,
      isPixelStage: src.isPixelStage == true,
      stageUI: src.stageUI,
      boyfriend: src.boyfriend,
      girlfriend: src.girlfriend,
      opponent: src.opponent,
      hide_girlfriend: src.hide_girlfriend == true,
      camera_boyfriend: src.camera_boyfriend,
      camera_opponent: src.camera_opponent,
      camera_girlfriend: src.camera_girlfriend,
      camera_speed: src.camera_speed
    };

    var shaders:Array<String> = cast src.shaders;
    if (shaders != null && shaders.length > 0) out.shaders = shaders;
    if (saveObjects.length > 0) out.objects = saveObjects;

    var preload:Dynamic = src.preload;
    if (preload == null || Reflect.fields(preload).length < 1)
      preload = buildPreload(objects);
    if (Reflect.fields(preload).length > 0) out.preload = preload;

    out._editorMeta = {
      gf: src._editorMeta.gf,
      dad: src._editorMeta.dad,
      boyfriend: src._editorMeta.boyfriend
    };
    return out;
  }

  static function toSaveObjectItem(obj:Dynamic):Dynamic
  {
    var type:String = canonicalType(obj.type);
    if (isCharacterType(type)) return {type: type};

    var item:Dynamic = {
      type: type,
      name: obj.name,
      x: obj.x,
      y: obj.y,
      scale: obj.scale,
      scroll: obj.scroll,
      alpha: obj.alpha,
      angle: obj.angle,
      color: colorToHex(parseColor(obj.color)),
      flipX: obj.flipX == true,
      flipY: obj.flipY == true,
      antialiasing: obj.antialiasing != false,
      filters: obj.filters != null ? obj.filters : FILTER_BOTH_QUALITY
    };
    if (obj.visible == false) item.visible = false;
    if (obj.danceEvery != null && obj.danceEvery > 0) item.danceEvery = obj.danceEvery;
    if (type != 'square') item.image = obj.image;
    if (type == 'animatedSprite')
    {
      item.animations = obj.animations != null ? obj.animations : [];
      item.firstAnimation = obj.firstAnimation != null ? obj.firstAnimation : '';
    }
    return item;
  }

  /** How many real props (not character slots) a stage JSON carries. */
  public static function propCount(objects:Array<Dynamic>):Int
  {
    if (objects == null) return 0;
    var n:Int = 0;
    for (obj in objects)
      if (obj != null && !isCharacterType(obj.type)) n++;
    return n;
  }
}
