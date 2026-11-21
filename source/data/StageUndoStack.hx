package data;

/**
 * Snapshot undo/redo for a stage JSON string. Consecutive identical
 * snapshots are ignored so holding an arrow key does not flood the stack.
 */
class StageUndoStack
{
  var entries:Array<String> = [];
  var index:Int = -1;
  var limit:Int;

  public function new(?limit:Int)
  {
    this.limit = limit != null && limit > 0 ? limit : StageEditorCore.UNDO_LIMIT;
  }

  /** Drop every snapshot. */
  public function clear():Void
  {
    entries = [];
    index = -1;
  }

  /** Record `snapshot` unless it matches the current entry. */
  public function push(snapshot:String):Void
  {
    if (snapshot == null) return;
    if (index >= 0 && entries[index] == snapshot) return;
    if (index < entries.length - 1)
      entries = entries.slice(0, index + 1);
    entries.push(snapshot);
    if (entries.length > limit)
      entries.shift();
    index = entries.length - 1;
  }

  /** True when there is an older snapshot than the current one. */
  public function canUndo():Bool
  {
    return index > 0;
  }

  /** True when a newer snapshot was undone. */
  public function canRedo():Bool
  {
    return index >= 0 && index < entries.length - 1;
  }

  /** Walk one snapshot back, or `null` if nothing to undo. */
  public function undo():Null<String>
  {
    if (!canUndo()) return null;
    index--;
    return entries[index];
  }

  /** Walk one snapshot forward, or `null` if nothing to redo. */
  public function redo():Null<String>
  {
    if (!canRedo()) return null;
    index++;
    return entries[index];
  }

  /** Snapshot the cursor is on. */
  public function current():Null<String>
  {
    if (index < 0 || index >= entries.length) return null;
    return entries[index];
  }

  /** Number of stored snapshots. */
  public function length():Int
  {
    return entries.length;
  }
}
