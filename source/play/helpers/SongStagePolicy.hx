package play.helpers;

/** The saved chart stage, its visuals, and the metadata used by gameplay. */
typedef SongStageSelection =
{
  var chartStage:String;
  var visualStage:String;
  var metadataStage:String;
};

class SongStagePolicy
{
  /**
   * HUD-only experimental mode omits stage objects and scripts but preserves
   * the stage JSON (notably pixel UI/notes) and never overwrites the chart's
   * stage with an empty visual stage. `fallback` is the normal song mapping.
   */
  public static function select(chartStage:String, fallback:String, showStage:Bool, keepMetadata:Bool):SongStageSelection
  {
    final stage:String = chartStage != null && chartStage.length > 0 ? chartStage : fallback;
    final visual:String = showStage ? stage : '';
    return {
      chartStage: stage,
      visualStage: visual,
      metadataStage: !showStage && keepMetadata ? stage : visual
    };
  }
}
