import backend.UpdateChecker;

// This entry point is only typechecked, never run (it would issue an HTTP request).
class UpdateCheckerTypecheck
{
  static function main():Void
  {
    UpdateChecker.check(function(_) {});
  }
}
