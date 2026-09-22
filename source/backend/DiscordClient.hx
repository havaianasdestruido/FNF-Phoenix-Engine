package backend;

#if DISCORD_ALLOWED
#if cpp
import cpp.ConstCharStar;
import cpp.Function;
import cpp.RawConstPointer;
#end
#if LUA_ALLOWED
import psychlua.FunkinLua.State;
#end

import states.MainMenuState;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
import lime.app.Application;
import sys.thread.Thread;
#end

class DiscordClient
{
	public static var isInitialized:Bool = false;
	private inline static final _defaultID:String = "1192736165472784445";
	public static var clientID(default, set):String = _defaultID;

	#if DISCORD_ALLOWED
	private static var presence:DiscordRichPresence = new DiscordRichPresence(); // I think for now we don't need DiscordPresence.create();
	// hides this field from scripts and reflection in general
	@:unreflective private static var __thread:Thread;

	/**
	 * Executes the `check` operation.
	 * @return Result produced by `check`, when applicable.
	 */
	public static function check()
	{
		if(ClientPrefs.discordRPC) initialize();
		else if(isInitialized) shutdown();
	}

	/**
	 * Executes the `prepare` operation.
	 * @return Result produced by `prepare`, when applicable.
	 */
	public static function prepare()
	{
		if (!isInitialized && ClientPrefs.discordRPC)
			initialize();

		Application.current.window.onClose.add(function() {
			if(isInitialized) shutdown();
		});
	}

	/**
	 * Executes the `shutdown` operation.
	 * @return Result produced by `shutdown`, when applicable.
	 */
	public dynamic static function shutdown()
	{
		isInitialized = false;
		Discord.Shutdown();
	}

	/**
	 * Executes the `onReady` operation.
	 * @param request Input value for `request`.
	 */
	private static function onReady(request:RawConstPointer<DiscordUser>):Void
	{
		final user = cast (request[0].username, String);
		final discriminator = cast (request[0].discriminator, String);

		var message = '(Discord) Connected to User ';
		if (discriminator != '0') //Old discriminators
			message += '($user#$discriminator)';
		else //New Discord IDs/Discriminator system
			message += '($user)';

		trace(message);
		changePresence();
	}

	/**
	 * Executes the `onError` operation.
	 * @param errorCode Input value for `errorCode`.
	 * @param message Input value for `message`.
	 */
	private static function onError(errorCode:Int, message:ConstCharStar):Void
	{
		trace('Discord: Error ($errorCode: ${cast(message, String)})');
	}

	/**
	 * Executes the `onDisconnected` operation.
	 * @param errorCode Input value for `errorCode`.
	 * @param message Input value for `message`.
	 */
	private static function onDisconnected(errorCode:Int, message:ConstCharStar):Void
	{
		trace('Discord: Disconnected ($errorCode: ${cast(message, String)})');
	}

	/**
	 * Executes the `initialize` operation.
	 * @return Result produced by `initialize`, when applicable.
	 */
	public static function initialize()
	{
		final discordHandlers:DiscordEventHandlers = #if (hxdiscord_rpc > "1.2.4") new DiscordEventHandlers(); #else DiscordEventHandlers.create(); #end
		discordHandlers.ready = Function.fromStaticFunction(onReady);
		discordHandlers.disconnected = Function.fromStaticFunction(onDisconnected);
		discordHandlers.errored = Function.fromStaticFunction(onError);
		Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), #if (hxdiscord_rpc > "1.2.4") false #else 1 #end, null);

		if(!isInitialized) trace("Discord Client initialized");

