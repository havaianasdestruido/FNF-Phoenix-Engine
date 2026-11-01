// Example overlay / replacement state script.
// Save as mods/YourMod/data/states/FreeplayState.hx to hook the existing menu,
// or as mods/YourMod/data/states/MyMenu.hx and call switchCustomState("MyMenu").
//
// Available identifiers: state/game (the MusicBeatState), FlxG, FlxSprite, FlxText,
// FlxTween, Paths, ClientPrefs, Conductor, Function_Stop, Function_Continue,
// switchCustomState, openCustomSubstate, openModSubState, addHaxeLibrary, debugPrint.

function onCreate()
{
	debugPrint("state script loaded: " + state);
}

function onCreatePost()
{
	// Menu widgets exist here — MainMenu/Freeplay call super.create() after building UI.
}

function onUpdate(elapsed:Float)
{
}

function onBeatHit(curBeat:Int)
{
}

function onDestroy()
{
}
