import backend.ClientPrefs;
import flixel.FlxCamera;
import flixel.FlxG;
import play.PlayState;
import play.helpers.PlayStateDistantNotes;
import shaders.ShaderWarmup;

/** Camera ownership and HUD synchronization, with renderer-free stubs. */
class DistantNotesSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function main():Void
  {
    ClientPrefs.distantNotes = true;
    ClientPrefs.shaders = false;
    ClientPrefs.downScroll = true;
    final state = new PlayState();
    FlxG.cameras.add(state.camHUD, false);

    PlayStateDistantNotes.setupDistantNotes(state);
    check(!PlayStateDistantNotes.distantNotesEnabled(), 'global Shaders off wins');
    check(state.camStrum == null, 'no extra pass when shaders are off');

    ClientPrefs.shaders = true;
    PlayStateDistantNotes.setupDistantNotes(state);
    check(state.camStrum != null, 'note camera created');
    check(state.distantNoteShader.downscroll, 'downscroll reaches uniform wrapper');
    check(FlxG.cameras.list.length == 2, 'camera registered once');
    check(FlxG.cameras.list[0] == state.camStrum, 'note camera draws below HUD');
    check(FlxG.cameras.list[1] == state.camHUD, 'HUD remains above notes');
    check(state.camStrum.filters.length == 1, 'one note-only filter');
    check(ShaderWarmup.tracked == 1, 'shader queued for warm-up');

    PlayStateDistantNotes.setupDistantNotes(state);
    check(FlxG.cameras.list.length == 2, 'setup is idempotent');
    check(ShaderWarmup.tracked == 1, 'no duplicate warm-up');

    state.camHUD.zoom = 1.2;
    state.camHUD.angle = 5;
    state.camHUD.alpha = 0.4;
    state.camHUD.visible = false;
    state.camHUD.width = 1000;
    state.camHUD.height = 600;
    state.camHUD.setScale(1.1, 0.9);
    state.camHUD.scroll.set(10, 20);
    state.camHUD.flashSprite.x = 30;
    state.camHUD.flashSprite.y = 40;
    state.camHUD.filters.push('hud-only');
    PlayStateDistantNotes.syncDistantNotes(state);
    check(state.camStrum.zoom == 1.2, 'zoom follows HUD');
    check(state.camStrum.angle == 5, 'angle follows HUD');
    check(state.camStrum.alpha == 0.4, 'alpha follows HUD');
    check(!state.camStrum.visible, 'visibility follows HUD');
    check(state.camStrum.width == 1000 && state.camStrum.height == 600, 'size follows HUD');
    check(state.camStrum.scaleX == 1.1 && state.camStrum.scaleY == 0.9, 'scale follows HUD');
    check(state.camStrum.scroll.x == 10 && state.camStrum.scroll.y == 20, 'scroll follows HUD');
    check(state.camStrum.flashSprite.x == 30 && state.camStrum.flashSprite.y == 40, 'shake follows HUD');
    check(state.camStrum.filters.length == 1, 'HUD filters are not copied onto notes');
    check(state.camHUD.filters.length == 1, 'HUD keeps its own filters');

    ClientPrefs.downScroll = false;
    PlayStateDistantNotes.syncDistantNotes(state);
    check(!state.distantNoteShader.downscroll, 'live scroll preference sync');
    PlayStateDistantNotes.syncDistantNotes(null);
    Sys.println('DistantNotesSpec: PASS');
  }
}
