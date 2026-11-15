import sys.io.File;

/** Guards the small integration sites that cannot run without the whole game. */
class AdaptivePerformanceWiringSpec
{
  static function check(value:Bool, label:String):Void
  {
    if (!value) throw label;
  }

  static function text(path:String):String return File.getContent(path);

  static function slice(source:String, start:String, end:String):String
  {
    final from:Int = source.indexOf(start);
    check(from >= 0, 'missing source section: $start');
    final until:Int = source.indexOf(end, from + start.length);
    check(until > from, 'missing end of source section: $end');
    return source.substring(from, until);
  }

  static function contains(source:String, needle:String, label:String):Void
  {
    check(source.indexOf(needle) >= 0, label);
  }

  static function main():Void
  {
    final prefs = text('source/backend/ClientPrefs.hx');
    contains(prefs, 'public static var adaptivePerformance:Bool = false;', 'preference exists and defaults off');
    contains(prefs, 'for (field in Type.getClassFields(ClientPrefs))', 'preferences use the existing save/load reflection');
    final options = text('source/options/OptimizationSubState.hx');
    final row = slice(options, "new Option('Adaptive Performance'", 'addOption(option)');
    contains(row, "'adaptivePerformance', 'bool', false", 'Optimization row binds to the saved default-off preference');

    final state = text('source/play/PlayState.hx');
    contains(state, 'if (ClientPrefs.adaptivePerformance && !ffmpegMode)', 'adapter is opt-in and excluded from video rendering');
    contains(state, 'adaptivePerformance = new PlayStateAdaptivePerformance(this)', 'fresh adapter per PlayState');
    contains(state, 'adaptivePerformance.destroy()', 'adapter listener is removed on exit');
    contains(state, 'adaptivePerformance = null', 'song-scoped overrides are released on exit');
    contains(state, 'adaptivePerformance.setFocused(false)', 'focus loss resets measurements');
    contains(state, 'adaptivePerformance.setFocused(true)', 'focus gain resets measurements');
    check(state.split('adaptivePerformance.resetSamples()').length >= 3, 'opening and closing substates reset measurements');

    final adapter = text('source/play/helpers/PlayStateAdaptivePerformance.hx');
    contains(adapter, 'FlxG.signals.postDraw.add(frameListener)', 'sample actual draws instead of update calls');
    contains(adapter, 'FlxG.signals.postDraw.remove(frameListener)', 'unregister the draw callback');
    contains(adapter, 'FlxG.drawFramerate', 'use the real draw target');
    contains(adapter, 'System.gc()', 'request the runtime garbage collector');
    check(adapter.indexOf('Main.fpsVar') < 0 && adapter.indexOf('showFPS') < 0,
      'detection does not depend on the optional FPS display');
    for (name in ['noteSplashes', 'oppNoteSplashes', 'ratingPopups', 'camZooms', 'enableGC'])
      check(adapter.indexOf('ClientPrefs.' + name + ' =') < 0, 'adaptive logic never assigns $name');

    final rating = text('source/play/helpers/PlayStateRating.hx');
    final sprite = slice(rating, 'if (state.showRating && ClientPrefs.ratingPopups', 'state.rating.setupRating');
    contains(sprite, '!state.adaptiveRatingsDisabled', 'rating sprite suppressed');
    final simple = slice(rating, 'if (ClientPrefs.ratingPopups && !state.adaptiveRatingsDisabled && ClientPrefs.simplePopups',
      'state.judgeTxt.showHit');
    contains(simple, '!state.adaptiveRatingsDisabled', 'simple rating suppressed');
    final timing = slice(rating, 'public static function spawnTiming', 'final asset:');
    contains(timing, 'state.adaptiveRatingsDisabled', 'Early/Late label suppressed');
    final combo = slice(rating, 'if (state.showComboNum && ClientPrefs.comboPopups', 'MissCounter.digits');
    check(combo.indexOf('adaptiveRatingsDisabled') < 0, 'combo-number preference remains independent');

    final events = text('source/play/helpers/PlayStateEvents.hx');
    final bop = slice(events, "case 'Add Camera Zoom':", "case '");
    contains(bop, '!state.adaptiveCameraZoomsDisabled', 'chart camera bops suppressed');
    final beat = slice(state, 'override function beatHit()', 'public function characterBopper');
    final section = slice(state, 'override function sectionHit()', 'public function bopIcons');
    contains(beat, '!adaptiveCameraZoomsDisabled', 'beat bops suppressed');
    contains(section, '!adaptiveCameraZoomsDisabled', 'section bops suppressed');
    for (stage in ['source/stages/Spooky.hx', 'source/stages/Philly.hx'])
      contains(text(stage), 'adaptiveCameraZoomsDisabled', 'stage camera bops suppressed: $stage');

    final popup = text('source/objects/Popup.hx');
    contains(slice(popup, 'public function setupRating', 'public function setupNumber'), 'isRatingPopup = true',
      'shared popup pool identifies ratings');
    contains(slice(popup, 'public function setupNumber', 'public function alphaTween'), 'isRatingPopup = false',
      'recycled combo digits are not mistaken for ratings');
    Sys.println('AdaptivePerformanceWiringSpec: PASS');
  }
}
