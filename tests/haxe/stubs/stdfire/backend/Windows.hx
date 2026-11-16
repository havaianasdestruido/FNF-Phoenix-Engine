package backend;

class Windows
{
  public static var lastMessage:String;
  public static var lastTitle:String;
  public static var accept:Bool = true;

  public static function alert(message:String, ?title:String):Bool
  {
    lastMessage = message;
    lastTitle = title;
    return accept;
  }
}
