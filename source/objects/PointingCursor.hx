package objects;

import backend.ClientPrefs;
import backend.PointingCursorLogic;
import backend.PointingCursorLogic.PointingTarget;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;

/**
 * Pointing-finger overlay ported from the HaxeFlixel Cursor demo
 * (`FlxUICursor` in flixel-ui, MIT).
 *
 * Sits to the left of the hovered or selected menu button and tracks it
 * every frame. Keyboard/gamepad selection keeps the finger on `selected`;
 * moving the mouse over a registered sprite jumps the finger there, matching
 * `FlxUICursor.jumpToXY`. Hover detection works in the on-screen space of
 * the camera the menu is drawn on, so panning or parallax-scrolling menus
 * (the Phoenix main menu and options lists) pick the row the pointer is
 * actually on.
 */
class PointingCursor extends FlxSprite
{
  /** Index the sprite is parked on (`-1` when hidden). */
  public var pointedIndex:Int = -1;

  /**
   * Selection index `follow()` wants the caller to use. Equals `selected`
   * unless the mouse just jumped onto a different member.
   */
  public var selectionIndex:Int = -1;

  var lastMouseX:Float = Math.NaN;
  var lastMouseY:Float = Math.NaN;
  var appliedStyle:String = null;
  var appliedColor:String = null;

  /**
   * Creates a hidden pointing sprite. Call `follow()` (or
   * `attachAndFollow()`) to park it on a menu item.
   */
  public function new()
  {
    super(0, 0);
    scrollFactor.set();
    visible = false;
    moves = false;
    antialiasing = false;
    refreshAppearance();
  }

  /**
   * Hosts one pointing sprite on `host` and parks it on `members[selected]`.
   *
   * @param host state or substate that owns the sprite
   * @param cursor existing overlay, or `null` to create one
   * @param members menu sprites (`Array`/`FlxTypedGroup.members`); null holes are treated as hidden
   * @param selected current selection index
   * @return the (possibly newly created) overlay
   */
  public static function attachAndFollow(host:FlxState, cursor:PointingCursor, members:Dynamic,
      selected:Int):PointingCursor
  {
    if (host == null || !ClientPrefs.debugPointingCursor || members == null)
    {
      if (cursor != null)
      {
        cursor.visible = false;
        cursor.pointedIndex = -1;
        cursor.selectionIndex = selected;
      }
      return cursor;
    }

    if (cursor == null)
    {
      cursor = new PointingCursor();
      host.add(cursor);
    }
    else
      bringToFront(host, cursor);

    cursor.follow(members, selected);
    return cursor;
  }

  /**
   * Moves this sprite so it points at `members[selected]`, or at the member
   * under the mouse when the pointer just moved over one.
   *
   * Both the hit rectangles and the pointer are compared in the coordinate
   * space of the camera the members are drawn on, so hover picking follows
   * what is actually on screen even on menus whose camera pans or whose items
   * use a parallax scroll factor.
   *
   * @param members menu sprites (`Array`/`FlxTypedGroup.members`); null holes are treated as hidden
   * @param selected current selection index
   * @return index the caller should treat as selected (`selected` unless the
   *         mouse jumped to a different member)
   */
  public function follow(members:Dynamic, selected:Int):Int
  {
    refreshAppearance();

    final camera:FlxCamera = membersCamera(members);
    final targets:Array<PointingTarget> = collect(members, camera);
    var hovered:Int = -1;
    #if FLX_MOUSE
    if (mouseJustMoved())
    {
      final pointer:FlxPoint = FlxG.mouse.getScreenPosition(camera);
      hovered = PointingCursorLogic.pickByPointer(targets, pointer.x, pointer.y);
      pointer.put();
    }
    #end

    final visual:Int = hovered >= 0 ? hovered : selected;
    final vis:Int = PointingCursorLogic.visibleIndex(targets, visual);
    final show:Bool = PointingCursorLogic.shouldShow(ClientPrefs.debugPointingCursor, vis >= 0);
    if (!show)
    {
      visible = false;
      pointedIndex = -1;
      selectionIndex = selected;
      return selected;
    }

    final target:PointingTarget = targets[vis];
    final pos = PointingCursorLogic.anchorPosition(target.x, target.y, target.width, target.height, width, height);
    setPosition(pos.x, pos.y);
    visible = true;
    pointedIndex = vis;
    selectionIndex = hovered >= 0 ? vis : selected;

    final source:FlxObject = memberAt(members, vis);
    if (source != null && source.cameras != null && source.cameras.length > 0)
      cameras = source.cameras;

    return selectionIndex;
  }

