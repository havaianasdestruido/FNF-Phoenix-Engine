package lime.system;

class JNI
{
  public static var calls:Array<String> = [];
  public static var accept:Bool = true;

  static function decode(value:Array<Int>):String
  {
    var bytes = haxe.io.Bytes.alloc(value.length);
    for (index in 0...value.length) bytes.set(index, value[index]);
    return bytes.toString();
  }

  public static function createStaticMethod(className:String, method:String, signature:String):Dynamic
  {
    if (className != 'quack.fnf.phoenix.android.PhoenixCore')
      throw 'Unexpected JNI class $className';
    if (method == 'showMessageBoxUtf8' && signature == '([B[B)Z')
      return function(message:Array<Int>, title:Array<Int>):Bool
      {
        calls.push('$method:${decode(message)}|${decode(title)}');
        return accept;
      };
    if ((method != 'setAppTitleUtf8' && method != 'showToastUtf8') || signature != '([B)Z')
      throw 'Unexpected JNI binding $className.$method $signature';
    return function(value:Array<Int>):Bool
    {
      calls.push('$method:${decode(value)}');
      return accept;
    };
  }
}
