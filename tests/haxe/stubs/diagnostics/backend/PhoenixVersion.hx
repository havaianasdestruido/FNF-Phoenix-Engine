package backend;

class PhoenixVersion
{
  public static var current:String = '0.0.1';

  public static function display(raw:String):String
    return (raw != null && raw.length > 0 && raw.charAt(0) == 'v') ? raw : 'v${raw}';
}
