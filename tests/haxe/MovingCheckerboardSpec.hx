import backend.ClientPrefs;
import objects.MovingCheckerboard;

/** Isolated contract for the shared moving menu background. */
class MovingCheckerboardSpec
{
  static function main():Void
  {
    ClientPrefs.movingMenuCheckerboard = true;
    ClientPrefs.reducedMotion = false;

    final custom:MovingCheckerboard = new MovingCheckerboard(0xFFFFFFFF, 12, -5);
    assert(custom.visible && custom.active, 'the default preference should show and animate the layer');
    assertClose(custom.velocity.x, 12, 'horizontal speed should be pixels per second');
    assertClose(custom.velocity.y, -5, 'vertical speed should be pixels per second');
    assertClose(custom.scrollFactor.y, 0.07, 'the subtle menu-camera parallax should be retained');

    final defaults:MovingCheckerboard = new MovingCheckerboard();
    assertClose(defaults.velocity.x, MovingCheckerboard.DEFAULT_SPEED_X, 'default horizontal speed');
    assertClose(defaults.velocity.y, MovingCheckerboard.DEFAULT_SPEED_Y, 'default vertical speed');

    ClientPrefs.movingMenuCheckerboard = false;
    MovingCheckerboard.refreshAll();
    assert(!custom.visible && !custom.active, 'disabled checkerboards should be hidden and inactive');
    assertClose(custom.velocity.x, 0, 'disabled checkerboards should stop moving horizontally');
    assertClose(custom.velocity.y, 0, 'disabled checkerboards should stop moving vertically');

    ClientPrefs.movingMenuCheckerboard = true;
    ClientPrefs.reducedMotion = true;
    MovingCheckerboard.refreshAll();
    assert(custom.visible && !custom.active, 'reduced motion should leave a static pattern visible');
    assertClose(custom.velocity.x, 0, 'reduced motion should stop horizontal movement');
    assertClose(custom.velocity.y, 0, 'reduced motion should stop vertical movement');

    ClientPrefs.reducedMotion = false;
    MovingCheckerboard.refreshAll();
    assert(custom.visible && custom.active, 'turning reduced motion off should restore movement');
    assertClose(custom.velocity.x, 12, 'restored custom horizontal speed');
    assertClose(custom.velocity.y, -5, 'restored custom vertical speed');

    custom.destroy();
    defaults.destroy();
    ClientPrefs.movingMenuCheckerboard = false;
    MovingCheckerboard.refreshAll(); // destroyed instances must have unregistered safely

    trace('MovingCheckerboardSpec passed');
  }

  static function assert(value:Bool, message:String):Void
  {
    if (!value) throw message;
  }

  static function assertClose(actual:Float, expected:Float, message:String):Void
  {
    if (Math.abs(actual - expected) > 0.0001)
      throw '$message: expected $expected, got $actual';
  }
}
