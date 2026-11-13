package backend;

import flixel.util.FlxSignal;

// import props.Player;
// import ui.DeviceManager;
class PlayerSettings
{
	static public var numPlayers(default, null) = 0;
	static public var numAvatars(default, null) = 0;
	static public var player1(default, null):PlayerSettings;
	static public var player2(default, null):PlayerSettings;

	#if (haxe >= "4.0.0")
	static public final onAvatarAdd = new FlxTypedSignal<PlayerSettings->Void>();
	static public final onAvatarRemove = new FlxTypedSignal<PlayerSettings->Void>();
	#else
	static public var onAvatarAdd = new FlxTypedSignal<PlayerSettings->Void>();
	static public var onAvatarRemove = new FlxTypedSignal<PlayerSettings->Void>();
	#end

	public var id(default, null):Int;

	#if (haxe >= "4.0.0")
	public final controls:Controls;
	#else
	public var controls:Controls;
	#end

	// public var avatar:Player;
	// public var camera(get, never):PlayCamera;

	function new(id, scheme)
	{
		this.id = id;
		this.controls = new Controls('player$id', scheme);
	}

	public function setKeyboardScheme(scheme)
	{
		controls.setKeyboardScheme(scheme);
	}

	/*
		static public function addAvatar(avatar:Player):PlayerSettings
		{
			var settings:PlayerSettings;

			if (player1 == null)
			{
				player1 = new PlayerSettings(0, Solo);
				++numPlayers;
			}

			if (player1.avatar == null)
				settings = player1;
			else
			{
				if (player2 == null)
				{
					if (player1.controls.keyboardScheme.match(Duo(true)))
						player2 = new PlayerSettings(1, Duo(false));
					else
						player2 = new PlayerSettings(1, None);
					++numPlayers;
				}

				if (player2.avatar == null)
					settings = player2;
				else
					throw throw 'Invalid number of players: ${numPlayers + 1}';
			}
			++numAvatars;
			settings.avatar = avatar;
			avatar.settings = settings;

			splitCameras();

			onAvatarAdd.dispatch(settings);

			return settings;
		}

		static public function removeAvatar(avatar:Player):Void
		{
			var settings:PlayerSettings;

			if (player1 != null && player1.avatar == avatar)
				settings = player1;
			else if (player2 != null && player2.avatar == avatar)
			{
				settings = player2;
				if (player1.controls.keyboardScheme.match(Duo(_)))
					player1.setKeyboardScheme(Solo);
			}
			else
				throw "Cannot remove avatar that is not for a player";

			settings.avatar = null;
			while (settings.controls.gamepadsAdded.length > 0)
			{
				final id = settings.controls.gamepadsAdded.shift();
				settings.controls.removeGamepad(id);
				DeviceManager.releaseGamepad(FlxG.gamepads.getByID(id));
			}

			--numAvatars;

			splitCameras();

			onAvatarRemove.dispatch(avatar.settings);
		}

	 */
	static public function init():Void
	{
		if (player1 == null)
		{
			player1 = new PlayerSettings(0, Solo);
			++numPlayers;
		}

		// Bind against ALL gamepads so TV remotes, Bluetooth pads, and
		// hotplugged controllers work even when none are active at boot.
		if (!player1.controls.gamepadsAdded.contains(flixel.input.actions.FlxActionInput.FlxInputDeviceID.ALL))
			player1.controls.addDefaultGamepad(flixel.input.actions.FlxActionInput.FlxInputDeviceID.ALL);

		// DeviceManager.init();
	}

	static public function reset()
	{
		player1 = null;
		player2 = null;
		numPlayers = 0;
	}
}
