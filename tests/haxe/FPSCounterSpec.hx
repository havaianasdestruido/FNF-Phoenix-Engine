import backend.ClientPrefs;
import debug.FPSCounter;

class FPSCounterSpec
{
  static function check(value:Bool, message:String):Void
  {
    if (!value) throw message;
  }

  static function main():Void
  {
    var counter = new FPSCounter();
    ClientPrefs.showRamUsage = true;
    ClientPrefs.showMaxRamUsage = true;
    ClientPrefs.debugInfo = true;
    ClientPrefs.frameProfiler = true;
    ClientPrefs.ffmpegMode = true;
    ClientPrefs.legacyFPSUI = false;
    counter.updateText();
    check(counter.text == 'FPS: 60\nRAM: 123 B', 'compact view must hide saved legacy details: ' + counter.text);

    ClientPrefs.legacyFPSUI = true;
    counter.updateText();
    check(counter.text.indexOf('FPS: 60 (Rendering Mode)\nMemory: 123 B / 456 B') == 0, 'legacy header and peak RAM');
    check(counter.text.indexOf('\nProfiler') != -1, 'legacy profiler');
    check(counter.text.indexOf('\nPools: pool stats') != -1, 'legacy pool stats');
    check(counter.text.indexOf('\nCurrent state:') != -1, 'legacy debug info');

    ClientPrefs.showMaxRamUsage = false;
    counter.updateText();
    check(counter.text.indexOf('Memory: 123 B /') == -1, 'legacy respects peak RAM setting');
    ClientPrefs.legacyFPSUI = false;
    counter.updateText();
    check(counter.text == 'FPS: 60\nRAM: 123 B', 'switching back immediately restores compact view');
    check(ClientPrefs.debugInfo && ClientPrefs.frameProfiler, 'switching views preserves debug settings');

    ClientPrefs.legacyFPSUI = true;
    ClientPrefs.showRamUsage = false;
    ClientPrefs.frameProfiler = false;
    ClientPrefs.debugInfo = false;
    counter.updateText();
    check(counter.text == 'FPS: 60 (Rendering Mode)', 'legacy respects visibility settings');
    ClientPrefs.legacyFPSUI = false;
    counter.updateText();
    check(counter.text == 'FPS: 60', 'compact respects RAM visibility');
    trace('FPS overlay compact and legacy modes OK');
  }
}
