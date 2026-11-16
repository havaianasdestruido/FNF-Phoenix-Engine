import backend.ChainableEffects;
import backend.ScreenFilters;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.effects.chainable.FlxEffectSprite;
import flixel.addons.effects.chainable.FlxGlitchEffect;
import flixel.addons.effects.chainable.FlxGlitchEffect.FlxGlitchDirection;
import flixel.addons.effects.chainable.FlxOutlineEffect;
import flixel.addons.effects.chainable.FlxOutlineEffect.FlxOutlineMode;
import flixel.addons.effects.chainable.FlxRainbowEffect;
import flixel.addons.effects.chainable.FlxShakeEffect;
import flixel.addons.effects.chainable.FlxTrailEffect;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.effects.chainable.FlxWaveEffect.FlxWaveDirection;
import flixel.addons.effects.chainable.FlxWaveEffect.FlxWaveMode;
import flixel.addons.effects.chainable.IFlxEffect;
import flixel.addons.effects.chainable.RecordedEffect;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import openfl.display.Sprite;
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.filters.ColorMatrixFilter;
import openfl.filters.ConvolutionFilter;
import openfl.filters.DisplacementMapFilter;
import openfl.filters.DropShadowFilter;
import openfl.filters.GlowFilter;
import play.PlayState;

/**
 * Contract for the script filter API: `backend.ScreenFilters` (plain OpenFL
 * filters on cameras, sprites and the whole window) and
 * `backend.ChainableEffects` (the `flixel.addons.effects.chainable` wrapper).
 *
 * Renderer-free: the OpenFL filter classes, the addon classes and the Flixel
 * display object are recording stubs, so the spec checks the plumbing scripts
 * depend on — target resolution, the named registry, defaults and clamping,
 * preset matrices, detach/restore ordering and the PlayState reset — without a
 * GPU or the game haxelibs.
 */
class ScreenFiltersSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function check(value:Bool, label:String):Void
  {
    if (!value) throw '$label: expected true';
  }

  static function main():Void
  {
    reset();

    targets();
    defaultsAndPlumbing();
    registry();
    presets();
    displacement();
    windowFilters();
    chainableResolution();
    chainableOrdering();
    chainableEffects();
    resetLifecycle();

    trace('ScreenFiltersSpec: ok');
  }

  static function reset():Void
  {
    ScreenFilters.reset();
    ScreenFilters.clear();
    ChainableEffects.reset();
    PlayState.instance = null;
  }

  // ------------------------------------------------------------------ //
  //                        TARGET RESOLUTION                           //
  // ------------------------------------------------------------------ //

  static function targets():Void
  {
    final game:PlayState = new PlayState();

    check(ScreenFilters.resolveTarget('hud') == game.camHUD, 'hud resolves to camHUD');
    check(ScreenFilters.resolveTarget('CamHUD') == game.camHUD, 'camera names are case insensitive');
    check(ScreenFilters.resolveTarget('  game ') == game.camGame, 'and trimmed');
    check(ScreenFilters.resolveTarget('other') == game.camOther, 'other resolves to camOther');
    // camNotes is optional: without one the notes target falls back to the HUD.
    check(ScreenFilters.resolveTarget('notes') == game.camHUD, 'notes falls back to camHUD');
    game.camNotes = new FlxCamera();
    check(ScreenFilters.resolveTarget('strum') == game.camNotes, 'strum resolves to camNotes when it exists');

    check(ScreenFilters.resolveTarget('global') == FlxG.game, 'global is the game object');
    check(ScreenFilters.resolveTarget('window') == FlxG.game, 'window is an alias of global');

    // A camera made with createCamera() lives in the state's variables.
    final custom:FlxCamera = new FlxCamera();
    game.variables.set('mycam', custom);
    check(ScreenFilters.resolveTarget('mycam') == custom, 'createCamera cameras resolve by name');

    // Sprites are not filter targets: Flixel only filters cameras and the game
    // object, so a sprite tag must not silently attach to something else.
    final sprite:FlxSprite = new FlxSprite(1, 2);
    game.modchartSprites.set('box', sprite);
    equal(ScreenFilters.resolveTarget('box'), null, 'a sprite tag is not a filter target');
    check(ScreenFilters.spriteFromString('box') == sprite, 'but sprites still resolve for chainable effects');

    equal(ScreenFilters.resolveTarget('nope'), null, 'unknown targets resolve to null');
    check(ScreenFilters.targetError('nope').indexOf('"nope"') != -1, 'the error names the target');
  }

  // ------------------------------------------------------------------ //
  //                         FILTER PLUMBING                            //
  // ------------------------------------------------------------------ //

  static function defaultsAndPlumbing():Void
  {
    reset();
    final game:PlayState = new PlayState();

    // A camera keeps its own array, so pushing into it works the way scripts do.
    check(ScreenFilters.add('hud', 'soft', ScreenFilters.blur()), 'blur attaches');
    equal(game.camHUD.filters.length, 1, 'one filter on the HUD');
    final blur:BlurFilter = cast game.camHUD.filters[0];
    equal(blur.blurX, 4.0, 'documented blurX default');
    equal(blur.blurY, 4.0, 'documented blurY default');
    equal(blur.quality, 1, 'documented quality default');

    // Explicit arguments reach the OpenFL object.
    ScreenFilters.add('hud', 'heavy', ScreenFilters.blur(12, 8, 3));
    final heavy:BlurFilter = cast ScreenFilters.get('hud', 'heavy');
    equal(heavy.blurX, 12.0, 'blurX passed through');
    equal(heavy.quality, 3, 'quality passed through');

    // Glow and shadow defaults, plus colour parsing.
    ScreenFilters.add('game', 'glow', ScreenFilters.glow('red', 1, 6, 6, 2));
    final glow:GlowFilter = cast ScreenFilters.get('game', 'glow');
    equal(glow.color, FlxColor.RED, 'glow colour parses names');
    equal(glow.strength, 2.0, 'glow strength default');

    ScreenFilters.add('game', 'shadow', ScreenFilters.shadow());
    final shadow:DropShadowFilter = cast ScreenFilters.get('game', 'shadow');
    equal(shadow.distance, 4.0, 'shadow distance default');
    equal(shadow.angle, 45.0, 'shadow angle default');

    // Convolution kernel plumbing.
    ScreenFilters.add('notes', 'sharpen', ScreenFilters.convolution(3, 3, [0.0, -1, 0, -1, 5, -1, 0, -1, 0], 1));
    final conv:ConvolutionFilter = cast ScreenFilters.get('notes', 'sharpen');
    equal(conv.matrix.length, 9, 'kernel length');
    equal(conv.matrix[4], 5.0, 'kernel centre');

    // A sprite target is refused with a message that points at the right API.
    final sprite:FlxSprite = new FlxSprite(0, 0);
    PlayState.instance.modchartSprites.set('box', sprite);
    equal(ScreenFilters.add('box', 'glow', ScreenFilters.glow()), false, 'a sprite target is refused');
    check(ScreenFilters.targetError('box').indexOf('chainable effects') != -1, 'the message points at chainable effects');

    // update() swaps in place and keeps the name.
    final before:BitmapFilter = ScreenFilters.get('hud', 'soft');
    check(ScreenFilters.update('hud', 'soft', ScreenFilters.blur(20, 20)), 'update finds the entry');
    check(ScreenFilters.get('hud', 'soft') != before, 'update replaced the filter object');
    equal((cast ScreenFilters.get('hud', 'soft') : BlurFilter).blurX, 20.0, 'the new filter is the new one');

    // Adding under an existing name replaces rather than stacking.
    final countBefore:Int = game.camHUD.filters.length;
    ScreenFilters.add('hud', 'soft', ScreenFilters.blur(2, 2));
    equal(game.camHUD.filters.length, countBefore, 're-adding a name replaces instead of stacking');

    // Unknown targets and null filters are refused, never crash.
    equal(ScreenFilters.add('doesNotExist', 'x', ScreenFilters.blur()), false, 'unknown target is refused');
    equal(ScreenFilters.add('hud', 'x', null), false, 'null filter is refused');
  }

  static function registry():Void
  {
    reset();
    final game:PlayState = new PlayState();

    ScreenFilters.add('hud', 'a', ScreenFilters.blur());
    ScreenFilters.add('hud', 'b', ScreenFilters.glow());
    ScreenFilters.add('game', 'c', ScreenFilters.blur());
    equal(ScreenFilters.names('hud').join(','), 'a,b', 'names are listed in draw order');
    equal(ScreenFilters.exists('hud', 'a'), true, 'exists finds a');
    equal(ScreenFilters.exists('game', 'a'), false, 'names are per target');

    // remove() reports, detaches and frees the registry slot.
    equal(ScreenFilters.remove('hud', 'a'), true, 'remove finds a');
    equal(ScreenFilters.remove('hud', 'a'), false, 'removing twice is a no-op');
    equal(game.camHUD.filters.length, 1, 'the camera lost exactly one filter');
    equal(ScreenFilters.names('hud').join(','), 'b', 'the registry forgot a');

    // clear(target) leaves hand-attached filters alone: a stage's rain shader
    // and a mod's own filter must survive a script calling clearFilters().
    final rain:BitmapFilter = ScreenFilters.blur();
    game.camHUD.filters.push(rain);
    ScreenFilters.clear('hud');
    equal(game.camHUD.filters.length, 1, 'clear keeps filters it did not attach');
    check(game.camHUD.filters[0] == rain, 'the surviving filter is the hand-attached one');
    equal(ScreenFilters.names('hud').length, 0, 'the registry is empty for the HUD');
    equal(ScreenFilters.names('game').join(','), 'c', 'other targets are untouched by clear(target)');

    // clear() without a target wipes every target.
    ScreenFilters.clear();
    equal(ScreenFilters.names('game').length, 0, 'clear() drops every target');
    equal(game.camGame.filters.length, 0, 'and detaches them from the cameras');
  }

  // ------------------------------------------------------------------ //
  //                              PRESETS                               //
  // ------------------------------------------------------------------ //

  static function presets():Void
  {
    // Every advertised preset must build a valid 4x5 matrix.
    for (name in ScreenFilters.PRESETS)
    {
      final matrix:Array<Float> = ScreenFilters.matrixByName(name);
      check(matrix != null, 'preset $name exists');
      equal(matrix.length, 20, 'preset $name has 20 entries');
    }

    final invert:Array<Float> = ScreenFilters.matrixByName('invert');
    equal(invert[0], -1.0, 'invert negates red');
    equal(invert[4], 255.0, 'invert re-adds full red');
    equal(invert[18], 1.0, 'invert keeps alpha');

    final grey:Array<Float> = ScreenFilters.matrixByName('GREYSCALE');
    equal(grey[0], 0.299, 'greyscale uses the luma red weight');
    equal(grey[1], 0.587, 'greyscale uses the luma green weight');
    equal(grey[2], 0.114, 'greyscale uses the luma blue weight');

    equal(ScreenFilters.matrixByName('nope'), null, 'unknown presets return null');

    // Colour breaks the Game Boy: it is a two-colour LCD.
    final gameboy:Array<Float> = ScreenFilters.matrixByName('gameboy');
    equal(gameboy[2], 0.0, 'gameboy ignores input blue');
    equal(gameboy[12], 0.0, 'gameboy output blue is driven by green');

    // toMatrix accepts arrays, presets and nothing else.
    final custom:Array<Float> = ScreenFilters.toMatrix([2.0, 0, 0, 0, 10, 0, 2.0, 0, 0, 10, 0, 0, 2.0, 0, 10, 0, 0, 0, 1, 0]);
    equal(custom[0], 2.0, 'custom matrices pass through');
    equal(ScreenFilters.toMatrix('invert').join(','), invert.join(','), 'toMatrix resolves presets');
    equal(ScreenFilters.toMatrix(null).join(','), ScreenFilters.identityMatrix().join(','), 'null is the identity');
    equal(ScreenFilters.toMatrix([1, 2, 3]).length, 20, 'a short array falls back to identity');
    equal(ScreenFilters.toMatrix({}).length, 20, 'anything else falls back to identity');

    // Colours: names, hex strings and numbers all land on an FlxColor.
    equal(ScreenFilters.toColor('red'), FlxColor.RED, 'colour by name');
    equal(ScreenFilters.toColor(0xFF00FF), 0xFF00FF, 'colour by number');
    check(ScreenFilters.toColor('noSuchColour') != 0, 'unknown names fall back instead of throwing');
    equal(ScreenFilters.toColor(null), 0x000000, 'null colour is black');
  }

  // ------------------------------------------------------------------ //
  //                        DISPLACEMENT MAPS                           //
  // ------------------------------------------------------------------ //

  static function displacement():Void
  {
    reset();
    final game:PlayState = new PlayState();

    final graphic:flixel.graphics.FlxGraphic = new flixel.graphics.FlxGraphic(new openfl.display.BitmapData(64, 64));
    backend.Paths.specImages.set('dispMap', graphic);

    final filter:BitmapFilter = ScreenFilters.displacement('dispMap', 1, 2, 12, 12, 'clamp');
    check(filter != null, 'a displacement filter builds from an image');
    final displacement:DisplacementMapFilter = cast filter;
    equal(displacement.scaleX, 12.0, 'scaleX passed through');
    equal(displacement.mode, 'clamp', 'mode by name');

    // The map is a private copy: disposing the filter must not free the shared
    // graphic, which every sprite using that image still points at.
    check(displacement.mapBitmap != graphic.bitmap, 'the map bitmap is a clone');
    equal(displacement.mapBitmap.disposed, false, 'the clone starts alive');

    ScreenFilters.add('hud', 'warp', displacement);
    check(ScreenFilters.remove('hud', 'warp'), 'the displacement filter attaches');
    equal(displacement.mapBitmap, null, 'removing it frees the map bitmap');
    equal(graphic.bitmap.disposed, false, 'the shared graphic is untouched');

    // Mode names, including the "colour" spelling.
    equal(ScreenFilters.displacementMode('ignore'), 'ignore', 'ignore mode');
    equal(ScreenFilters.displacementMode('colour'), 'color', 'colour alias');
    equal(ScreenFilters.displacementMode('nonsense'), 'wrap', 'unknown modes wrap');

    // A missing map warns instead of throwing inside a script callback.
    equal(ScreenFilters.displacement('nope'), null, 'a missing map returns null');
  }

  // ------------------------------------------------------------------ //
  //                          WHOLE WINDOW                              //
  // ------------------------------------------------------------------ //

  static function windowFilters():Void
  {
    reset();
    new PlayState();

    // FlxG.game is a DisplayObject: assigning a fresh array per call is what
    // keeps both filters when a script adds two.
    check(ScreenFilters.add('global', 'one', ScreenFilters.blur()), 'global filters attach');
    check(ScreenFilters.add('global', 'two', ScreenFilters.glow()), 'a second global filter attaches');
    equal(FlxG.game.filters.length, 2, 'the game object carries both');
    equal(ScreenFilters.names('global').join(','), 'one,two', 'both are registered');

    ScreenFilters.remove('global', 'one');
    equal(FlxG.game.filters.length, 1, 'removing one leaves the other');
    ScreenFilters.clear('global');
    equal(FlxG.game.filters.length, 0, 'clear empties the game object');
  }

  // ------------------------------------------------------------------ //
  //                       CHAINABLE EFFECTS                            //
  // ------------------------------------------------------------------ //

  static function chainableResolution():Void
  {
    reset();
    final game:PlayState = new PlayState();

    final sprite:FlxSprite = new FlxSprite(10, 20);
    final entry:ChainableEntry = ChainableEffects.attach('box', sprite);
    check(entry != null, 'a sprite can be wrapped');
    equal(ChainableEffects.isAttached('box'), true, 'the tag is registered');
    equal(entry.effectSprite.target, sprite, 'the wrapper targets the sprite');
    equal(entry.effectSprite.effects.length, 0, 'the chain starts empty');
    equal(entry.effectSprite.updateTargetAnimation, false, 'the state still updates the target');

    // Attaching twice returns the same entry instead of stacking wrappers.
    check(ChainableEffects.attach('box', sprite) == entry, 're-attaching reuses the entry');

    // An unknown tag resolves through the state, like getProperty() does.
    final tagged:FlxSprite = new FlxSprite(0, 0);
    game.modchartSprites.set('tagged', tagged);
    check(ChainableEffects.entry('tagged') != null, 'a modchart sprite resolves by tag');
    equal(ChainableEffects.entry('nope'), null, 'unknown tags stay unresolved');
  }

  static function chainableOrdering():Void
  {
    reset();
    final game:PlayState = new PlayState();

    // A sprite that is already on screen is swapped for the wrapper in place, so
    // effects never change draw order.
    final first:FlxSprite = new FlxSprite(0, 0);
    final second:FlxSprite = new FlxSprite(0, 0);
    game.add(first);
    game.add(second);
    equal(game.members.indexOf(first), 0, 'the sprite starts first');

    ChainableEffects.attach('first', first);
    equal(game.members.indexOf(first), -1, 'the raw sprite is out of the state');
    equal(game.members.length, 2, 'the count is unchanged');
    final wrapper:FlxEffectSprite = cast game.members[0];
    equal(wrapper.target, first, 'the wrapper took the sprite slot');
    equal(game.members[1], second, 'the other member did not move');

    // Detaching puts the original sprite back in the same slot.
    check(ChainableEffects.detach('first'), 'detach works');
    equal(game.members[0], first, 'the original sprite is restored in place');
    equal(game.members.length, 2, 'still two members');
    equal(ChainableEffects.isAttached('first'), false, 'the tag is gone');

    // A sprite that was never added still gets a wrapper, just not in the state.
    final offscreen:FlxSprite = new FlxSprite(0, 0);
    final entry:ChainableEntry = ChainableEffects.attach('offscreen', offscreen);
    equal(game.members.indexOf(entry.effectSprite), -1, 'an unattached sprite stays out of the state');
    equal(entry.effectSprite.width, offscreen.width, 'the wrapper copies the sprite geometry');

    // front = true puts the wrapper on top instead of in the old slot.
    reset();
    final top:PlayState = new PlayState();
    final back:FlxSprite = new FlxSprite(0, 0);
    final cover:FlxSprite = new FlxSprite(0, 0);
    top.add(back);
    top.add(cover);
    ChainableEffects.attach('front', back, true);
    equal(top.members.length, 2, 'the original is swapped out, not left behind');
    check(Std.isOfType(top.members[1], FlxEffectSprite), 'front puts the wrapper last');
    equal(top.members[0], cover, 'and leaves the other member alone');
  }

  static function chainableEffects():Void
  {
    reset();
    final game:PlayState = new PlayState();
    final sprite:FlxSprite = new FlxSprite(0, 0);
    game.modchartSprites.set('box', sprite);

    // Shorthands reach the addon classes with the documented defaults.
    check(ChainableEffects.push('box', ChainableEffects.shake()), 'shake pushes');
    final shake:FlxShakeEffect = cast ChainableEffects.effects('box')[0];
    equal(shake.intensity, 5.0, 'shake intensity default');
    equal(shake.duration, 0.5, 'shake duration default');
    equal(shake.axes, FlxAxes.XY, 'shake shakes both axes by default');

    check(ChainableEffects.push('box', ChainableEffects.shake(3, 1, FlxAxes.X)), 'shake with axes');
    final single:FlxShakeEffect = cast ChainableEffects.effects('box')[1];
    equal(single.axes, FlxAxes.X, 'shake axis passes through');

    check(ChainableEffects.push('box', ChainableEffects.wave()), 'wave pushes');
    final wave:FlxWaveEffect = cast ChainableEffects.effects('box')[2];
    equal(wave.mode, FlxWaveMode.ALL, 'wave mode default');
    equal(wave.direction, FlxWaveDirection.HORIZONTAL, 'wave direction default');
    equal(wave.strength, 10, 'wave strength default');

    // Name parsing for every enum the addon takes.
    equal(ChainableEffects.waveMode('END'), FlxWaveMode.END, 'wave mode by name');
    equal(ChainableEffects.waveMode('nope'), FlxWaveMode.ALL, 'unknown wave mode falls back');
    equal(ChainableEffects.waveDirection('vertical'), FlxWaveDirection.VERTICAL, 'wave direction by name');

    check(ChainableEffects.push('box', ChainableEffects.glitch()), 'glitch pushes');
    final glitch:FlxGlitchEffect = cast ChainableEffects.effects('box')[3];
    equal(glitch.strength, 4, 'glitch strength default');
    equal(glitch.direction, FlxGlitchDirection.HORIZONTAL, 'glitch direction default');

    check(ChainableEffects.push('box', ChainableEffects.rainbow()), 'rainbow pushes');
    final rainbow:FlxRainbowEffect = cast ChainableEffects.effects('box')[4];
    equal(rainbow.speed, 5.0, 'rainbow speed default');

    check(ChainableEffects.push('box', ChainableEffects.outline('red', 3)), 'outline pushes');
    final outline:FlxOutlineEffect = cast ChainableEffects.effects('box')[5];
    equal(outline.thickness, 3, 'outline thickness');
    equal(outline.mode, FlxOutlineMode.FAST, 'outline mode default');
    equal(outline.color, FlxColor.RED, 'outline colour parses');
    equal(outline.dirty, true, 'a fresh outline redraws once');

    // Trails need the wrapper, which is why they take the tag.
    final trail:FlxTrailEffect = cast ChainableEffects.trail('box');
    check(trail != null, 'a trail can be built for an attached sprite');
    equal(trail.target, ChainableEffects.entry('box').effectSprite, 'the trail targets the wrapper');
    equal(trail.length, 10, 'trail length default');
    equal(ChainableEffects.trail('nope'), null, 'a trail for an unknown tag is refused');

    // build() maps the script-facing type names onto the same classes.
    check(ChainableEffects.build('box', 'shake') is FlxShakeEffect, 'build shake');
    check(ChainableEffects.build('box', 'wave') is FlxWaveEffect, 'build wave');
    check(ChainableEffects.build('box', 'outline', 'black', 2) is FlxOutlineEffect, 'build outline');
    equal(ChainableEffects.build('box', 'nope'), null, 'build refuses unknown types');

    // The chain can be edited after the fact.
    final total:Int = ChainableEffects.effects('box').length;
    check(ChainableEffects.pop('box'), 'pop removes the last effect');
    equal(ChainableEffects.effects('box').length, total - 1, 'one effect fewer');
    check(ChainableEffects.pop('box', 0), 'pop removes by index');
    equal(ChainableEffects.effects('box').length, total - 2, 'two effects fewer');
    equal(ChainableEffects.pop('box'), true, 'pop keeps working until the chain is empty');
    while (ChainableEffects.pop('box')) {}
    equal(ChainableEffects.pop('box'), false, 'popping an empty chain is a no-op');

    check(ChainableEffects.push('box', ChainableEffects.glitch()), 'push after empty');
    check(ChainableEffects.clear('box'), 'clear empties the chain');
    equal(ChainableEffects.effects('box').length, 0, 'the chain is empty');

    // setEnabled freezes the chain without dropping it.
    ChainableEffects.push('box', ChainableEffects.shake());
    check(ChainableEffects.setEnabled('box', false), 'the chain can be frozen');
    equal(ChainableEffects.entry('box').effectSprite.effectsEnabled, false, 'effectsEnabled is false');
    final effect:IFlxEffect = ChainableEffects.effects('box')[0];
    ChainableEffects.entry('box').effectSprite.update(0.016);
    final frozen:Int = (cast effect : RecordedEffect).updates;
    ChainableEffects.entry('box').effectSprite.update(0.016);
    equal((cast effect : RecordedEffect).updates, frozen, 'a frozen chain does not update');

    check(ChainableEffects.setEnabled('box', true), 'the chain resumes');
    ChainableEffects.entry('box').effectSprite.update(0.016);
    check((cast effect : RecordedEffect).updates > frozen, 'a resumed chain updates again');

    equal(ChainableEffects.setEnabled('nope', false), false, 'unknown tags are refused');
    equal(ChainableEffects.push('nope', ChainableEffects.shake()), false, 'pushing to an unknown tag is refused');
  }

  // ------------------------------------------------------------------ //
  //                              RESET                                 //
  // ------------------------------------------------------------------ //

  static function resetLifecycle():Void
  {
    reset();
    final game:PlayState = new PlayState();
    ScreenFilters.add('hud', 'soft', ScreenFilters.blur());
    ScreenFilters.add('global', 'tint', ScreenFilters.colorMatrix('gameboy'));
    final sprite:FlxSprite = new FlxSprite(0, 0);
    ChainableEffects.attach('box', sprite);

    // PlayState.destroy() calls both: the next song must not inherit a stale
    // filter name or a freed effect sprite.
    ScreenFilters.reset();
    ChainableEffects.reset();
    // `FlxG.game` outlives the state, so a 'global' filter must not survive it.
    equal(FlxG.game.filters.length, 0, 'a window filter is detached on reset too');
    equal(ScreenFilters.names('hud').length, 0, 'the filter registry is empty after reset');
    equal(ChainableEffects.isAttached('box'), false, 'the chainable registry is empty after reset');
    equal(game.camHUD.filters.length, 0, 'the camera was detached, not just forgotten');
    equal(ScreenFilters.add('hud', 'soft', ScreenFilters.blur()), true, 'the names are free again');
  }
}
