package utils;

class PlatformUtil
{
  public static var lastTitle:String;
  public static var lastMessage:String;
  public static var accept:Bool = true;
  #if cpp
  public static var delivered = new sys.thread.Lock();
  public static var onSend:Null<(String, String)->Void> = null;
  #end

  public static function sendNotification(title:String, message:String):Bool
  {
    lastTitle = title;
    lastMessage = message;
    #if cpp
    if (onSend != null) onSend(title, message);
    delivered.release();
    #end
    return accept;
  }
}
