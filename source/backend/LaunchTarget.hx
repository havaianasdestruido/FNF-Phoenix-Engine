package backend;

/**
 * The screen a build boots into.
 *
 * Flixel/OpenFL-free on purpose so the decision can be unit tested without the
 * game haxelibs (see `tests/haxe/LaunchStateSpec.hx`).
 */
enum LaunchTarget
{
  /** Default: `StartupState` (splash videos) and then `TitleState`. */
  SPLASH;

  /** `ClientPrefs.disableSplash`: `TitleState` right away. */
  TITLE;

  /** `-DMENU`: `MainMenuState`, skipping the splash and the title screen. */
  MAIN_MENU;

  /** `-DFREEPLAY`: `FreeplayState`, skipping the splash and the title screen. */
  FREEPLAY;
}
