package play.helpers;

import backend.ClientPrefs;
import play.PlayState;

#if (SHADERS_ALLOWED && !neko)
import flixel.FlxCamera;
import flixel.FlxG;
import shaders.DistantNoteShader;
import shaders.ShaderWarmup;

/**
 * Optional Doido perspective pass, isolated from the flat HUD.
 *
 * The note camera (`PlayState.camNotes`) is inserted below `camHUD` so health and
 * rating text stay readable. It mirrors HUD motion but keeps its own filter list:
 * HUD shaders stay on the HUD, and note shaders can target `notes`/`camNotes`
 * (or the `strum`/`camStrum` aliases).
 */
class PlayStateDistantNotes
{
  /** Whether the optional note-only perspective pass can run on this build. */
  public static function distantNotesEnabled():Bool
  {
    return ClientPrefs.distantNotes && ClientPrefs.shaders;
  }

  /**
   * Adds a transparent camera below the HUD. Only notes, strums and their splashes
   * are routed here; ratings and health stay flat. Idempotent per song.
   */
  public static function setupDistantNotes(state:PlayState):Void
  {
    if (state == null || state.camNotes != null || !distantNotesEnabled()) return;

    state.distantNoteShader = new DistantNoteShader(ClientPrefs.downScroll);
    state.camNotes = new FlxCamera();
    state.camNotes.bgColor.alpha = 0;
    state.camNotes.addShader(state.distantNoteShader);

    final hudIndex:Int = FlxG.cameras.list.indexOf(state.camHUD);
    if (hudIndex >= 0) FlxG.cameras.insert(state.camNotes, hudIndex, false);
    else FlxG.cameras.add(state.camNotes, false);

    ShaderWarmup.track(state.distantNoteShader);
  }

  /** Mirrors HUD motion/visibility without sharing its shaders or distorting text. */
  public static function syncDistantNotes(state:PlayState):Void
  {
    final camera:FlxCamera = state != null ? state.camNotes : null;
    if (camera == null || state.camHUD == null) return;

    final hud:FlxCamera = state.camHUD;
    camera.scroll.copyFrom(hud.scroll);
    if (camera.zoom != hud.zoom) camera.zoom = hud.zoom;
    if (camera.angle != hud.angle) camera.angle = hud.angle;
    if (camera.alpha != hud.alpha) camera.alpha = hud.alpha;
    if (camera.visible != hud.visible) camera.visible = hud.visible;
    if (camera.width != hud.width) camera.width = hud.width;
    if (camera.height != hud.height) camera.height = hud.height;
    if (camera.scaleX != hud.scaleX || camera.scaleY != hud.scaleY) camera.setScale(hud.scaleX, hud.scaleY);
    // Camera.update() has already applied HUD shake when called from draw().
    camera.flashSprite.x = hud.flashSprite.x;
    camera.flashSprite.y = hud.flashSprite.y;
    final shader:DistantNoteShader = state.distantNoteShader;
    if (shader != null && shader.uDownscroll.value[0] != ClientPrefs.downScroll)
      shader.uDownscroll.value = [ClientPrefs.downScroll];
  }
}
#else
/** No extra camera/pass on targets without runtime shaders. */
class PlayStateDistantNotes
{
  /** Unsupported targets never enable the perspective pass. */
  public static function distantNotesEnabled():Bool return false;

  /** No-op setup on unsupported targets. */
  public static function setupDistantNotes(state:PlayState):Void {}

  /** No-op sync on unsupported targets. */
  public static function syncDistantNotes(state:PlayState):Void {}
}
#end