  /**
   * Rebuilds the graphic and tint from `ClientPrefs` when the style or color
   * actually changed.
   */
  public function refreshAppearance():Void
  {
    final style:String = PointingCursorLogic.normalizeStyle(ClientPrefs.pointingCursorStyle);
    final colorName:String = PointingCursorLogic.normalizeColor(ClientPrefs.pointingCursorColor);
    if (style == appliedStyle && colorName == appliedColor) return;

    appliedStyle = style;
    appliedColor = colorName;
    rebuildGraphic(style);
    color = PointingCursorLogic.colorValue(colorName);
    antialiasing = false;
  }

  /**
   * Pushes `cursor` to the end of `host.members` so it draws above menu art.
   *
   * @param host owning state
   * @param cursor overlay to raise
   */
  static function bringToFront(host:FlxState, cursor:PointingCursor):Void
  {
    if (host == null || cursor == null || host.members == null || host.members.length == 0) return;
    if (host.members[host.members.length - 1] == cursor) return;
    if (!host.members.remove(cursor)) return;
    host.members.push(cursor);
  }

  /**
   * True when the mouse moved since the last `follow()` call.
   *
   * The raw game-space pointer is compared, not `FlxG.mouse.x/y`: those are
   * world coordinates that shift whenever a menu camera pans (the follow lerp
   * while keyboard scrolling) or zooms (beat pulses), so they used to re-run
   * hover picking against a pointer the player never moved — on the Phoenix
   * main menu that snapped the selection back up right after every scroll
   * down, making the list feel stuck.
   *
   * @return whether a `jumpToXY`-style hover pick should run
   */
  function mouseJustMoved():Bool
  {
    #if FLX_MOUSE
    if (FlxG.mouse == null || FlxG.game == null) return false;
    final mx:Float = FlxG.game.mouseX;
    final my:Float = FlxG.game.mouseY;
    final moved:Bool = lastMouseX != mx || lastMouseY != my;
    lastMouseX = mx;
    lastMouseY = my;
    return moved;
    #else
    return false;
    #end
  }

  /**
   * The camera the menu members are drawn on.
   *
   * Members usually share one camera; the first member that names one wins,
   * and the default camera is the fallback for members that never set
   * `cameras` (flixel then draws them on `FlxG.camera` anyway).
   *
   * @param members raw group members
   * @return camera whose scroll positions the members on screen
   */
  static function membersCamera(members:Dynamic):FlxCamera
  {
    if (members != null)
    {
      final length:Int = members.length;
      for (i in 0...length)
      {
        final object:FlxObject = memberAt(members, i);
        if (object != null && object.cameras != null && object.cameras.length > 0)
          return object.cameras[0];
      }
    }
    return FlxG.camera;
  }

  /**
   * Builds `PointingTarget` rectangles from a menu group's members, already
   * converted to the on-screen space of `camera` (world position minus the
   * camera scroll scaled by each member's scroll factor).
   *
   * @param members raw group members
   * @param camera camera the members are drawn on
   * @return parallel array of pointable on-screen rectangles
   */
  static function collect(members:Dynamic, camera:FlxCamera):Array<PointingTarget>
  {
    final targets:Array<PointingTarget> = [];
    if (members == null) return targets;
    final length:Int = members.length;
    for (i in 0...length)
    {
      final object:FlxObject = memberAt(members, i);
      if (object == null)
      {
        targets.push({x: 0, y: 0, width: 0, height: 0, visible: false});
        continue;
      }
      targets.push(PointingCursorLogic.screenRect(object.x, object.y, object.width, object.height, camera.scroll.x,
        camera.scroll.y, object.scrollFactor.x, object.scrollFactor.y,
        object.visible && object.exists && object.alive));
    }
    return targets;
  }

