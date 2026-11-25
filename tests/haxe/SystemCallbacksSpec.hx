import debug.system.SystemInfo;
import psychlua.FunkinLua;
import psychlua.PythonScript;
import psychlua.callbacks.SystemCallbacks;
import psychlua.pystdlib.PySystemLib;

/**
 * Verifies Lua, Python, and HScript bindings for `debug.system.SystemInfo`
 * (`source/debug/system/src/phoenix_system.cpp`).
 */
class SystemCallbacksSpec
{
  static final EXPECTED_NAMES:Array<String> = [
    'getMonotonicSeconds',
    'getProcessCPUSeconds',
    'getLogicalCPUCount',
    'getPageSize',
    'getTotalPhysicalMemory'
  ];

  static function check(cond:Bool, label:String):Void
  {
    if (!cond) throw 'Assertion failed: $label';
  }

  static function call(fn:Dynamic):Dynamic
  {
    return Reflect.callMethod(null, fn, []);
  }

  static function main():Void
  {
    final lua = new FunkinLua();
    final py = new PythonScript();
    SystemCallbacks.register(lua);
    PySystemLib.register(py);

    for (name in EXPECTED_NAMES)
    {
      check(FunkinLua.registeredFunctions.exists(name), 'Lua registered $name');
      check(PythonScript.registeredFunctions.exists(name), 'Python registered $name');
      check(Reflect.isFunction(FunkinLua.registeredFunctions.get(name)), 'Lua $name is callable');
      check(Reflect.isFunction(PythonScript.registeredFunctions.get(name)), 'Python $name is callable');
    }

    final interp = {variables: new Map<String, Dynamic>()};
    SystemCallbacks.seedHScript(interp);
    for (name in EXPECTED_NAMES)
    {
      check(interp.variables.exists(name), 'HScript seeded $name');
      check(Reflect.isFunction(interp.variables.get(name)), 'HScript $name is callable');
    }
    check(interp.variables.exists('SystemInfo'), 'HScript seeded SystemInfo namespace');
    final ns:Dynamic = interp.variables.get('SystemInfo');
    for (field in ['monotonicSeconds', 'processCPUSeconds', 'logicalCPUCount', 'pageSize', 'totalPhysicalMemory'])
    {
      check(Reflect.isFunction(Reflect.field(ns, field)), 'SystemInfo.$field is callable');
    }

    // Verify all three host bindings match SystemInfo's contract.
    for (source in [
      {label: 'Lua', map: FunkinLua.registeredFunctions},
      {label: 'Python', map: PythonScript.registeredFunctions},
      {label: 'HScript', map: interp.variables}
    ])
    {
      final t0:Float = call(source.map.get('getMonotonicSeconds'));
      final t1:Float = call(source.map.get('getMonotonicSeconds'));
      check(t0 >= 0 && t1 >= t0, '${source.label} monotonicSeconds nondecreasing');
      final cpu:Float = call(source.map.get('getProcessCPUSeconds'));
      check(cpu >= 0, '${source.label} processCPUSeconds >= 0');
      final cpus:Int = call(source.map.get('getLogicalCPUCount'));
      check(cpus >= 1, '${source.label} logicalCPUCount >= 1');
      final pg:Float = call(source.map.get('getPageSize'));
      check(pg >= 0, '${source.label} pageSize >= 0');
      final ram:Float = call(source.map.get('getTotalPhysicalMemory'));
      check(ram >= 0, '${source.label} totalPhysicalMemory >= 0');
    }

    final nsT0:Float = Reflect.callMethod(ns, Reflect.field(ns, 'monotonicSeconds'), []);
    final nsT1:Float = Reflect.callMethod(ns, Reflect.field(ns, 'monotonicSeconds'), []);
    check(nsT0 >= 0 && nsT1 >= nsT0, 'SystemInfo.monotonicSeconds nondecreasing');
    check((Reflect.callMethod(ns, Reflect.field(ns, 'processCPUSeconds'), []) : Float) >= 0, 'SystemInfo.processCPUSeconds >= 0');
    check((Reflect.callMethod(ns, Reflect.field(ns, 'logicalCPUCount'), []) : Int) >= 1, 'SystemInfo.logicalCPUCount >= 1');
    check((Reflect.callMethod(ns, Reflect.field(ns, 'pageSize'), []) : Float) >= 0, 'SystemInfo.pageSize >= 0');
    check((Reflect.callMethod(ns, Reflect.field(ns, 'totalPhysicalMemory'), []) : Float) >= 0, 'SystemInfo.totalPhysicalMemory >= 0');

    // Non-cpp fallback invariants when running on --interp.
    #if !cpp
    check(SystemCallbacks.processCPUSeconds() == 0, 'non-cpp processCPUSeconds == 0');
    check(SystemCallbacks.logicalCPUCount() == 1, 'non-cpp logicalCPUCount == 1');
    check(SystemCallbacks.pageSize() == 0, 'non-cpp pageSize == 0');
    check(SystemCallbacks.totalPhysicalMemory() == 0, 'non-cpp totalPhysicalMemory == 0');
    check(SystemInfo.monotonicSeconds() >= 0, 'non-cpp SystemInfo.monotonicSeconds >= 0');
    #end

    trace('SystemCallbacksSpec: ok');
  }
}
