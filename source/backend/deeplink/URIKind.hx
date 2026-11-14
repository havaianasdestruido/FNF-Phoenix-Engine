package backend.deeplink;

/**
 * Structured URI kinds for `PhoenixURI.parseEx`.
 * Kept in its own module so both `PhoenixURI` and `DeepLinks`
 * can import it without relying on multi-type-per-file quirks.
 */
enum URIKind
{
	Menu(route:String);
	Screen(route:String);
	Song(name:String, difficulty:Null<String>);
	Mod(modId:String, song:Null<String>);
	Diagnostics;
	InputTest;
	Replay(id:String);
}