		if (__thread == null)
		{
			__thread = Thread.create(() ->
			{
				while (true)
				{
					if (isInitialized)
					{
						#if DISCORD_DISABLE_IO_THREAD
						Discord.UpdateConnection();
						#end
						Discord.RunCallbacks();
					}

					// Wait 1 second until the next loop...
					Sys.sleep(1.0);
				}
			});
		}
		isInitialized = true;
	}

	/**
	 * Executes the `changePresence` operation.
	 * @param details Input value for `details`.
	 * @param state Input value for `state`.
	 * @param smallImageKey Input value for `smallImageKey`.
	 * @param hasStartTimestamp Input value for `hasStartTimestamp`.
	 * @param endTimestamp Input value for `endTimestamp`.
	 * @param largeImageKey Input value for `largeImageKey`.
	 * @return Result produced by `changePresence`, when applicable.
	 */
	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, largeImageKey:String = 'icon')
	{
		var startTimestamp:Float = 0;
		if (hasStartTimestamp) startTimestamp = Date.now().getTime();
		if (endTimestamp > 0) endTimestamp = startTimestamp + endTimestamp;

		presence.state = state;
		presence.details = details;
		presence.smallImageKey = smallImageKey;
		presence.largeImageKey = largeImageKey;
		presence.largeImageText = "Engine Version: " + MainMenuState.psychEngineJSVersion;
		// Obtained times are in milliseconds so they are divided so Discord can use it
		presence.startTimestamp = Std.int(startTimestamp / 1000);
		presence.endTimestamp = Std.int(endTimestamp / 1000);

		final button:DiscordButton = new DiscordButton();
		button.label = "Engine Source Code";
		button.url = "https://github.com/JordanSantiagoYT/FNF-JS-Engine";
		presence.buttons[0] = button;
		updatePresence();
	}

	/**
	 * Executes the `updatePresence` operation.
	 * @return Result produced by `updatePresence`, when applicable.
	 */
	public static function updatePresence()
	{
		Discord.UpdatePresence(RawConstPointer.addressOf(presence));
	}

	#if LUA_ALLOWED
	/**
	 * Executes the `addLuaCallbacks` operation.
	 * @param lua Input value for `lua`.
	 * @return Result produced by `addLuaCallbacks`, when applicable.
	 */
	public static function addLuaCallbacks(lua:State)
	{
		Convert.addCallback(lua, "changeDiscordPresence", changePresence);
		Convert.addCallback(lua, "changeDiscordClientID", function(?newID:String) {
			if(newID == null) newID = _defaultID;
			clientID = newID;
		});
	}
	#end
	#else
	// No-op stub for builds compiled without Discord RPC (e.g. Neko).
	/**
	 * Executes the `check` operation.
	 */
	public static function check():Void {}
	/**
	 * Executes the `prepare` operation.
	 */
	public static function prepare():Void {}
	/**
	 * Executes the `shutdown` operation.
	 */
	public dynamic static function shutdown():Void { isInitialized = false; }
	/**
	 * Executes the `initialize` operation.
	 */
	public static function initialize():Void { isInitialized = false; }
	/**
	 * Executes the `changePresence` operation.
	 * @param details Input value for `details`.
	 * @param state Input value for `state`.
	 * @param smallImageKey Input value for `smallImageKey`.
	 * @param hasStartTimestamp Input value for `hasStartTimestamp`.
	 * @param endTimestamp Input value for `endTimestamp`.
	 * @param largeImageKey Input value for `largeImageKey`.
	 */
	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, largeImageKey:String = 'icon'):Void {}
	/**
	 * Executes the `updatePresence` operation.
	 */
	public static function updatePresence():Void {}
	#end

	/**
	 * Executes the `resetClientID` operation.
	 * @return Result produced by `resetClientID`, when applicable.
	 */
	inline public static function resetClientID()
	{
		clientID = _defaultID;
	}

	/**
	 * Executes the `set_clientID` operation.
	 * @param newID Input value for `newID`.
	 * @return Result produced by `set_clientID`, when applicable.
	 */
	private static function set_clientID(newID:String)
	{
		var change:Bool = (clientID != newID);
		clientID = newID;

		if(change && isInitialized)
		{
			shutdown();
			initialize();
			updatePresence();
		}
		return newID;
	}
}