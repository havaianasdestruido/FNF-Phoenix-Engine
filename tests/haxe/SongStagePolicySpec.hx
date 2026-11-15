import play.helpers.SongStagePolicy;

class SongStagePolicySpec
{
  static function equal(actual:String, expected:String, message:String):Void
  {
    if (actual != expected) throw message + ': expected ' + expected + ', got ' + actual;
  }

  static function main():Void
  {
    final experimental = SongStagePolicy.select('mod-pixel', 'stage', false, true);
    equal(experimental.chartStage, 'mod-pixel', 'chart stage survives HUD-only gameplay');
    equal(experimental.visualStage, '', 'experimental skips stage artwork/scripts');
    equal(experimental.metadataStage, 'mod-pixel', 'pixel/stage JSON remains available');

    final restart = SongStagePolicy.select(experimental.chartStage, 'stage', true, false);
    equal(restart.visualStage, 'mod-pixel', 'leaving the profile restores the same mod stage');
    equal(restart.metadataStage, 'mod-pixel', 'normal gameplay reads the stage JSON');

    final fallback = SongStagePolicy.select(null, 'school', false, true);
    equal(fallback.chartStage, 'school', 'missing stage uses the vanilla song mapping');
    equal(fallback.visualStage, '', 'missing stage does not accidentally enable the stage');
    equal(fallback.metadataStage, 'school', 'pixel fallback retains its metadata');

    final manual = SongStagePolicy.select('custom', 'stage', false, false);
    equal(manual.visualStage, '', 'the existing manual HUD-only preference still hides visuals');
    equal(manual.metadataStage, '', 'manual HUD-only keeps its prior metadata behavior');
    equal(manual.chartStage, 'custom', 'manual HUD-only no longer destroys the stored stage');
    trace('SongStagePolicySpec passed');
  }
}
