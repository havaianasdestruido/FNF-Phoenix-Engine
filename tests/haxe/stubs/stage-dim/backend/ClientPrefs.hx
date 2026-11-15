package backend;

/**
 * Only the fields the stage-dim helper and its spec read. Defaults mirror
 * `source/backend/ClientPrefs.hx`; the spec flips them to prove the overlay
 * reacts to the preference.
 */
class ClientPrefs
{
  public static var stageDim:Float = 0;
}
