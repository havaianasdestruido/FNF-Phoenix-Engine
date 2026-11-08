package backend;

/**
 * Compile-time launch shortcuts ported from Doido Engine
 * (`DoidoTeam/FNF-Doido-Engine`).
 *
 * Build flags:
 *
 * - `-DFREEPLAY` boots straight into `FreeplayState`.
 * - `-DMENU` boots straight into `MainMenuState`.
 *
 * They pick different start screens, so they are mutually exclusive.
 * `project.hxp` (`configureLaunchFlags`) aborts the build when both are set; if
 * one still reaches the runtime, `FREEPLAY` wins so the result stays
 * deterministic instead of depending on define order.
 *
 * Both flags skip `StartupState` (splash videos) and `TitleState`. Mods, prefs
 * and the save file are still loaded by `InitState` first, so a direct boot
 * behaves like reaching those screens by playing normally. Builds that ship
 * this way are development builds: the title screen easter eggs, the update
 * check prompt and the flashing-lights warning that live on `TitleState` are
 * skipped.
 */
class LaunchState
{
  /** True when the build was made with `-DFREEPLAY`. */
  public static final FREEPLAY_BUILD:Bool = #if FREEPLAY true #else false #end;

  /** True when the build was made with `-DMENU`. */
  public static final MENU_BUILD:Bool = #if MENU true #else false #end;

  /**
   * True when both launch flags are enabled. `project.hxp` rejects that at
   * build time; this stays available for logging and for the spec.
   */
  public static function hasConflict(freeplay:Null<Bool> = null, menu:Null<Bool> = null):Bool
  {
    return (freeplay ?? FREEPLAY_BUILD) && (menu ?? MENU_BUILD);
  }

  /**
   * Resolve the first screen of this run.
   *
   * @param disableSplash The `ClientPrefs.disableSplash` value (skips the splash videos).
   * @param freeplay Overrides the `-DFREEPLAY` define; `null` reads the define.
   * @param menu Overrides the `-DMENU` define; `null` reads the define.
   * @return The state `InitState` should switch to.
   */
  public static function resolve(disableSplash:Bool = false, freeplay:Null<Bool> = null, menu:Null<Bool> = null):LaunchTarget
  {
    // `-DFREEPLAY` wins a conflict: project.hxp refuses to build that case, and
    // a fixed order keeps a mis-built binary predictable.
    if (freeplay ?? FREEPLAY_BUILD)
      return LaunchTarget.FREEPLAY;
    if (menu ?? MENU_BUILD)
      return LaunchTarget.MAIN_MENU;
    return disableSplash ? LaunchTarget.TITLE : LaunchTarget.SPLASH;
  }

  /** Human readable name, used by the build log and by the spec. */
  public static function targetName(target:LaunchTarget):String
  {
    return switch (target)
    {
      case SPLASH: 'splash videos then title screen';
      case TITLE: 'title screen (splash disabled)';
      case MAIN_MENU: 'main menu (-DMENU)';
      case FREEPLAY: 'freeplay (-DFREEPLAY)';
    }
  }
}
