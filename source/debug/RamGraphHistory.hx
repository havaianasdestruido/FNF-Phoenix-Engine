package debug;

/** Fixed-size, chronological RAM samples and display scaling for the gameplay graph. */
class RamGraphHistory
{
  public var length(get, never):Int;
  var values:Array<Float> = [];
  var capacity:Int;
  var next:Int = 0;

  /** Create a history with room for the given number of samples. */
  public function new(capacity:Int)
  {
    this.capacity = Std.int(Math.max(1, capacity));
  }

  inline function get_length():Int return values.length;

  /** Remove old samples when the graph is enabled again. */
  public function clear():Void
  {
    values = [];
    next = 0;
  }

  /** Record one non-negative finite byte count. */
  public function add(value:Float):Void
  {
    if (!Math.isFinite(value) || value < 0) return;
    if (values.length < capacity)
      values.push(value);
    else
      values[next] = value;
    next = (next + 1) % capacity;
  }

  /** Read from oldest to newest. */
  public function get(index:Int):Float
  {
    if (index < 0 || index >= values.length) throw 'Invalid RAM sample index: $index';
    return values[values.length == capacity ? (next + index) % capacity : index];
  }

  /** Padded vertical bounds; a constant or empty history still has a usable range. */
  public function bounds():{min:Float, max:Float}
  {
    if (length == 0) return {min: 0, max: 1};
    var low = get(0);
    var high = low;
    for (i in 1...length)
    {
      var value = get(i);
      low = Math.min(low, value);
      high = Math.max(high, value);
    }
    var padding = Math.max((high - low) * 0.08, Math.max(high * 0.02, 1));
    return {min: Math.max(0, low - padding), max: high + padding};
  }

  /** Interpolate through two samples without overshooting either value. */
  public static inline function interpolate(from:Float, to:Float, t:Float):Float
  {
    t = Math.max(0, Math.min(1, t));
    var smooth = t * t * (3 - 2 * t);
    return from + (to - from) * smooth;
  }
}
