import debug.RamGraphHistory;

/** Renderer-free tests for the RAM graph's rolling samples and interpolation. */
class RamGraphHistorySpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    var history = new RamGraphHistory(3);
    check(history.length == 0, 'empty history');
    check(history.bounds().max > history.bounds().min, 'empty bounds');
    history.add(10);
    var flat = history.bounds();
    check(flat.min < 10 && flat.max > 10, 'flat values get padded bounds');
    history.add(20);
    history.add(30);
    history.add(40);
    history.add(50);
    check(history.length == 3, 'history is bounded');
    check(history.get(0) == 30 && history.get(1) == 40 && history.get(2) == 50, 'oldest-to-newest after wrap');
    var bounds = history.bounds();
    check(bounds.min < 30 && bounds.max > 50, 'bounds contain the visible samples');
    history.add(Math.NaN);
    history.add(Math.POSITIVE_INFINITY);
    history.add(-1);
    check(history.length == 3 && history.get(2) == 50, 'invalid samples ignored');
    check(RamGraphHistory.interpolate(10, 20, 0) == 10, 'line starts at first bar');
    check(RamGraphHistory.interpolate(10, 20, 1) == 20, 'line ends at second bar');
    check(RamGraphHistory.interpolate(10, 20, 0.5) == 15, 'line interpolates midpoint');
    for (i in 0...101)
    {
      var result = RamGraphHistory.interpolate(20, 10, i / 100);
      check(result >= 10 && result <= 20, 'interpolation must not overshoot');
    }
    history.clear();
    check(history.length == 0, 'clear removes stale samples');
    history.add(7);
    check(history.length == 1 && history.get(0) == 7, 'can sample after clear');
    var single = new RamGraphHistory(1);
    single.add(1);
    single.add(2);
    check(single.length == 1 && single.get(0) == 2, 'one-sample ring');
    trace('RAM graph history tests passed');
  }
}
