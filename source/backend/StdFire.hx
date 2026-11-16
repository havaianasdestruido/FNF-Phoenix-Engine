package backend;

#if html5
import js.Browser;
import js.html.DivElement;
#end

/** Cross-platform implementation of the small stdfire softmod API. */
class StdFire
{
  static inline final DEFAULT_TITLE:String = "Phoenix Engine";
  @:unreflective static var savedTitle:Null<String> = null;
  @:unreflective static var lastSoftmodTitle:Null<String> = null;
  @:unreflective static var lastTitleTarget:Dynamic = null;

  /**
   * Rename the running window/tab/activity without intercepting engine writes.
   * Passing null restores the previously observed title only if the same target
   * still shows the last stdfire title. A true result means accepted or queued.
   */
  public static function nativeTitleRename(title:Null<String>):Bool
  {
    // Native title APIs use NUL-terminated strings; never silently truncate.
    if (title != null && title.indexOf("\x00") >= 0) return false;
    if (title == null && lastSoftmodTitle == null) return true;

    var current = currentTitle();
    var target = currentTitleTarget();
    if (title == null)
    {
      if (current == null || target == null) return false;
      if (target != lastTitleTarget || current != lastSoftmodTitle)
      {
        // A normal engine/other-mod update or a new window took precedence.
        clearSavedTitle();
        return true;
      }
      if (savedTitle == null || !setPlatformTitle(savedTitle)) return false;
      clearSavedTitle();
      return true;
    }

    // Repeated stdfire writes retain the previous title, but an intervening
    // engine write or window replacement starts a fresh restore point.
    var previous = lastSoftmodTitle != null && target != null && target == lastTitleTarget && current == lastSoftmodTitle
      ? savedTitle : current;
    if (!setPlatformTitle(title)) return false;
    savedTitle = previous;
    lastSoftmodTitle = title;
    lastTitleTarget = target;
    return true;
  }

  static function clearSavedTitle():Void
  {
    savedTitle = null;
    lastSoftmodTitle = null;
    lastTitleTarget = null;
  }

  /** Show a native, modal message box. Browsers do not support custom titles. */
  public static function nativeMSGBox(message:String, ?title:String):Bool
  {
    if (message == null || message.indexOf("\x00") >= 0 || (title != null && title.indexOf("\x00") >= 0)) return false;
    if (title == null) title = DEFAULT_TITLE;
    try
    {
      #if html5
      Browser.alert(message);
      return true;
      #elseif android
      // SDL's JNI converts standard UTF-8 with NewStringUTF, which corrupts
      // supplementary characters. The Java bridge passes decoded Strings to
      // the same native Android dialog implementation instead.
      return android.platform.AndroidStdFire.showMessageBox(message, title);
      #elseif (cpp && windows)
      return Windows.alert(message, title);
      #elseif !flash
      var app = lime.app.Application.current;
      if (app == null || app.window == null) return false;
      // Lime delegates to SDL's platform-native message box (including mobile).
      // Its Void return cannot indicate whether the OS ultimately displayed it.
      #if (cpp && lime_cffi)
      return LimeNativeText.alert(app.window, message, title);
      #else
      app.window.alert(message, title);
      return true;
      #end
      #else
      return false;
      #end
    }
    catch (e:Dynamic)
    {
      return false;
    }
  }

  /** Show a brief, non-modal warning; never falls back to a message box. */
  public static function nativeWarn(message:String, ?title:String):Bool
  {
    if (message == null || message.indexOf("\x00") >= 0 || StringTools.trim(message).length == 0
        || (title != null && title.indexOf("\x00") >= 0)) return false;
    if (title == null || StringTools.trim(title).length == 0) title = DEFAULT_TITLE;
    try
    {
      #if html5
      return showBrowserWarning(message);
      #elseif android
      // A text Toast only: do not post an Android notification or show a dialog.
      return android.platform.AndroidStdFire.showToast(message);
      #elseif (ios && cpp)
      return ios.platform.IOSStdFire.showToast(message);
      #elseif (cpp && windows)
      return utils.PlatformUtil.sendNotification(title, message);
      #elseif (cpp && ((linux && !android) || (mac && !ios)))
      // The desktop helpers wait for an external process; keep that wait off
      // the game thread so a slow notification service cannot freeze play.
      return queueDesktopWarning(title, message);
      #else
      return false;
      #end
    }
    catch (e:Dynamic)
    {
      return false;
    }
  }

  static function currentTitle():Null<String>
  {
    #if html5
    return Browser.document != null ? Browser.document.title : null;
    #elseif !flash
    var app = lime.app.Application.current;
    return app != null && app.window != null ? app.window.title : null;
    #else
    return null;
    #end
  }

  static function currentTitleTarget():Dynamic
  {
    #if html5
    return Browser.document;
    #elseif !flash
    var app = lime.app.Application.current;
    return app != null ? app.window : null;
    #else
    return null;
    #end
  }

