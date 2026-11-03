package;

import backend.WindowNative;

/** Native desktop dialogs. Windows dialogs are modal and block the game thread. */
class Dialog
{
  /** Return true only for Yes; No, dismissal, unsupported targets, and failure are false. */
  public static function showYesNoWindows(message:String, title:String = "Phoenix Engine"):Bool
  {
    #if (cpp && windows)
    Windows.prepare();
    return WindowNative.messageBox(message != null ? message : "", title != null ? title : "Phoenix Engine", true, false) == 6;
    #else
    return false;
    #end
  }
}