  /**
   * Casts `members[index]` to an `FlxObject` when it is one.
   *
   * @param members raw group members
   * @param index slot to read
   * @return the object, or `null`
   */
  static function memberAt(members:Dynamic, index:Int):FlxObject
  {
    if (members == null || index < 0 || index >= members.length) return null;
    final raw:Dynamic = members[index];
    if (raw == null) return null;
    if (Std.isOfType(raw, FlxObject)) return cast raw;
    return null;
  }

  /**
   * Bakes a white pointing graphic for `style` onto a transparent canvas.
   *
   * @param style canonical style name
   */
  function rebuildGraphic(style:String):Void
  {
    final size = PointingCursorLogic.spriteSize(style);
    final data:BitmapData = new BitmapData(size.width, size.height, true, 0x00000000);
    switch (style)
    {
      case 'Arrow':
        drawArrow(data);
      case 'Triangle':
        drawTriangle(data);
      default:
        drawFinger(data);
    }
    loadGraphic(data);
  }

  /**
   * Paints a right-pointing hand (palm + index finger) onto `data`.
   *
   * @param data destination pixels
   */
  static function drawFinger(data:BitmapData):Void
  {
    fillRect(data, 4, 12, 12, 16, 0xFFFFFFFF);
    fillRect(data, 6, 8, 6, 6, 0xFFFFFFFF);
    fillRect(data, 14, 13, 16, 6, 0xFFFFFFFF);
    fillRect(data, 26, 14, 4, 4, 0xFFFFFFFF);
  }

  /**
   * Paints a right-pointing chevron onto `data`.
   *
   * @param data destination pixels
   */
  static function drawArrow(data:BitmapData):Void
  {
    final h:Int = data.height;
    final w:Int = data.width;
    final mid:Int = Std.int(h / 2);
    for (y in 0...h)
    {
      final dist:Int = y < mid ? mid - y : y - mid;
      final start:Int = Std.int(dist * (w - 4) / (mid == 0 ? 1 : mid));
      for (x in start...w)
        data.setPixel32(x, y, 0xFFFFFFFF);
    }
  }

  /**
   * Paints a filled right-pointing triangle onto `data`.
   *
   * @param data destination pixels
   */
  static function drawTriangle(data:BitmapData):Void
  {
    final h:Int = data.height;
    final w:Int = data.width;
    final mid:Int = Std.int(h / 2);
    for (y in 0...h)
    {
      final dist:Int = y < mid ? mid - y : y - mid;
      final maxX:Int = w - 1 - Std.int(dist * w / (mid == 0 ? 1 : mid));
      for (x in 0...w)
        if (x <= maxX) data.setPixel32(x, y, 0xFFFFFFFF);
    }
  }

  /**
   * Fills a rectangle of `color` on `data`, clipped to the bitmap.
   *
   * @param data destination pixels
   * @param x left
   * @param y top
   * @param w width
   * @param h height
   * @param color ARGB pixel
   */
  static function fillRect(data:BitmapData, x:Int, y:Int, w:Int, h:Int, color:Int):Void
  {
    final maxX:Int = data.width;
    final maxY:Int = data.height;
    var row:Int = y;
    while (row < y + h)
    {
      if (row >= 0 && row < maxY)
      {
        var col:Int = x;
        while (col < x + w)
        {
          if (col >= 0 && col < maxX) data.setPixel32(col, row, color);
          col++;
        }
      }
      row++;
    }
  }
}