  static function setPlatformTitle(title:String):Bool
  {
    if (title == null) return false;
    try
    {
      #if html5
      if (Browser.document == null) return false;
      var app = lime.app.Application.current;
      // Keep Lime's cached window title in sync with document.title.
      if (app != null && app.window != null) app.window.title = title;
      else Browser.document.title = title;
      return Browser.document.title == title;
      #elseif android
      if (!android.platform.AndroidStdFire.setTitle(title)) return false;
      var app = lime.app.Application.current;
      if (app != null && app.window != null)
      {
        #if (cpp && lime_cffi)
        // Keep Lime's getter in sync without calling SDL_SetWindowTitle:
        // SDL's Android JNI uses NewStringUTF and can overwrite the correct
        // Activity title with a corrupted supplementary character.
        LimeNativeText.cacheTitle(app.window, title);
        #else
        app.window.title = title;
        #end
      }
      return true; // Android runs the Activity update on its UI thread.
      #elseif (ios && cpp)
      if (!ios.platform.IOSStdFire.setTitle(title)) return false;
      var app = lime.app.Application.current;
      if (app != null && app.window != null)
      {
        #if lime_cffi
        LimeNativeText.setTitle(app.window, title);
        #else
        app.window.title = title;
        #end
      }
      return true; // UIKit runs the scene update on its main queue.
      #elseif !flash
      var app = lime.app.Application.current;
      if (app == null || app.window == null) return false;
      #if (cpp && lime_cffi)
      return LimeNativeText.setTitle(app.window, title);
      #else
      app.window.title = title;
      return app.window.title == title;
      #end
      #else
      return false;
      #end
    }
    catch (e:Dynamic)
    {
      return false;
    }
  }

  #if (cpp && ((linux && !android) || (mac && !ios)))
  // Internal queue objects must not be exposed through mod reflection.
  @:unreflective static final desktopWarningMutex = new sys.thread.Mutex();
  @:unreflective static var desktopWarningPending:Null<{title:String, message:String}> = null;
  @:unreflective static var desktopWarningWorkerRunning:Bool = false;

  /** One worker and one pending warning bound resource use when mods spam calls. */
  static function queueDesktopWarning(title:String, message:String):Bool
  {
    desktopWarningMutex.acquire();
    desktopWarningPending = {title: title, message: message};
    if (desktopWarningWorkerRunning)
    {
      desktopWarningMutex.release();
      return true;
    }
    desktopWarningWorkerRunning = true;
    try
    {
      sys.thread.Thread.create(flushDesktopWarnings);
    }
    catch (e:Dynamic)
    {
      desktopWarningWorkerRunning = false;
      desktopWarningPending = null;
      desktopWarningMutex.release();
      return false;
    }
    desktopWarningMutex.release();
    return true;
  }

  static function flushDesktopWarnings():Void
  {
    while (true)
    {
      desktopWarningMutex.acquire();
      var pending = desktopWarningPending;
      desktopWarningPending = null;
      if (pending == null)
      {
        desktopWarningWorkerRunning = false;
        desktopWarningMutex.release();
        return;
      }
      desktopWarningMutex.release();
      try
      {
        utils.PlatformUtil.sendNotification(pending.title, pending.message);
      }
      catch (e:Dynamic) {} // A failed helper must not strand the worker/queue.
    }
  }
  #end

  #if html5
  @:unreflective static var browserWarning:Null<DivElement> = null;
  @:unreflective static var browserWarningTimer:Null<Int> = null;

  static function showBrowserWarning(message:String):Bool
  {
    var document = Browser.document;
    if (document == null || document.body == null) return false;
    if (browserWarning == null)
    {
      browserWarning = document.createDivElement();
      browserWarning.setAttribute("role", "status");
      browserWarning.setAttribute("aria-live", "polite");
      var style = browserWarning.style;
      style.position = "fixed";
      style.left = "50%";
      style.bottom = "24px";
      style.transform = "translateX(-50%)";
      style.zIndex = "2147483647";
      style.maxWidth = "min(90vw, 480px)";
      style.maxHeight = "25vh";
      style.overflow = "hidden";
      style.padding = "10px 16px";
      style.borderRadius = "8px";
      style.backgroundColor = "rgba(25, 25, 25, 0.94)";
      style.color = "white";
      style.font = "14px sans-serif";
      style.textAlign = "center";
      style.whiteSpace = "pre-wrap";
      style.pointerEvents = "none";
    }
    // Treat mod-provided text as text, never HTML.
    browserWarning.textContent = message;
    if (browserWarning.parentNode == null) document.body.appendChild(browserWarning);
    if (browserWarningTimer != null) Browser.window.clearTimeout(browserWarningTimer);
    browserWarningTimer = Browser.window.setTimeout(function()
    {
      if (browserWarning != null && browserWarning.parentNode != null)
        browserWarning.parentNode.removeChild(browserWarning);
      browserWarningTimer = null;
    }, 3500);
    return true;
  }
  #end
}
