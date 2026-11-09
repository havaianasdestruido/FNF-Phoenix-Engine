package states;

import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.LaunchState;
import backend.LaunchTarget;
import backend.Paths;
import backend.PlayerSettings;
import flixel.FlxState;

import backend.Achievements;
#if ACHIEVEMENTS_ALLOWED
import backend.PlaytimeTracker;
#end

/**
 * Handles initialization of variables when first opening the game.
**/
class InitState extends FlxState {
    override function create():Void {
        super.create();

        // -- FLIXEL STUFF -- //

        FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

        FlxTransitionableState.skipNextTransIn = true;

        // -- SETTINGS -- //

		FlxG.save.bind('funkin', CoolUtil.getSavePath());

		#if (flixel >= "5.0.0")
		trace('save status: ${FlxG.save.status}');
		#end

		FlxG.fixedTimestep = false;

		PlayerSettings.init();

        // ClientPrefs.loadDefaultKeys();
		ClientPrefs.loadPrefs();
		// Opt-in vlog (Options -> Misc): Main already restored it from the raw
		// save, this re-syncs with the value loadPrefs() just read in case the
		// early read could not open funkin.sol.
		backend.VLog.setEnabled(ClientPrefs.vlogEnabled);
		Conductor.recalculateTimings(); // #43: apply the saved safeFrames before any song starts

		#if ACHIEVEMENTS_ALLOWED
		FlxG.plugins.addIfUniqueType(new PlaytimeTracker());
		#end

        /*
        #if ACHIEVEMNTS_ALLOWED
        Achievements.init();
        #end
        */

        // -- MODS -- //

		#if MODS_ALLOWED
		if (!ClientPrefs.safeMode) Mods.pushGlobalMods();
		#end
		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		if (!ClientPrefs.safeMode) Mods.loadTopMod();

        // -- -- -- //

        Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

        // Default is the splash videos and then the title screen. The
        // `-DFREEPLAY` / `-DMENU` build flags (backend.LaunchState) skip both.
        switch (LaunchState.resolve(ClientPrefs.disableSplash))
        {
            case LaunchTarget.FREEPLAY:
                FlxG.switchState(FreeplayState.new);
            case LaunchTarget.MAIN_MENU:
                FlxG.switchState(MainMenuState.new);
            case LaunchTarget.TITLE:
                FlxG.switchState(TitleState.new);
            case LaunchTarget.SPLASH:
                FlxG.switchState(StartupState.new);
        }
    }
}
