package states;

import backend.CoolUtil;
import play.PlayState;

/** Immutable-ish snapshot of a completed song or story campaign. */
class ResultsData
{
  public var title:String;
  public var difficulty:String;
  public var score:Float = 0;
  public var accuracy:Float = 0;
  public var totalPlayed:Int = 0;
  public var perfects:Int = 0;
  public var sicks:Int = 0;
  public var goods:Int = 0;
  public var bads:Int = 0;
  public var poors:Int = 0;
  public var misses:Float = 0;
  public var maxCombo:Float = 0;
  public var peakNPS:Float = 0;
  public var fcTier:String = 'No Play';
  public var fcStrings:Array<String> = [];
  public var hitOffsets:Array<Float> = [];

  public function new(title:String, difficulty:String)
  {
    this.title = title;
    this.difficulty = difficulty;
  }

  public static function fromPlayState(state:PlayState, title:String):ResultsData
  {
    final result = new ResultsData(title, CoolUtil.difficulties[PlayState.storyDifficulty]);
    result.score = state.songScore;
    result.accuracy = state.totalPlayed > 0 ? Math.max(0, Math.min(100, state.totalNotesHit / state.totalPlayed * 100)) : 0;
    result.totalPlayed = state.totalPlayed;
    result.perfects = state.perfects;
    result.sicks = state.sicks;
    result.goods = state.goods;
    result.bads = state.bads;
    result.poors = state.poorRatings;
    result.misses = state.songMisses;
    result.maxCombo = state.maxCombo;
    result.peakNPS = state.maxNPS;
    result.fcStrings = state.fcStrings.copy();
    result.fcTier = state.ratingFC == null || state.ratingFC.length == 0 ? 'No Play' : state.ratingFC;
    result.hitOffsets = state.hitOffsets.copy();
    return result;
  }

  /** Adds a completed song to this week-level snapshot. */
  public function addSong(song:ResultsData):Void
  {
    score += song.score;
    final combinedPlayed:Int = totalPlayed + song.totalPlayed;
    if (combinedPlayed > 0)
      accuracy = (accuracy * totalPlayed + song.accuracy * song.totalPlayed) / combinedPlayed;
    totalPlayed = combinedPlayed;
    perfects += song.perfects;
    sicks += song.sicks;
    goods += song.goods;
    bads += song.bads;
    poors += song.poors;
    misses += song.misses;
    maxCombo = Math.max(maxCombo, song.maxCombo);
    peakNPS = Math.max(peakNPS, song.peakNPS);
    if (song.fcStrings.length > 0) fcStrings = song.fcStrings.copy();
    for (offset in song.hitOffsets) hitOffsets.push(offset);
    fcTier = tierFromTotals();
  }

  function tierFromTotals():String
  {
    final tiers = fcStrings.length >= 10 ? fcStrings : ['No Play', 'PFC', 'SFC', 'GFC', 'BFC', 'FC', 'SDCB', 'Clear', 'TDCB', 'QDCB'];
    if (totalPlayed == 0) return tiers[0];
    if (misses >= 1000) return tiers[9];
    if (misses >= 100) return tiers[8];
    if (misses >= 10) return tiers[7];
    if (misses > 0) return tiers[6];
    if (poors > 0) return tiers[5];
    if (bads > 0) return tiers[4];
    if (goods > 0) return tiers[3];
    if (sicks > 0) return tiers[2];
    if (perfects > 0) return tiers[1];
    return tiers[0];
  }
}
