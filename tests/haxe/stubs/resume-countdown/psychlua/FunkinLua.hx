package psychlua;

/** The shared script sentinels; the same strings stand for all backends. */
class FunkinLua
{
  public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
  public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
}
