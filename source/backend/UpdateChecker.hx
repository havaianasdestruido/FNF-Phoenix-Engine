package backend;

import backend.PhoenixReleases;
import haxe.Http;
#if lime
import lime.app.Application;
#end
#if (sys && target.threaded)
import sys.thread.Thread;
import sys.thread.Deque;
#end

enum UpdateCheckResult
{
  Available(release:PhoenixRelease);
  UpToDate(version:String);
  NoReleases;
  Failed(message:String);
}

/**
 * Shared, non-blocking update check for the title screen and the debug menu.
 * Results are cached for the session so returning to the title does not spam
 * GitHub; the debug menu can force a refresh. Native requests run on a worker
 * thread and are delivered back on Lime's main-thread update signal.
 */
class UpdateChecker
{
  public static var latestRelease(default, null):Null<PhoenixRelease> = null;
  public static var checking(default, null):Bool = false;

  static var lastResult:Null<UpdateCheckResult> = null;
  static var lastIncludePrereleases:Bool = false;
  static var callbacks:Array<UpdateCheckResult->Void> = [];
  #if (lime && sys && target.threaded)
  static var messages:Deque<Dynamic> = new Deque<Dynamic>();
  static var polling:Bool = false;
  #end

  public static function check(callback:UpdateCheckResult->Void, force:Bool = false):Void
  {
    if (callback == null) return;
    if (!force && lastResult != null && lastIncludePrereleases == ClientPrefs.enablePreReleaseUpdates)
    {
      callback(lastResult);
      return;
    }
    callbacks.push(callback);
    if (checking) return;
    checking = true;
    startRequest();
  }

  static function startRequest():Void
  {
    #if (lime && sys && target.threaded)
    try
    {
      if (Application.current != null)
      {
        if (!polling)
        {
          Application.current.onUpdate.add(poll);
          polling = true;
        }
        Thread.create(function() {
          performRequest(function(data) {
            messages.add({data: data, error: null});
          }, function(error) {
            messages.add({data: null, error: error});
          });
        });
        return;
      }
    }
    catch (e:Dynamic)
    {
      stopPolling();
      finish(null, 'Could not start the update check: ${e}');
      return;
    }
    #end
    performRequest(function(data) finish(data, null), function(error) finish(null, error));
  }

  #if (lime && sys && target.threaded)
  static function poll(_delta:Float):Void
  {
    var message:Dynamic = messages.pop(false);
    if (message == null) return;
    stopPolling();
    finish(message.data, message.error);
  }

  static function stopPolling():Void
  {
    if (polling && Application.current != null) Application.current.onUpdate.remove(poll);
    polling = false;
  }
  #end

  static function performRequest(onData:String->Void, onError:String->Void):Void
  {
    var finished:Bool = false;
    function fail(message:String):Void
    {
      if (finished) return;
      finished = true;
      onError(message);
    }

    try
    {
      final http:Http = new Http(RuntimeFlags.url("urls.releasesApi", PhoenixVersion.RELEASES_API_URL));
      http.setHeader("Accept", "application/vnd.github+json");
      http.setHeader("User-Agent", "Phoenix-Engine-Update-Checker");
      http.setHeader("X-GitHub-Api-Version", "2022-11-28");
      #if sys
      http.cnxTimeout = 10;
      #end
      http.onStatus = function(status:Int) {
        if (status < 200 || status >= 300) fail('GitHub returned HTTP $status.');
      };
      http.onError = function(error:String) fail('Update check failed: $error');
      http.onData = function(data:String) {
        if (finished) return;
        finished = true;
        onData(data);
      };
      http.request(false);
    }
    catch (e:Dynamic)
    {
      fail('Update check failed: $e');
    }
  }

  static function finish(data:Null<String>, error:Null<String>):Void
  {
    checking = false;
    // Read the current setting when the response arrives, even if the player
    // changed it while the request was in flight. Cache results per policy.
    lastIncludePrereleases = ClientPrefs.enablePreReleaseUpdates;
    var result:UpdateCheckResult;
    if (error != null)
    {
      result = Failed(error);
    }
    else
    {
      result = switch (PhoenixReleases.evaluate(data == null ? "" : data, PhoenixVersion.current, lastIncludePrereleases))
      {
        case Available(release):
          latestRelease = release;
          Available(release);
        case UpToDate(version):
          latestRelease = null;
          UpToDate(version);
        case NoReleases:
          latestRelease = null;
          NoReleases;
        case InvalidData:
          latestRelease = null;
          Failed("GitHub returned an invalid release list.");
      };
    }
    lastResult = result;
    final pending:Array<UpdateCheckResult->Void> = callbacks;
    callbacks = [];
    for (callback in pending)
    {
      try callback(result)
      catch (e:Dynamic) trace('[UpdateChecker] Callback failed: $e');
    }
  }
}
