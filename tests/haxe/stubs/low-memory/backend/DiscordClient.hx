package backend;

class DiscordClient
{
  public static var isInitialized:Bool = true;
  public static var checks:Int = 0;
  public static function check():Void
  {
    checks++;
    isInitialized = ClientPrefs.discordRPC;
  }
}
