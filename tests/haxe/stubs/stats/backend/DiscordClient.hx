package backend;

class DiscordClient
{
  public static var lastDetails:String = null;
  public static function changePresence(details:String, ?state:String):Void
    lastDetails = details;
}
