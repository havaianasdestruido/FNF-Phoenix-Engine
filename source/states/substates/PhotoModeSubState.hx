package states.substates;

import backend.MusicBeatSubstate;
import backend.Paths;
import backend.PhotoModeMath;
import backend.SSPlugin;
import backend.Screenshot;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import play.PlayState;

/**
 * Paused-game photo tool opened from {@link PauseSubState}.
 *
 * It temporarily hides every gameplay camera except `camGame`, detaches the
 * normal camera follow, and provides free pan/zoom controls. Enter/A or F2
 * saves a clean frame to `screenshots/` through {@link backend.Screenshot};
 * the controls and global screenshot hotkey are restored when the mode closes.
 */
class PhotoModeSubState extends MusicBeatSubstate
{
  /** Seconds to leave the overlay hidden so the capture reads a clean frame. */
  static inline final CAPTURE_DELAY:Float = 0.15;

  /** Play state whose game camera is being framed. */
  var playState:PlayState;

  /** Transparent camera used only for the screen-space photo controls. */
  var photoCamera:FlxCamera;

  /** Camera visibility values captured before the HUD is hidden. */
  var savedCameraVisibility:Array<{camera:FlxCamera, visible:Bool}> = [];

  /** Camera follow target and viewport restored when Photo Mode closes. */
  var savedFollowTarget:FlxObject;

  /** Camera scroll coordinates captured on entry. */
  var savedScrollX:Float = 0;
  var savedScrollY:Float = 0;

  /** Game camera zoom captured on entry. */
  var savedZoom:Float = 1;

  /** Whether the global F2 screenshot plugin was enabled on entry. */
  var savedScreenshotEnabled:Bool = true;

  /** Whether the operating-system cursor was visible on entry. */
  var savedMouseVisible:Bool = false;

  /** Whether the FPS counter was visible on entry. */
  var savedFpsVisible:Bool = false;

  /** Whether the commit watermark was visible on entry. */
  var savedWatermarkVisible:Bool = false;

  /** Fixed-screen control panel, hidden temporarily while a screenshot is read. */
  var photoUi:FlxGroup;

  /** Bottom panel background. */
  var bottomBar:FlxSprite;

  /** Photo Mode title. */
  var titleText:FlxText;

  /** Input instructions for keyboard, mouse, and gamepad. */
  var instructionText:FlxText;

  /** Status message shown after a screenshot attempt. */
  var statusText:FlxText;

  /** Current camera zoom shown in the overlay. */
  var zoomText:FlxText;

  /** Reused point for converting pointer motion into overlay-camera space. */
  var pointer:FlxPoint = FlxPoint.get();

  /** Pointer coordinates from the previous drag update. */
  var previousPointerX:Float = 0;
  var previousPointerY:Float = 0;

  /** True while a mouse or touch pointer is dragging the camera. */
  var pointerDragging:Bool = false;

  /** Whether a screenshot is waiting for its clean-frame capture. */
  var saveInProgress:Bool = false;

  /** Timer used to capture after the controls have been hidden for one frame. */
  var captureTimer:FlxTimer;

  /** True after the original camera and plugin settings have been recorded. */
  var gameViewSaved:Bool = false;

  /** Prevents camera, cursor, and plugin state from being restored twice. */
  var restored:Bool = false;

  /** Saves the active PlayState for the photo session. */
  public function new()
  {
    super();
    playState = PlayState.instance;
  }

  /** Initializes the overlay and temporarily hands the game camera to the player. */
  override function create():Void
  {
    if (playState == null || playState.camGame == null)
    {
      super.create();
      close();
      return;
    }

    saveGameView();
    playState.camGame.target = null;
    hideGameplayCameras();

    photoCamera = new FlxCamera();
    photoCamera.bgColor.alpha = 0;
    photoCamera.zoom = 1;
    photoCamera.scroll.set(0, 0);
    FlxG.cameras.add(photoCamera, false);
    cameras = [photoCamera];

    createOverlay();
    addVirtualPad(LEFT_FULL, A_B);
    addVirtualPadCamera();

    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null) FlxG.mouse.visible = true;
    #end

