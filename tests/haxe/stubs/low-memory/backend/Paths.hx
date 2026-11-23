package backend;

/** Minimal `Paths` test double tracking cache eviction, major GC and pin flags. */
class Paths
{
  public static var unused:Int = 0;
  public static var stored:Int = 0;
  public static var compacted:Int = 0;
  public static var majorGcs:Int = 0;
  public static var ignoreDumpExclusions:Bool = false;

  /** Increments the shallow-trim counter. */
  public static function clearUnusedMemory():Void unused++;

  /** Increments the deep-trim counter. */
  public static function clearStoredMemory():Void stored++;

  /** Increments the heap-compaction counter. */
  public static function compress():Void compacted++;

  /**
   * Records explicit garbage collector requests.
   *
   * @param major Whether a full mark-and-sweep GC was requested.
   */
  public static function gc(major:Bool = false):Void
  {
    if (major) majorGcs++;
  }

  /** Resets all call counters between test cases. */
  public static function reset():Void
  {
    unused = 0;
    stored = 0;
    compacted = 0;
    majorGcs = 0;
  }
}
