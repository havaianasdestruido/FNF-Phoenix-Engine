import utils.PlatformUtilNative;

@:access(utils.PlatformUtilNative)
class PlatformUtilNativeSpec
{
  static function main():Void
  {
    #if !windows
    if (PlatformUtilNative.sendFakeMsgBoxNative('test', 42) != 42)
      throw 'Unsupported/native stub must preserve the result';
    #else
    if (PlatformUtilNative.sendFakeMsgBoxNative('test', 42) != 7)
      throw 'Windows dialog should use the WindowNative bridge';
    #end
    Sys.println('PlatformUtilNative typecheck passed');
  }
}