    super.create();
  }

  /** Captures the current game-camera view, visibility, and screenshot setting. */
  function saveGameView():Void
  {
    final gameCamera:FlxCamera = playState.camGame;
    savedScrollX = gameCamera.scroll.x;
    savedScrollY = gameCamera.scroll.y;
    savedZoom = gameCamera.zoom;
    savedFollowTarget = gameCamera.target;
    savedScreenshotEnabled = SSPlugin.enabled;
    savedFpsVisible = Main.fpsVar != null && Main.fpsVar.visible;
    savedWatermarkVisible = Main.commitWatermark != null && Main.commitWatermark.visible;
    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null) savedMouseVisible = FlxG.mouse.visible;
    #end
    gameViewSaved = true;

    // Photo Mode handles F2 itself so the global plugin cannot capture the
    // controls overlay at the same time as the clean, HUD-free frame.
    SSPlugin.enabled = false;
    SSPlugin.clearPreview();
    if (Main.fpsVar != null) Main.fpsVar.visible = false;
    if (Main.commitWatermark != null) Main.commitWatermark.visible = false;
  }

  /** Hides all existing cameras other than the gameplay camera. */
  function hideGameplayCameras():Void
  {
    for (camera in FlxG.cameras.list)
    {
      if (camera == null) continue;
      savedCameraVisibility.push({camera: camera, visible: camera.visible});
      if (camera != playState.camGame) camera.visible = false;
    }
  }

  /** Creates the fixed-screen overlay and assigns it to the Photo Mode camera. */
  function createOverlay():Void
  {
    photoUi = new FlxGroup();
    photoUi.cameras = [photoCamera];
    add(photoUi);

    bottomBar = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    bottomBar.alpha = 0.78;
    bottomBar.scrollFactor.set();
    bottomBar.cameras = [photoCamera];
    photoUi.add(bottomBar);

    titleText = new FlxText(24, 0, 0, 'PHOTO MODE', 24);
    titleText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, FlxTextAlign.LEFT);
    titleText.scrollFactor.set();
    titleText.cameras = [photoCamera];
    photoUi.add(titleText);

    zoomText = new FlxText(0, 0, 0, '', 20);
    zoomText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, FlxTextAlign.RIGHT);
    zoomText.scrollFactor.set();
    zoomText.cameras = [photoCamera];
    photoUi.add(zoomText);

    #if sys
    final captureHint:String = 'Enter / A / F2: save to screenshots/';
    #else
    final captureHint:String = 'Screenshot export is unavailable on this build.';
    #end
    instructionText = new FlxText(24, 0, FlxG.width - 48,
      'Directional keys / D-pad or mouse drag: pan  |  Wheel / Q / E: zoom  |  Shift: fast  |  R: reset\n'
        + captureHint + '  |  Esc / B: return', 17);
    instructionText.setFormat(Paths.font('vcr.ttf'), 17, FlxColor.WHITE, FlxTextAlign.LEFT);
    instructionText.scrollFactor.set();
    instructionText.cameras = [photoCamera];
    photoUi.add(instructionText);

    statusText = new FlxText(24, 0, 0, 'Ready', 16);
    statusText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, FlxTextAlign.LEFT);
    statusText.scrollFactor.set();
    statusText.cameras = [photoCamera];
    photoUi.add(statusText);

    layoutOverlay(FlxG.width, FlxG.height);
  }

  /**
   * Repositions the overlay and resizes its transparent camera after a resize.
   * @param width New logical viewport width.
   * @param height New logical viewport height.
   */
  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    if (photoCamera != null) photoCamera.setSize(width, height);
    if (photoUi != null) layoutOverlay(width, height);
  }

  /**
   * Places fixed-screen controls at the bottom edge and keeps zoom at the right.
   * @param width Logical viewport width.
   * @param height Logical viewport height.
   */
  function layoutOverlay(width:Int, height:Int):Void
  {
    if (bottomBar != null)
    {
      bottomBar.setGraphicSize(width, 112);
      bottomBar.updateHitbox();
      bottomBar.setPosition(0, height - bottomBar.height);
    }

    if (titleText != null) titleText.setPosition(24, height - 103);
    if (zoomText != null)
    {
      zoomText.x = width - zoomText.width - 24;
      zoomText.y = height - 101;
    }
    if (instructionText != null)
    {
      instructionText.fieldWidth = Math.max(100, width - 48);
      instructionText.setPosition(24, height - 73);
      instructionText.updateHitbox();
    }
    if (statusText != null) statusText.setPosition(24, height - 30);
  }

  /**
   * Handles back, capture, pan, pointer dragging, zoom, and view reset.
   * @param elapsed Seconds elapsed since the previous update.
   */
  override function update(elapsed:Float):Void
  {
    if (controls.BACK)
    {
      close();
      return;
    }

    if (!saveInProgress)
    {
      updateCameraInput(elapsed);
      if (controls.ACCEPT || FlxG.keys.justPressed.F2) saveScreenshot();
    }

    updateZoomLabel();
    super.update(elapsed);
  }

  /**
   * Applies keyboard, gamepad, mouse-drag, and wheel camera input.
   * @param elapsed Seconds elapsed since the previous update.
   */
  function updateCameraInput(elapsed:Float):Void
  {
    final camera:FlxCamera = playState.camGame;
    final fast:Bool = FlxG.keys.pressed.SHIFT;
    final step:Float = PhotoModeMath.panDistance(elapsed, camera.zoom, fast);
    final horizontal:Float = (controls.UI_RIGHT ? 1 : 0) - (controls.UI_LEFT ? 1 : 0);
    final vertical:Float = (controls.UI_DOWN ? 1 : 0) - (controls.UI_UP ? 1 : 0);
    camera.scroll.x += horizontal * step;
    camera.scroll.y += vertical * step;

    if (FlxG.keys.pressed.Q) setZoom(camera.zoom * Math.pow(2, -elapsed));
    if (FlxG.keys.pressed.E) setZoom(camera.zoom * Math.pow(2, elapsed));
    if (FlxG.keys.justPressed.R) resetView();

    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null)
    {
      FlxG.mouse.getScreenPosition(photoCamera, pointer);
      if (FlxG.mouse.justPressed)
      {
        pointerDragging = true;
        previousPointerX = pointer.x;
        previousPointerY = pointer.y;
      }
      if (pointerDragging && FlxG.mouse.pressed)
      {
        camera.scroll.x -= (pointer.x - previousPointerX) / PhotoModeMath.clampZoom(camera.zoom);
        camera.scroll.y -= (pointer.y - previousPointerY) / PhotoModeMath.clampZoom(camera.zoom);
        previousPointerX = pointer.x;
        previousPointerY = pointer.y;
      }
      if (FlxG.mouse.justReleased) pointerDragging = false;
      if (FlxG.mouse.wheel != 0)
        setZoom(camera.zoom * Math.pow(1.12, FlxG.mouse.wheel));
    }
    #end
  }

  /**
   * Changes zoom around the viewport center without shifting the composition.
   * @param requestedZoom Zoom requested by the wheel or keyboard controls.
   */
  function setZoom(requestedZoom:Float):Void
  {
    final camera:FlxCamera = playState.camGame;
    final view = PhotoModeMath.zoomAtCenter(camera.scroll.x, camera.scroll.y, requestedZoom);
    camera.zoom = view.zoom;
    camera.scroll.set(view.scrollX, view.scrollY);
  }

  /** Restores the original paused camera framing. */
  function resetView():Void
  {
    final camera:FlxCamera = playState.camGame;
    camera.zoom = savedZoom;
    camera.scroll.set(savedScrollX, savedScrollY);
  }

  /** Updates the displayed zoom only when its rounded value changes. */
  function updateZoomLabel():Void
  {
    if (zoomText == null || playState == null || playState.camGame == null) return;
    final nextText:String = 'Zoom: ' + Math.round(playState.camGame.zoom * 100) / 100 + 'x';
    if (zoomText.text == nextText) return;
    zoomText.text = nextText;
    zoomText.updateHitbox();
    zoomText.x = FlxG.width - zoomText.width - 24;
  }

  /** Saves a clean screenshot through the existing backend Screenshot writer. */
  function saveScreenshot():Void
  {
    if (saveInProgress) return;
    saveInProgress = true;
    statusText.text = 'Saving screenshot...';
    photoUi.visible = false;
    if (virtualPad != null) virtualPad.visible = false;

    captureTimer = new FlxTimer().start(CAPTURE_DELAY, _ ->
    {
      var saved:Bool = false;
      #if sys
      try
      {
        saved = new Screenshot().save('screenshots');
      }
      catch (error:Dynamic)
      {
        FlxG.log.warn('Photo Mode: screenshot failed ($error).');
      }
      #end

      if (photoUi != null) photoUi.visible = true;
      if (virtualPad != null) virtualPad.visible = mobile.MobileControls.enabled;
      if (statusText != null)
      {
        #if sys
        statusText.text = saved ? 'Saved to screenshots/' : 'Could not save screenshot; check the game log.';
        #else
        statusText.text = 'Screenshot export is unavailable on this build.';
        #end
      }
      saveInProgress = false;
      captureTimer = null;
      layoutOverlay(FlxG.width, FlxG.height);
    });
  }

  /** Restores the camera, HUD cameras, cursor, and global screenshot hotkey. */
  function restoreGameView():Void
  {
    if (restored || !gameViewSaved) return;
    restored = true;

    if (captureTimer != null)
    {
      captureTimer.cancel();
      captureTimer = null;
    }

    if (playState != null && playState.camGame != null)
    {
      playState.camGame.target = savedFollowTarget;
      playState.camGame.zoom = savedZoom;
      playState.camGame.scroll.set(savedScrollX, savedScrollY);
    }
    for (entry in savedCameraVisibility)
      if (entry.camera != null) entry.camera.visible = entry.visible;

    SSPlugin.enabled = savedScreenshotEnabled;
    if (Main.fpsVar != null) Main.fpsVar.visible = savedFpsVisible;
    if (Main.commitWatermark != null) Main.commitWatermark.visible = savedWatermarkVisible;
    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null) FlxG.mouse.visible = savedMouseVisible;
    #end
  }

  /** Restores all temporarily changed global state and removes the overlay camera. */
  override function destroy():Void
  {
    restoreGameView();
    pointer = FlxDestroyUtil.put(pointer);
    if (photoCamera != null)
    {
      FlxG.cameras.remove(photoCamera);
      photoCamera = null;
    }
    super.destroy();
  }
}
