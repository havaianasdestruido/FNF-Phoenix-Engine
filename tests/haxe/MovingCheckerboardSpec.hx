import backend.ClientPrefs;
import backend.MenuCheckerTextures;
import backend.Paths;
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

    tilePreference(custom, defaults);

    custom.destroy();
    defaults.destroy();
    ClientPrefs.movingMenuCheckerboard = false;
    ClientPrefs.menuCheckerTexture = MenuCheckerTextures.DEFAULT_KEY;
    MovingCheckerboard.refreshAll(); // destroyed instances must have unregistered safely

    trace('MovingCheckerboardSpec passed');
  }

  /**
   * `ClientPrefs.menuCheckerTexture` picks the `images/checker*.png` tile every
   * live checkerboard repeats (Super Secret Debug Menu -> Menu Checker Texture).
   */
  static function tilePreference(custom:MovingCheckerboard, defaults:MovingCheckerboard):Void
  {
    Paths.reset();
    assert(custom.textureKey == MenuCheckerTextures.DEFAULT_KEY, 'the default tile is used before the option is touched');

    ClientPrefs.menuCheckerTexture = 'checker_fatty';
    final variant:MovingCheckerboard = new MovingCheckerboard();
    assert(variant.textureKey == 'checker_fatty', 'a new checkerboard repeats the preferred tile');
    assert(variant.graphic != null && variant.graphic.key == 'checker_fatty', 'the preferred tile is the graphic it draws');
    assert(custom.textureKey == MenuCheckerTextures.DEFAULT_KEY, 'an open menu keeps its tile until the preference is refreshed');

    ClientPrefs.menuCheckerTexture = 'checker_lol';
    MovingCheckerboard.refreshAll();
    assert(variant.textureKey == 'checker_lol', 'the changed instance swaps to the new tile');
    assert(custom.textureKey == 'checker_lol' && defaults.textureKey == 'checker_lol',
      'every live checkerboard swaps tile at once');
    assertClose(variant.velocity.x, MovingCheckerboard.DEFAULT_SPEED_X, 'swapping the tile keeps the movement');

    final loads:Int = Paths.loaded.length;
    MovingCheckerboard.refreshAll();
    assert(Paths.loaded.length == loads, 'an unchanged tile is not loaded again');

    // A variant the build does not ship (disabled mod, content-stripped build)
    // must not leave the menus with an empty backdrop.
    ClientPrefs.menuCheckerTexture = 'checker_missing';
    MovingCheckerboard.refreshAll();
    assert(variant.textureKey == MenuCheckerTextures.DEFAULT_KEY, 'a missing variant falls back to the default tile');
    assert(variant.graphic != null && variant.graphic.key == MenuCheckerTextures.DEFAULT_KEY,
      'the fallback actually loads the default tile');

    ClientPrefs.menuCheckerTexture = 'menuDesat';
    MovingCheckerboard.refreshAll();
    assert(variant.textureKey == MenuCheckerTextures.DEFAULT_KEY, 'an unrelated asset name is rejected');

    ClientPrefs.menuCheckerTexture = null;
    MovingCheckerboard.refreshAll();
    assert(variant.textureKey == MenuCheckerTextures.DEFAULT_KEY, 'a cleared preference uses the default tile');

    variant.destroy();

    // What the debug menu offers: the shipped tiles plus the folder contents.
    final offered:Array<String> = MovingCheckerboard.availableTextures();
    assert(offered.length > 0 && offered[0] == MenuCheckerTextures.DEFAULT_KEY, 'the default tile leads the offered list');
    assert(offered.indexOf('checker_sandbox') > -1, 'a tile found in the images folder is offered');
    assert(offered.indexOf('menuDesat') < 0, 'unrelated images are not offered');
    for (key in MenuCheckerTextures.BUILT_IN)
      assert(offered.indexOf(key) > -1, 'the shipped tile $key is always offered');
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
