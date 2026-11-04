package options;

import backend.ClientPrefs;
import backend.Controls;
import backend.Diagnostics;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import openfl.Lib;

import data.Song;
import objects.Note;

class MiscSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Misc';
		rpcTitle = 'Miscellaneous Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('Enable pre-release updates',
			'Include experimental pre-releases when checking for Phoenix updates.\nDisabled by default: only complete releases are shown.',
			'enablePreReleaseUpdates',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Use JS Engine Recharts', //Name
			'If checked, songs will have an optional "JSHard" difficulty (if available.)\nUse this difficulty for the JSE-specific recharts.', //Description
			'JSEngineRecharts', //Save data variable name
			'bool', //Variable type
			false); //Default value
		addOption(option);

		var option:Option = new Option('Always Play Cutscenes', //Name
			'If checked, cutscenes will always play even if you\nenter the song through Freeplay.', //Description
			'alwaysTriggerCutscene', //Save data variable name
			'bool', //Variable type
			false); //Default value
		addOption(option);

		var option:Option = new Option('Disable Splash Screen', //Name
			'If checked, the splash screen gets disabled on startup.', //Description
			'disableSplash', //Save data variable name
			'bool', //Variable type
			false); //Default value
		addOption(option);

		//credit to Nael2xd for the idea
		var option:Option = new Option('Rainbow Note Shift Speed', //Name
			'Changes the amount of time between 1 cycle for Rainbow Notes.\n(Make sure you have your note colors set to "Rainbow" to see this in action!)', //Description
			'rainbowTime', //Save data variable name
			'float', //Variable type
			5.0); //Default value
		option.scrollSpeed = 4;
		option.minValue = 0.01;
		option.maxValue = 100;
		option.changeValue = 0.01;
		option.decimals = 2; //lol
		option.displayFormat = '%vs';
		addOption(option);

		var option:Option = new Option('Autosave',
			'If checked, the Chart Editor will autosave.',
			'autosaveCharts',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Autosave Time: ',
			'Change the amount of time for a chart to autosave.', 
			'autosaveTime',
			'int',
			240);
		option.scrollSpeed = 30;
		option.minValue = 30;
		option.maxValue = 600;
		option.changeValue = 1;
		option.displayFormat = '%vs';
		addOption(option);

		var option:Option = new Option('Enable VLog', //Name
			'If checked, the engine keeps a very verbose session log at\n'
			+ 'vlog/log.txt (per-frame timings, lag spikes, memory, every trace).\n'
			+ 'Disabled by default; takes effect immediately and is kept on\n'
			+ 'the next launches until unchecked.', //Description
			'vlogEnabled', //Save data variable name
			'bool', //Variable type
			false); //Default value
		option.onChange = () -> backend.VLog.setEnabled(ClientPrefs.vlogEnabled);
		addOption(option);

		#if (windows && sys) // Only Windows registers at runtime; mobile gets the scheme from the build.
		var option:Option = new Option('Toggle Deeplink', //Name
			'If checked, this copy of the game registers the phoenix:// link\n'
			+ 'scheme, so links like phoenix://menu/misc can open the game.\n'
			+ 'Unchecking removes that registration again.\n'
			+ 'Nothing is ever written when the game launches.', //Description
			'deeplinkEnabled', //Save data variable name
			'bool', //Variable type
			false); //Default value
		option.onChange = backend.deeplink.DeepLinks.applyRegistration;
		addOption(option);
		#end

		// Support actions live last, next to the settings backup. One button:
		// build the redacted block, copy it, save a copy under crash/ and show
		// it. Nothing is uploaded anywhere (TODO §19: offline only).
		var option:Option = new Option('Copy Diagnostics',
			'Copies a redacted support block to the clipboard: engine version and\n'
			+ 'commit, target, CPU/RAM, GPU and driver, save path, mod list and\n'
			+ 'order, the options you changed and the last ~60 log lines.\n'
			+ 'A copy is also saved to crash/, and it is never uploaded anywhere.',
			'copyDiagnostics',
			'link',
			false);
		option.onChange = copyDiagnostics;
		addOption(option);

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];

		addBackupOptions();

		super();
	}

	/**
	 * "Copy Diagnostics": builds the block, puts it on the clipboard, writes a
	 * file copy under `crash/` and opens the read-only viewer.
	 *
	 * The message is shown by the viewer itself, so a canceled/failed copy has
	 * exactly one place to look. `Diagnostics.busy` keeps a held ACCEPT from
	 * generating two reports.
	 */
	function copyDiagnostics():Void
	{
		final message:String = Diagnostics.copyToClipboard();
		// A failed build leaves the previous report in `lastReport`; showing that
		// would be worse than showing nothing.
		final report:String = Diagnostics.lastError == null ? Diagnostics.lastReport : null;
		// The viewer shows the exact string that was copied (or prepared, when
		// the clipboard is unavailable), never a second build.
		openSubState(new states.substates.DiagnosticsSubstate(report, message));
	}
}
