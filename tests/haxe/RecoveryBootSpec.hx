import backend.RecoveryBoot;
class RecoveryBootSpec {
  static function check(value:Bool, message:String):Void if (!value) throw message;
  static function main():Void {
    RecoveryBoot.begin();
    check(RecoveryBoot.failures == 0, 'first start');
    RecoveryBoot.begin();
    check(RecoveryBoot.failures == 1, 'first unclean start');
    RecoveryBoot.begin();
    check(RecoveryBoot.failures == RecoveryBoot.THRESHOLD, 'repeated unclean starts');
    check(!sys.FileSystem.exists(RecoveryBoot.disabledModsPath() + 'scripts/test.lua'), 'disabled path cannot expose mods');
    RecoveryBoot.markCrash();
    RecoveryBoot.finish(0);
    RecoveryBoot.begin();
    check(RecoveryBoot.failures == 3, 'handled crash is not clean');
    RecoveryBoot.finish(1);
    RecoveryBoot.begin();
    check(RecoveryBoot.failures == 4, 'nonzero exit is not clean');
    RecoveryBoot.finish(0);
    RecoveryBoot.begin();
    check(RecoveryBoot.failures == 0, 'clean exit resets count');
    RecoveryBoot.finish(0);
    trace('RecoveryBootSpec passed');
  }
}
