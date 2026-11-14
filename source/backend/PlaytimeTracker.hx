package backend;

import flixel.FlxBasic;
import flixel.FlxG;
#if !flash
import lime.app.Application;
#end

/**
 * Tracks cumulative time spent with the game running, feeding `PlayerStats`
 * continuously (even after the 50-hour playtime badge unlocks).
 */
class PlaytimeTracker extends FlxBasic
{
	static inline var ACHIEVEMENT_ID:String = PlayerStats.PLAYTIME_ACHIEVEMENT_ID;
	static inline var TARGET_HOURS:Float = PlayerStats.PLAYTIME_ACHIEVEMENT_HOURS;
	static inline var SAVE_INTERVAL_SECONDS:Float = 60;

	private var pendingSaveSeconds:Float = 0;
	#if ACHIEVEMENTS_ALLOWED
	private var pendingAchievementSeconds:Float = 0;
	#end

	public function new()
	{
		super();

		#if !flash
		if (Application.current != null && Application.current.onExit != null)
			Application.current.onExit.add(onApplicationExit);
		#end
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (elapsed <= 0 || Math.isNaN(elapsed) || !Math.isFinite(elapsed))
			return;

		PlayerStats.addPlaytime(elapsed, false);
		pendingSaveSeconds += elapsed;

		var reachedBadge:Bool = false;
		#if ACHIEVEMENTS_ALLOWED
		if (!Achievements.isUnlocked(ACHIEVEMENT_ID))
		{
			pendingAchievementSeconds += elapsed;
			if (Achievements.exists(ACHIEVEMENT_ID)
				&& Achievements.getScore(ACHIEVEMENT_ID) + pendingAchievementSeconds / 3600 >= TARGET_HOURS)
				reachedBadge = true;
		}
		else
		{
			pendingAchievementSeconds = 0;
		}
		#end

		// Persist at least once a minute, and immediately when the 50-hour badge threshold is reached.
		if (reachedBadge || pendingSaveSeconds >= SAVE_INTERVAL_SECONDS)
			savePendingTime();
	}

	override public function destroy():Void
	{
		savePendingTime();
		#if !flash
		if (Application.current != null && Application.current.onExit != null)
			Application.current.onExit.remove(onApplicationExit);
		#end
		super.destroy();
	}

	private function onApplicationExit(_:Int):Void
	{
		savePendingTime();
	}

	private function savePendingTime():Void
	{
		if (pendingSaveSeconds <= 0 #if ACHIEVEMENTS_ALLOWED && pendingAchievementSeconds <= 0 #end)
			return;

		pendingSaveSeconds = 0;
		PlayerStats.save(false);

		var flushedByUnlock:Bool = false;
		#if ACHIEVEMENTS_ALLOWED
		if (pendingAchievementSeconds > 0)
		{
			final elapsedHours:Float = pendingAchievementSeconds / 3600;
			pendingAchievementSeconds = 0;
			if (Achievements.exists(ACHIEVEMENT_ID) && !Achievements.isUnlocked(ACHIEVEMENT_ID))
			{
				Achievements.addScore(ACHIEVEMENT_ID, elapsedHours, false);
				flushedByUnlock = Achievements.isUnlocked(ACHIEVEMENT_ID);
			}
		}
		#end

		// Achievements.addScore flushes automatically when it unlocks the achievement.
		if (!flushedByUnlock && FlxG.save != null)
			FlxG.save.flush();
	}
}
