package states;

import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.FramerateController;
import backend.LaunchState;
import backend.LaunchTarget;
import backend.Paths;
import backend.PlayerSettings;
import backend.PlayerStats;
import backend.PlaytimeTracker;
import flixel.FlxState;

import backend.Achievements;

/**
 * Handles initialization of variables when first opening the game.
**/
class InitState extends FlxState {
    override function create():Void {
        super.create();

        // -- FLIXEL STUFF -- //

        // The focus-lost (background) rate comes from Options -> Graphics
        // (`ClientPrefs.focusLostFramerate`); it is applied after the save
        // file is read, below. Nothing is hard-coded here anymore.
		FlxG.sound.muteKeys = TitleState.muteKeys;
		FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];
		#if android
		FlxG.android.preventDefaultKeys = [flixel.input.android.FlxAndroidKey.BACK];
		backend.TouchlessUI.init();
		#end

        FlxTransitionableState.skipNextTransIn = true;

        // -- SETTINGS -- //

		FlxG.save.bind('funkin', CoolUtil.getSavePath());

		#if (flixel >= "5.0.0")
		trace('save status: ${FlxG.save.status}');
		#end

		FlxG.fixedTimestep = false;

		PlayerSettings.init();

        // ClientPrefs.loadDefaultKeys();
		if (!backend.RecoveryBoot.freshPrefs) ClientPrefs.loadPrefs();
		else
		{
			ClientPrefs.applyGamepadDeadzone();
			#if android
			if (backend.TouchlessUI.isHardwareTouchless())
				ClientPrefs.androidTVNavigation = true;
			#end
			#if ACHIEVEMENTS_ALLOWED
			Achievements.load(); // Preserve achievements even when preferences are bypassed.
			#end
		}
		// Both paths end up here: apply the saved background rate (defaults to
		// the historical 60) and the menu rate for every screen that follows.
		// `InitState` is not a MusicBeatState, so it would not get the latter
		// from create().
		FramerateController.applyFocusLost(ClientPrefs.focusLostFramerate);
		FramerateController.apply(ClientPrefs.menuFramerate);
		PlayerStats.load();
		// Opt-in vlog (Options -> Misc): Main already restored it from the raw
		// save, this re-syncs with the value loadPrefs() just read in case the
		// early read could not open funkin.sol.
		backend.VLog.setEnabled(ClientPrefs.vlogEnabled);
		backend.LuaDiagnosticsSetup.sync();
		// Memory profiles release cached assets when the window is backgrounded.
		// The handler checks the active profile, so registering it is harmless
		// when no profile is selected.
		FlxG.signals.focusLost.add(backend.LowMemory.onFocusLost);
		Conductor.recalculateTimings(); // #43: apply the saved safeFrames before any song starts

		FlxG.plugins.addIfUniqueType(new PlaytimeTracker());

        /*
        #if ACHIEVEMNTS_ALLOWED
        Achievements.init();
        #end
        */

        // -- MODS -- //

		#if MODS_ALLOWED
		if (!ClientPrefs.safeMode && !backend.RecoveryBoot.disableMods) Mods.pushGlobalMods();
		#end
		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		if (!ClientPrefs.safeMode && !backend.RecoveryBoot.disableMods) Mods.loadTopMod();

        // -- -- -- //

        Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

        // Default is the splash videos and then the title screen. The
        // `-DFREEPLAY` / `-DMENU` build flags (backend.LaunchState) skip both.
        // Every target goes through the loading screen: it is what sets
        // `Paths.currentLevel` (the per-week asset folder) before the state
        // builds its artwork. The `-DFREEPLAY` / `-DMENU` shortcuts used to
        // switch directly, which left the level unset and made every image
        // lookup miss (a black menu/song) on a fresh boot.
        switch (LaunchState.resolve(ClientPrefs.disableSplash))
        {
            case LaunchTarget.FREEPLAY:
                LoadingState.loadAndSwitchState(FreeplayState.new);
            case LaunchTarget.MAIN_MENU:
                LoadingState.loadAndSwitchState(MainMenuState.new);
            case LaunchTarget.TITLE:
                // Boot loading screen: executable open -> title screen.
                LoadingState.loadAndSwitchState(TitleState.new);
            case LaunchTarget.SPLASH:
                FlxG.switchState(StartupState.new);
        }
    }
}
