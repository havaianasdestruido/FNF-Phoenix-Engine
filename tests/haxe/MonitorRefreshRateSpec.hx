import backend.MonitorRefreshRate;
import lime.app.Application;

class MonitorRefreshRateSpec
{
  static function assertEquals(expected:Int, actual:Int, label:String):Void
  {
    if (expected != actual) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    // The native (X server) reading wins; Lime is the fallback; 60 is the floor.
    assertEquals(144, MonitorRefreshRate.pick(144, 60), 'native reading wins');
    assertEquals(75, MonitorRefreshRate.pick(0, 75), 'Lime reading when native is unknown');
    assertEquals(75, MonitorRefreshRate.pick(-1, 75), 'negative native reading is unknown');
    assertEquals(60, MonitorRefreshRate.pick(0, 0), 'fallback when nothing is known');
    assertEquals(60, MonitorRefreshRate.pick(-5, -1), 'fallback for invalid readings');
    assertEquals(60, MonitorRefreshRate.FALLBACK, 'fallback constant');

    #if !cpp
    // Only desktop Linux C++ builds have the native query.
    assertEquals(0, MonitorRefreshRate.queryNative(), 'no native query on this target');

    // Lime may have no application, window or display mode yet: never crash.
    Application.current = null;
    assertEquals(0, MonitorRefreshRate.queryLime(), 'no application');
    assertEquals(60, MonitorRefreshRate.get(), 'fallback without an application');
    Application.current = new Application();
    assertEquals(0, MonitorRefreshRate.queryLime(), 'no window');
    Application.current.window = new Window();
    assertEquals(0, MonitorRefreshRate.queryLime(), 'no display mode');
    Application.current.window.displayMode = new DisplayMode(165);
    assertEquals(165, MonitorRefreshRate.queryLime(), 'Lime display mode');
    assertEquals(165, MonitorRefreshRate.get(), 'Lime display mode is used');
    Application.current.window.displayMode = new DisplayMode(0);
    assertEquals(60, MonitorRefreshRate.get(), 'Lime reporting zero falls back');
    #end

    Sys.println('MonitorRefreshRate spec passed');
  }
}
