package options;

import options.helpers.OptionsMenuHelpers;

/**
 * Options -> Audio.
 *
 * The category exists for one loudness control: **Master Volume**, the single
 * multiplier every `FlxSound` uses (instrumental, vocals, hitsounds and the
 * pause track all go through `FlxG.sound.volume`). Until now the only way to
 * change it was the `volume_up` / `volume_down` / `volume_mute` keys and the
 * `objects.CustomSoundTray` popup they show, so a player on a gamepad, a remote
 * or a touchscreen could not set it at all.
 *
 * The row is a **mirror**, never a second copy of the value:
 *
 * - the real value is `FlxG.sound.volume` and is already saved and restored by
 *   `ClientPrefs` (`flixelSound`) and exported in the `audio` section of a
 *   settings backup; `ClientPrefs.masterVolume` is kept out of both;
 * - the slider position follows the tray's logarithmic curve
 *   (`backend.VolumeCurve`), so the same number means the same loudness in the
 *   row and under the `+`/`-` keys — half the tray is about `0.03`, not `0.5`;
 * - `Option.live` + `Option.readValue` make the row read `FlxG.sound.volume`
 *   every frame (see `BaseOptionsMenu.refreshLiveOptions()`), so pressing a
 *   volume key, using the tray or a mod script changing the volume updates the
 *   label instead of leaving a stale number behind.
 */
class AudioSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Audio';
		rpcTitle = 'Audio Settings Menu'; //for Discord Rich Presence

		OptionsMenuHelpers.addMasterVolumeRow(this);

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];

		addBackupOptions();

		super();
	}
}
