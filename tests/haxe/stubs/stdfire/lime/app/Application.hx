package lime.app;

class Application
{
  public static var current:Application;
  public var window:TestWindow;

  public function new()
  {
    window = new TestWindow();
  }
}

class TestWindow
{
  public var title(default, set):String = "Original";
  public var alertMessage:String = null;
  public var alertTitle:String = null;

  public function new() {}

  function set_title(value:String):String
  {
    #if html5
    js.Browser.document.title = value;
    #end
    return title = value;
  }

  public function alert(message:String, title:String):Void
  {
    alertMessage = message;
    alertTitle = title;
  }
}
