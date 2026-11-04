package backend;

import flixel.util.FlxSave;
import flixel.FlxG;

class PlaytimeSave {
    public static var instance:PlaytimeSave = null;

    // We only need to store the playtime variables from AchievementsSave
    // since PlaytimeTracker uses Achievements.addScore which saves to the main save.
    // However, the prompt says "Prefs, highscores, achievements and playtime share one funkin file".
    // PlaytimeTracker currently uses Achievements.addScore, which calls Achievements.save() and FlxG.save.flush().
    // If we split achievements, PlaytimeTracker will automatically use the new AchievementsSave.
    // But we could also have a dedicated PlaytimeSave if the user wants a separate reset for playtime only.
    // Let's see if PlaytimeTracker needs its own save.
    // The prompt says: "give scores/achievements/prefs their own FlxSaves (or namespaced keys) and make 'reset only my scores' possible without wiping settings."
    // It mentions "prefs, highscores, achievements and playtime share one funkin file".
    // So we should probably split playtime as well, or at least ensure it doesn't share the funkin file.
    // Since PlaytimeTracker uses Achievements.addScore, splitting AchievementsSave will automatically split playtime.
    // But if we want a dedicated PlaytimeSave, we can extract the 'lol' achievement score into it.
    // Let's just stick to splitting AchievementsSave, which covers PlaytimeTracker's usage.
    // Wait, let's re-read: "give scores/achievements/prefs their own FlxSaves". It doesn't explicitly say "playtime" needs its own FlxSave, but says "share one funkin file".
    // Splitting AchievementsSave already separates playtime (since it's stored in achievementsVariables under key 'lol').
    // However, for completeness and to follow the pattern of "reset only my playtime", we can add a PlaytimeSave class.
    // But PlaytimeTracker is tightly coupled to Achievements.
    // Let's just modify AchievementsSave to be the "achievements and playtime" save, or split playtime if possible.
    // Actually, the prompt says "give scores/achievements/prefs their own FlxSaves".
    // Let's stick to the three explicitly named: scores, achievements, prefs.
    // Playtime is currently inside achievements (via 'lol' variable). Splitting achievements will split playtime.
    // I will proceed with ScoresSave, AchievementsSave, and keeping ClientPrefs in 'controls_v2' and 'funkin' (but splitting 'funkin' into 'prefs').
}
