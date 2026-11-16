package ios.platform;

#if (ios && cpp)
@:buildXml('<include name="../../../../source/ios/platform/stdfire/build.xml" />')
@:cppFileCode('#include "phoenix_stdfire_ios.h"')
#end
/** UIKit bridge for stdfire; requests are dispatched to the main queue. */
class IOSStdFire
{
  /** Queue a scene/controller title update, not an installed app rename. */
  #if (ios && cpp)
  @:functionCode('return phoenixStdFireSetTitle(title.c_str());')
  #end
  public static function setTitle(title:String):Bool
  {
    return false;
  }

  /** Queue a brief, non-modal UIKit banner. */
  #if (ios && cpp)
  @:functionCode('return phoenixStdFireShowToast(message.c_str());')
  #end
  public static function showToast(message:String):Bool
  {
    return false;
  }
}
