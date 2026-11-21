import data.StageEditorCore;
import data.StageUndoStack;

/**
 * Contract tests for the Stage Editor core: Psych-compatible JSON, object
 * graph edits, quality filters, undo, camera helpers and the Week 1 template.
 *
 * Flixel-free so `tests/haxe/run-stage-editor.sh` can run it on the Haxe
 * interpreter without game haxelibs.
 */
class StageEditorSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function eq(actual:Dynamic, expected:Dynamic, label:String):Void
  {
    if (actual != expected) throw label + ': expected ' + expected + ', got ' + actual;
  }

  static function approx(actual:Float, expected:Float, label:String):Void
  {
    if (Math.abs(actual - expected) > 0.001) throw label + ': expected ' + expected + ', got ' + actual;
  }

  static function main():Void
  {
    dummyAndNormalize();
    characterSlots();
    namesAndReserved();
    objectGraph();
    filtersAndPreview();
    danceAndSnap();
    colorAndCamera();
    week1Template();
    jsonRoundtrip();
    psychCompatibility();
    undoStack();
    listScrollAndPaths();
    Sys.println('StageEditorSpec: PASS');
  }

  static function dummyAndNormalize():Void
  {
    var dummy:Dynamic = StageEditorCore.dummyStage();
    eq(dummy.defaultZoom, 0.9, 'dummy zoom');
    eq(dummy.boyfriend[0], 770, 'dummy bf x');
    eq(dummy.hide_girlfriend, false, 'dummy shows gf');
    eq(dummy._editorMeta.boyfriend, 'bf', 'dummy editor meta');
    check(dummy.objects.length == 0, 'dummy has no props until the editor asks');

    var partial:Dynamic = {directory: 'week3', defaultZoom: 1.05};
    StageEditorCore.normalizeStage(partial);
    eq(partial.directory, 'week3', 'normalize keeps directory');
    check(partial.boyfriend != null && partial.boyfriend.length > 1, 'normalize fills boyfriend');
    check(partial.camera_speed == 1, 'normalize fills camera_speed');
    check(partial.objects.length == 0, 'normalize does not invent props');
    eq(partial._editorMeta.gf, 'gf', 'normalize fills editor meta');

    var broken:Dynamic = StageEditorCore.parse('not json');
    eq(broken.defaultZoom, 0.9, 'invalid JSON falls back to dummy');
    check(StageEditorCore.parse(null).boyfriend != null, 'null JSON falls back to dummy');
    check(StageEditorCore.parse('').opponent != null, 'empty JSON falls back to dummy');
  }

  static function characterSlots():Void
  {
    var stage:Dynamic = StageEditorCore.dummyStage();
    StageEditorCore.ensureCharacterSlots(stage);
    eq(stage.objects.length, 3, 'three character slots');
    eq(StageEditorCore.canonicalType(stage.objects[0].type), 'gf', 'gf first');
    eq(StageEditorCore.canonicalType(stage.objects[1].type), 'dad', 'dad second');
    eq(StageEditorCore.canonicalType(stage.objects[2].type), 'boyfriend', 'bf last');
    eq(StageEditorCore.propCount(stage.objects), 0, 'slots are not props');

    StageEditorCore.ensureCharacterSlots(stage);
    eq(stage.objects.length, 3, 'ensure is idempotent');

    check(StageEditorCore.isCharacterType('gfGroup'), 'gfGroup is a character slot');
    check(StageEditorCore.isCharacterType('boyfriendGroup'), 'boyfriendGroup is a character slot');
    eq(StageEditorCore.canonicalType('dadGroup'), 'dad', 'dadGroup canonicalizes');
    check(!StageEditorCore.isCharacterType('sprite'), 'sprite is not a character');
    check(StageEditorCore.isPropType('animatedSprite'), 'animatedSprite is a prop');
    check(StageEditorCore.isPropType('square'), 'square is a prop');
  }

  static function namesAndReserved():Void
  {
    check(StageEditorCore.isReservedName('gf'), 'gf is reserved');
    check(StageEditorCore.isReservedName('boyfriendGroup'), 'boyfriendGroup is reserved');
    check(!StageEditorCore.isReservedName('stageback'), 'stageback is free');

    var objects:Array<Dynamic> = [];
    eq(StageEditorCore.findUnoccupiedName(objects, 'sprite'), 'sprite1', 'first free name');
    objects.push({type: 'sprite', name: 'sprite1'});
    eq(StageEditorCore.findUnoccupiedName(objects, 'sprite'), 'sprite2', 'skips taken names');

    eq(StageEditorCore.sanitizeName(objects, 'gf', -1).indexOf('gf_') == 0, true, 'reserved names get a suffix');
    eq(StageEditorCore.sanitizeName(objects, 'sprite1', -1) != 'sprite1', true, 'collisions get a suffix');
    eq(StageEditorCore.sanitizeName(objects, 'sprite1', 0), 'sprite1', 'keeping your own name is allowed');
    eq(StageEditorCore.sanitizeName(objects, '  curtains  ', -1), 'curtains', 'names are trimmed');
  }

  static function objectGraph():Void
  {
    var stage:Dynamic = StageEditorCore.dummyStage();
    StageEditorCore.ensureCharacterSlots(stage);
    var objects:Array<Dynamic> = cast stage.objects;

    StageEditorCore.insertObject(objects, StageEditorCore.defaultObject('sprite', 'bg'), 0);
    eq(objects[0].name, 'bg', 'insert at back');
    eq(objects[0].image, 'stageback', 'sprite default image');
    eq(StageEditorCore.propCount(objects), 1, 'one prop');

    StageEditorCore.duplicateObject(objects, 0);
    eq(objects[1].name, 'bg_copy1', 'duplicate gets a unique name');
    check(objects[1] != objects[0], 'duplicate is a different object');
    objects[0].x = 50;
    eq(objects[1].x, 0, 'duplicate does not alias position');

    var before:Int = objects.length;
    StageEditorCore.removeObject(objects, 2); // gf slot
    eq(objects.length, before, 'cannot delete a character slot');

    StageEditorCore.removeObject(objects, 1);
    eq(StageEditorCore.propCount(objects), 1, 'duplicate removed');

    var gfIndex:Int = 1;
    eq(StageEditorCore.canonicalType(objects[gfIndex].type), 'gf', 'gf still after the prop');
    var moved:Int = StageEditorCore.moveObject(objects, 0, 1);
    eq(moved, 1, 'prop moved in front of gf');
    eq(objects[0].type, 'gf', 'gf is now behind');
    eq(objects[1].name, 'bg', 'prop is now in front of gf');

    var labels:Array<String> = StageEditorCore.listLabels(objects);
    eq(labels[0].indexOf('Boyfriend') != -1, true, 'list is front-first');
    eq(StageEditorCore.listIndexToObject(objects, 0), objects.length - 1, 'front list index maps to last object');

    var cloned:Dynamic = StageEditorCore.cloneObject(objects[1]);
    var originalX:Dynamic = objects[1].x;
    cloned.x = 999;
    eq(objects[1].x, originalX, 'cloneObject does not alias');
  }

  static function filtersAndPreview():Void
  {
    var both:Int = StageEditorCore.FILTER_BOTH_QUALITY;
    var high:Int = StageEditorCore.FILTER_HIGH;
    var low:Int = StageEditorCore.FILTER_LOW;
    var story:Int = StageEditorCore.FILTER_STORY | both;

    check(StageEditorCore.validateVisibility(both, false, false), 'high quality sees both');
    check(StageEditorCore.validateVisibility(both, true, false), 'low quality sees both');
    check(StageEditorCore.validateVisibility(high, false, false), 'high quality sees high-only');
    check(!StageEditorCore.validateVisibility(high, true, false), 'low quality hides high-only');
    check(StageEditorCore.validateVisibility(low, true, false), 'low quality sees low-only');
    check(!StageEditorCore.validateVisibility(low, false, false), 'high quality hides low-only');
    check(!StageEditorCore.validateVisibility(story, false, false), 'story-only hidden in freeplay');
    check(StageEditorCore.validateVisibility(story, false, true), 'story-only shown in story');
    check(StageEditorCore.validateVisibility(null, false, false), 'null filters still show');

    check(StageEditorCore.previewVisible(high, false, true), 'editor high checkbox shows high sprites');
    check(!StageEditorCore.previewVisible(high, true, false), 'editor low-only hides high sprites');
    check(StageEditorCore.previewVisible(both, true, false), 'both-quality still shows when only low is checked');
    check(StageEditorCore.previewVisible(0, false, false), 'no bits means always visible in the editor');

    var packedLowStory:Int = StageEditorCore.packFilters(true, false, true, false);
    check(StageEditorCore.hasFilter(packedLowStory, StageEditorCore.FILTER_LOW), 'pack low');
    check(!StageEditorCore.hasFilter(packedLowStory, StageEditorCore.FILTER_HIGH), 'pack not high');
    check(StageEditorCore.hasFilter(packedLowStory, StageEditorCore.FILTER_STORY), 'pack story-only');
    check(!StageEditorCore.hasFilter(packedLowStory, StageEditorCore.FILTER_FREEPLAY), 'pack not freeplay');
    var bothModes:Int = StageEditorCore.packFilters(true, true, true, true);
    check(!StageEditorCore.hasFilter(bothModes, StageEditorCore.FILTER_STORY), 'both mode boxes write no story bit');
    check(!StageEditorCore.hasFilter(bothModes, StageEditorCore.FILTER_FREEPLAY), 'both mode boxes write no freeplay bit');
    var neitherQuality:Int = StageEditorCore.packFilters(false, false, false, false);
    eq(neitherQuality & StageEditorCore.FILTER_BOTH_QUALITY, StageEditorCore.FILTER_BOTH_QUALITY, 'no quality boxes still both');
    check(StageEditorCore.showsInStory(null), 'null mask shows in story');
    check(StageEditorCore.showsInFreeplay(null), 'null mask shows in freeplay');
    check(!StageEditorCore.showsInFreeplay(story), 'story-only hides the freeplay checkbox');
    check(!StageEditorCore.showsInStory(StageEditorCore.FILTER_FREEPLAY | both), 'freeplay-only hides the story checkbox');

    var storyOnly:Int = StageEditorCore.FILTER_STORY | high;
    check(!StageEditorCore.previewVisible(storyOnly, false, true, false, true), 'editor hides story-only when Story is off');
    check(StageEditorCore.previewVisible(storyOnly, false, true, true, false), 'editor shows story-only when Story is on');
  }

  static function danceAndSnap():Void
  {
    check(!StageEditorCore.shouldDance(0, 4), 'zero never dances');
    check(StageEditorCore.shouldDance(1, 0), 'every beat, beat 0');
    check(StageEditorCore.shouldDance(1, 7), 'every beat, beat 7');
    check(StageEditorCore.shouldDance(0.25, 3), 'fractional counts as every beat');
    check(StageEditorCore.shouldDance(2, 4), 'every 2 beats, even');
    check(!StageEditorCore.shouldDance(2, 5), 'every 2 beats, odd');
    check(!StageEditorCore.shouldDance(1, -1), 'negative beats do not dance');

    eq(StageEditorCore.snap(13, 0), 13, 'grid 0 is a no-op');
    eq(StageEditorCore.snap(13, 10), 10, 'snap down');
    eq(StageEditorCore.snap(16, 10), 20, 'snap up');
    eq(StageEditorCore.nudge(5, 1, false, 0), 6, 'nudge 1px');
    eq(StageEditorCore.nudge(5, 1, true, 0), 15, 'nudge 10px with shift');
    eq(StageEditorCore.clampZoom(0), 0.1, 'zoom floor');
    eq(StageEditorCore.clampZoom(99), 3, 'zoom ceiling');
    eq(StageEditorCore.clampZoom(Math.sqrt(-1)), 0.9, 'NaN zoom becomes default');
  }

  static function colorAndCamera():Void
  {
    eq(StageEditorCore.parseColor('FFFFFF'), 0xFFFFFF, 'plain hex');
    eq(StageEditorCore.parseColor('#FF0000'), 0xFF0000, 'hash hex');
    eq(StageEditorCore.parseColor('0xFF00FF00'), 0x00FF00, '0xAARRGGBB keeps RGB');
    eq(StageEditorCore.parseColor(null), 0xFFFFFF, 'null is white');
    eq(StageEditorCore.parseColor('nope'), 0xFFFFFF, 'garbage is white');
    eq(StageEditorCore.colorToHex(0x0A0B0C), '0A0B0C', 'hex pad');

    var stage:Dynamic = StageEditorCore.dummyStage();
    stage.camera_boyfriend = [10, 20];
    stage.opponent = [100, 200];
    eq(StageEditorCore.cameraOffset(stage, 'boyfriend')[0], 10, 'bf camera x');
    eq(StageEditorCore.characterPosition(stage, 'dad')[1], 200, 'dad y');
    StageEditorCore.setCharacterPosition(stage, 'gf', 3, 4);
    eq(stage.girlfriend[0], 3, 'set gf x');
    StageEditorCore.setCameraOffset(stage, 'dad', 7, 8);
    eq(stage.camera_opponent[1], 8, 'set dad cam y');

    var shaders = StageEditorCore.shadersFromString(' rain, glitch , ');
    eq(shaders.length, 2, 'shader split');
    eq(shaders[0], 'rain', 'shader trim');
    eq(StageEditorCore.shadersToString(shaders), 'rain, glitch', 'shader join');
  }

  static function week1Template():Void
  {
    var stage:Dynamic = StageEditorCore.week1Template();
    eq(StageEditorCore.propCount(stage.objects), 5, 'week 1 has five props');
    eq(stage.objects[0].image, 'stageback', 'back');
    eq(stage.objects[0].scroll[0], 0.9, 'back parallax');
    eq(stage.objects[3].flipX, true, 'right light is flipped');
    eq(stage.objects[2].filters, StageEditorCore.FILTER_HIGH, 'lights are high-quality');
    eq(StageEditorCore.canonicalType(stage.objects[5].type), 'gf', 'gf after curtains');
    var preloadFields = Reflect.fields(stage.preload);
    check(preloadFields.length >= 4, 'preload lists the images');
    check(Reflect.hasField(stage.preload, 'images/stageback'), 'preload key uses images/');
  }

  static function jsonRoundtrip():Void
  {
    var stage:Dynamic = StageEditorCore.week1Template();
    stage.shaders = ['rain'];
    var raw:String = StageEditorCore.stringify(stage);
    check(raw.indexOf('\t') != -1, 'pretty printed with tabs');
    var back:Dynamic = StageEditorCore.parse(raw);
    eq(back.shaders[0], 'rain', 'shaders survive');
    eq(StageEditorCore.propCount(back.objects), 5, 'props survive');
    eq(back.objects[0].name, 'stageback', 'names survive');
    eq(back._editorMeta.boyfriend, 'bf', 'editor meta survives');

    var compact:Dynamic = StageEditorCore.dummyStage();
    var compactRaw:String = StageEditorCore.stringify(compact);
    check(compactRaw.indexOf('"objects"') == -1, 'empty objects omitted from save');
    check(compactRaw.indexOf('"shaders"') == -1, 'empty shaders omitted from save');
  }

  static function psychCompatibility():Void
  {
    // Shape taken from Psych Engine 1.0 stage files (issue #16429).
    var psych:Dynamic = {
      directory: 'week1',
      defaultZoom: 0.9,
      boyfriend: [770, 100],
      girlfriend: [400, 130],
      opponent: [100, 100],
      hide_girlfriend: false,
      camera_boyfriend: [0, 0],
      camera_opponent: [0, 0],
      camera_girlfriend: [0, 0],
      camera_speed: 1,
      _editorMeta: {boyfriend: 'bf', gf: 'gf', dad: 'dad'},
      objects: [
        {
          type: 'animatedSprite',
          name: 'BG_characters',
          image: 'BG_characters',
          x: -281,
          y: 269,
          scale: [1, 1],
          scroll: [1.5, 1],
          danceEvery: 0.25,
          filters: 3,
          color: 'FFFFFF',
          animations: [{anim: 'BG_characters', name: '', loop: true, indices: []}],
          firstAnimation: 'BG_characters'
        },
        {type: 'gf'},
        {type: 'dad'},
        {type: 'boyfriend'}
      ]
    };
    StageEditorCore.normalizeStage(psych);
    eq(psych.objects[0].type, 'animatedSprite', 'keeps animatedSprite');
    eq(psych.objects[0].danceEvery, 0.25, 'keeps danceEvery');
    eq(StageEditorCore.canonicalType(psych.objects[1].type), 'gf', 'gf marker');
    eq(StageEditorCore.propCount(psych.objects), 1, 'one real prop');
    var raw:String = StageEditorCore.stringify(psych);
    var back:Dynamic = StageEditorCore.parse(raw);
    eq(back.objects[0].firstAnimation, 'BG_characters', 'firstAnimation roundtrip');
    eq(back.objects[0].scroll[0], 1.5, 'scroll x roundtrip');
  }

  static function undoStack():Void
  {
    var stack = new StageUndoStack(3);
    check(!stack.canUndo(), 'empty cannot undo');
    stack.push('a');
    stack.push('a');
    eq(stack.length(), 1, 'identical snapshots are ignored');
    stack.push('b');
    stack.push('c');
    stack.push('d');
    eq(stack.length(), 3, 'limit is honoured');
    eq(stack.current(), 'd', 'cursor on latest');
    eq(stack.undo(), 'c', 'undo to c');
    eq(stack.undo(), 'b', 'undo to b');
    check(!stack.canUndo(), 'oldest snapshot, no more undo');
    eq(stack.redo(), 'c', 'redo to c');
    stack.push('e');
    check(!stack.canRedo(), 'branching push drops redo');
    eq(stack.current(), 'e', 'new branch is current');
    stack.clear();
    eq(stack.length(), 0, 'clear empties');
  }

  static function listScrollAndPaths():Void
  {
    var objects:Array<Dynamic> = [];
    for (i in 0...5) objects.push({type: 'sprite', name: 's' + i});
    eq(StageEditorCore.objectToListIndex(objects, 0), 4, 'back object is last in the front-first list');
    eq(StageEditorCore.objectToListIndex(objects, 4), 0, 'front object is first in the list');
    eq(StageEditorCore.objectToListIndex(objects, -1), -1, 'bad object index');
    eq(StageEditorCore.listIndexToObject(objects, StageEditorCore.objectToListIndex(objects, 2)), 2, 'list roundtrip');

    eq(StageEditorCore.clampListScroll(10, 0, 14), 0, 'short list does not scroll');
    eq(StageEditorCore.clampListScroll(20, -3, 14), 0, 'scroll floor');
    eq(StageEditorCore.clampListScroll(20, 99, 14), 6, 'scroll ceiling 20-14');
    eq(StageEditorCore.clampListScroll(20, 2, 14), 2, 'scroll in range');
    eq(StageEditorCore.clampListScroll(1, 5, 0), 0, 'window of 0 still clamps to a short list');

    eq(StageEditorCore.scrollToShow(20, 0, 5, 14), 0, 'jump scroll up to selection');
    eq(StageEditorCore.scrollToShow(20, 19, 0, 14), 6, 'jump scroll down to selection');
    eq(StageEditorCore.scrollToShow(20, 8, 0, 14), 0, 'selection already visible stays');
    eq(StageEditorCore.LIST_WINDOW, 14, 'list window size');
    eq(StageEditorCore.GRID_SIZE, 10, 'grid size');

    eq(StageEditorCore.sanitizeStageFileName('My Stage.json'), 'MyStage', 'spaces and extension stripped');
    eq(StageEditorCore.sanitizeStageFileName('../hack'), 'hack', 'punctuation stripped');
    eq(StageEditorCore.sanitizeStageFileName('..'), 'stage', 'empty after sanitize');
    eq(StageEditorCore.sanitizeStageFileName(''), 'stage', 'empty name');
    eq(StageEditorCore.sanitizeStageFileName(null), 'stage', 'null name');
    eq(StageEditorCore.sanitizeStageFileName('week-1_b'), 'week-1_b', 'dash and underscore kept');
    eq(StageEditorCore.sanitizeModFolder('../x'), '', 'parent folder rejected');
    eq(StageEditorCore.sanitizeModFolder('foo/bar'), '', 'slash rejected');
    eq(StageEditorCore.sanitizeModFolder('foo\\bar'), '', 'backslash rejected');
    eq(StageEditorCore.sanitizeModFolder('phoenix-showcase'), 'phoenix-showcase', 'valid mod');
    eq(StageEditorCore.sanitizeModFolder(null), '', 'null mod');
    eq(StageEditorCore.modStagePath('phoenix-showcase', 'arena'), 'mods/phoenix-showcase/stages/arena.json', 'mod path');
    eq(StageEditorCore.modStagePath('', 'stage'), 'mods/stages/stage.json', 'no-mod path');
    eq(StageEditorCore.modStagePath('../evil', 'x'), 'mods/stages/x.json', 'bad mod falls back to mods/stages');
    eq(StageEditorCore.modStagePath('ok', '../nope.json'), 'mods/ok/stages/nope.json', 'file stem sanitized');
  }
}
