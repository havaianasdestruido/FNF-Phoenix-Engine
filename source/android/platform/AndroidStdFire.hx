package android.platform;

#if android
import lime.system.JNI;
#end

/** Small Android UI bridge used by stdfire; all Activity work runs on the UI thread. */
class AndroidStdFire
{
  #if android
  static var setTitleMethod:Dynamic = null;
  static var showMessageBoxMethod:Dynamic = null;
  static var showToastMethod:Dynamic = null;

  // JNI's NewStringUTF expects modified UTF-8, not the standard UTF-8 emitted
  // by hxcpp. Send bytes instead so supplementary characters survive intact.
  static function utf8Bytes(value:String):Array<Int>
  {
    var bytes = haxe.io.Bytes.ofString(value);
    return [for (index in 0...bytes.length) bytes.get(index)];
  }
  #end

  /** Queue an Activity/task title update; this cannot rename the installed app. */
  public static function setTitle(title:String):Bool
  {
    #if android
    if (title == null) return false;
    try
    {
      if (setTitleMethod == null)
        setTitleMethod = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'setAppTitleUtf8', '([B)Z');
      return setTitleMethod(utf8Bytes(title));
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  /** Show SDL's Android dialog with correctly decoded Unicode, blocking the game thread. */
  public static function showMessageBox(message:String, title:String):Bool
  {
    #if android
    if (message == null || title == null) return false;
    try
    {
      if (showMessageBoxMethod == null)
        showMessageBoxMethod = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'showMessageBoxUtf8', '([B[B)Z');
      return showMessageBoxMethod(utf8Bytes(message), utf8Bytes(title));
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }

  /** Queue a short bottom text Toast, without notification permissions. */
  public static function showToast(message:String):Bool
  {
    #if android
    if (message == null) return false;
    try
    {
      if (showToastMethod == null)
        showToastMethod = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'showToastUtf8', '([B)Z');
      return showToastMethod(utf8Bytes(message));
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    return false;
    #end
  }
}
