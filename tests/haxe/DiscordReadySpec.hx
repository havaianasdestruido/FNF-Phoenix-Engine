import backend.DiscordClient;
import cpp.RawConstPointer;
import hxdiscord_rpc.Types;

/** Native regression: DiscordUser is a C++ value struct, not a nullable object. */
@:access(backend.DiscordClient)
class DiscordReadySpec
{
  static function main():Void
  {
    DiscordClient.reconnectAttempts = 3;
    DiscordClient.reconnectPending = true;
    DiscordClient.onReady(null);
    assertBackoffUnchanged("null callback pointer");

    var user = new DiscordUser();
    user.username = null;
    DiscordClient.onReady(RawConstPointer.addressOf(user));
    assertBackoffUnchanged("null username");

    // A successful callback must still clear the reconnect backoff. Updating
    // presence is safe without initializing Discord; no client/thread is started.
    user.username = "Phoenix";
    user.discriminator = null;
    DiscordClient.onReady(RawConstPointer.addressOf(user));
    if (DiscordClient.reconnectAttempts != 0 || DiscordClient.reconnectPending)
      throw "valid user did not reset reconnect backoff";

    Sys.println("PASS: Discord ready callback native struct and null guards");
  }

  static function assertBackoffUnchanged(context:String):Void
  {
    if (DiscordClient.reconnectAttempts != 3 || !DiscordClient.reconnectPending)
      throw context + " should return before resetting reconnect backoff";
  }
}
