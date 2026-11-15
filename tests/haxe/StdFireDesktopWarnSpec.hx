import backend.StdFire;
import sys.thread.Lock;
import sys.thread.Thread;
import utils.PlatformUtil;

/** The Linux/macOS notification helper may block; the game thread must not. */
class StdFireDesktopWarnSpec
{
  static function check(condition:Bool, message:String):Void
  {
    if (!condition) throw message;
  }

  static function main():Void
  {
    var started = new Lock();
    var resume = new Lock();
    var returned = new Lock();
    var processed = new Lock();
    var messages:Array<String> = [];
    var accepted = false;

    PlatformUtil.onSend = function(title, message)
    {
      messages.push(message);
      if (message == 'First')
      {
        started.release();
        resume.wait(5);
      }
      processed.release();
    };

    Thread.create(function()
    {
      accepted = StdFire.nativeWarn('First');
      returned.release();
    });
    if (!started.wait(5))
    {
      resume.release();
      throw 'notification helper did not start';
    }
    if (!returned.wait(2))
    {
      resume.release();
      throw 'NativeWarn waited for a blocked desktop notification helper';
    }
    check(accepted, 'first warning queued');
    check(StdFire.nativeWarn('Superseded'), 'another warning queued');
    check(StdFire.nativeWarn('Latest'), 'latest warning queued');
    resume.release();
    check(processed.wait(5), 'first warning processed');
    check(processed.wait(5), 'latest warning processed');
    check(messages.length == 2 && messages[0] == 'First' && messages[1] == 'Latest',
      'only the latest pending warning is retained');

    var failed = new Lock();
    var recovered = new Lock();
    PlatformUtil.onSend = function(title, message)
    {
      if (message == 'Failure')
      {
        failed.release();
        throw 'simulated helper failure';
      }
      if (message == 'Recovered') recovered.release();
    };
    check(StdFire.nativeWarn('Failure'), 'failure case queued');
    check(failed.wait(5), 'failing helper called');
    check(StdFire.nativeWarn('Recovered'), 'warning after failure queued');
    check(recovered.wait(5), 'worker continues after helper throws');
    Sys.println('StdFire non-blocking desktop warnings passed');
  }
}
