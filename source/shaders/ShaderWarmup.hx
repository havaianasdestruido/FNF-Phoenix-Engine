package shaders;

import backend.FlxFixedShader;
import backend.VLog;
import flixel.FlxG;
import openfl.display.Shader;
#if (SHADERS_ALLOWED && !flash)
import openfl.display3D.Context3D;
#end

/**
 * Compiles shader programs **before** the frame that first draws them.
 *
 * GLSL is compiled lazily by the renderer the first time a shader is bound, so
 * a stage shader (`RainShader`), the `Pulse` event's `RuntimeShaders.pulseEffect`
 * or a mod shader created by Lua all stall the frame that first uses them -
 * usually the first bop of a song. This class runs the exact same lazy
 * initialisation the renderer would run (`OpenGLRenderer.__initShader`), but
 * while the game is still on a loading screen.
 *
 * The compiled program lands in OpenFL's per-context program cache, which is
 * keyed by vertex+fragment source, so the instance the stage later renders with
 * gets a cache hit instead of a driver compile. Backends that cannot compile
 * outside a render pass (no `Stage.context3D`, or the Flash/AIR target where
 * `SHADERS_ALLOWED` is off) simply report `isSupported() == false` and every
 * call becomes a no-op with a counter bump.
 *
 * Typical use, from a state that is loading gameplay:
 * ```haxe
 * ShaderWarmup.beginLoading();          // start queuing script shaders
 * // ... create the stage, scripts, ...
 * ShaderWarmup.warmAll(stage.declareShaders());
 * ShaderWarmup.endLoading();            // compile everything queued above
 * ```
 */
class ShaderWarmup
{
  /** GLSL (plus shader family) already compiled during this session. */
  static var warmedPrograms:Map<String, Bool> = [];

  /** Shaders queued by `track()` during the current loading phase. */
  static var pending:Array<Shader> = [];

  /** Whether `track()` queues shaders right now (only while loading). */
  static var collecting:Bool = false;

  /** Programs compiled ahead of time in this session. */
  public static var compiled(default, null):Int = 0;
  /** Warm-up calls answered by the program cache instead of the driver. */
  public static var reused(default, null):Int = 0;
  /** Shaders the driver (or a `custom` shader) refused to build. */
  public static var failed(default, null):Int = 0;
  /** Warm-up calls on a backend that cannot pre-compile programs. */
  public static var unsupported(default, null):Int = 0;

  /**
   * Whether this backend can compile a program outside a render pass.
   * @return `true` when there is a GL context to compile against.
   */
  public static function isSupported():Bool
  {
    #if (SHADERS_ALLOWED && !flash)
    return renderContext() != null;
    #else
    return false;
    #end
  }

  /**
   * Begins a loading phase: shaders handed to `track()` are queued and
   * compiled by `endLoading()`.
   */
  public static function beginLoading():Void
  {
    pending = [];
    collecting = true;
  }

  /**
   * Queues a shader created while a state is loading (a runtime shader
   * instantiated by a Lua/Python/HScript call, for example) so it is compiled
   * with the rest of the stage's shaders instead of on its first draw.
   *
   * @param shader The instance to compile later; `null` is ignored.
   */
  public static function track(?shader:Shader):Void
  {
    if (!collecting || shader == null) return;
    if (pending.indexOf(shader) != -1) return;
    pending.push(shader);
  }

  /**
   * Ends the loading phase and compiles everything `track()` queued.
   * @return How many queued shaders ended up with a usable program.
   */
  public static function endLoading():Int
  {
    collecting = false;

    var queue:Array<Shader> = pending;
    pending = [];
    if (queue.length == 0) return 0;

    var done:Int = 0;
    for (i in 0...queue.length)
      if (warm(queue[i])) done++;
    return done;
  }

  /**
   * Compiles one shader now, unless its GLSL was already compiled in this
   * session.
   *
   * @param shader The instance the game will render with; `null` is ignored.
   * @param label Name used in logs (defaults to the shader's class name).
   * @return `true` when the shader has a usable program afterwards.
   */
  public static function warm(?shader:Shader, ?label:String):Bool
  {
    if (shader == null) return false;

    #if (SHADERS_ALLOWED && !flash)
    // A `custom` FlxFixedShader builds (and reuses) its own program, so there is
    // nothing this class could cache for it.
    if (isSelfManaged(shader))
    {
      unsupported++;
      return false;
    }

    var key:String = programKey(shader);

    if (warmedPrograms.exists(key))
    {
      reused++;
      return true;
    }

    var context:Context3D = renderContext();
    if (context == null)
    {
      unsupported++;
      return false;
    }

    var hadProgram:Bool = shader.program != null;
    var started:Float = haxe.Timer.stamp();

    try
    {
      initProgram(shader, context);
    }
    catch (error:Dynamic)
    {
      failed++;
      FlxG.log.warn('[ShaderWarmup] Could not pre-compile ${describe(shader, label)}: $error');
      return false;
    }

    if (shader.program == null)
    {
      failed++;
      FlxG.log.warn('[ShaderWarmup] ${describe(shader, label)} did not build a GL program (custom shader?)');
      return false;
    }

    // `save == false` programs are per instance: remembering the source would
    // make the next shader with the same GLSL skip its own compile.
    if (sharesProgram(shader)) warmedPrograms.set(key, true);

    if (hadProgram)
      reused++;
    else
      compiled++;

    if (VLog.isActive())
    {
      var elapsed:Int = Std.int((haxe.Timer.stamp() - started) * 1000);
      VLog.log('shader', 'warm-up ${describe(shader, label)} in ' + elapsed + ' ms');
    }

    return true;
    #else
    unsupported++;
    return false;
    #end
  }

  /**
   * Compiles every shader in a stage's declaration list.
   *
   * @param shaders The list to compile; `null` and repeated entries are fine.
   * @param label Name used in logs (defaults to each shader's class name).
   * @return How many shaders ended up with a usable program.
   */
  public static function warmAll(?shaders:Array<Shader>, ?label:String):Int
  {
    if (shaders == null) return 0;

    var done:Int = 0;
    for (i in 0...shaders.length)
      if (warm(shaders[i], label)) done++;
    return done;
  }

  /** One line with the session counters, for logs. */
  public static function summary():String
  {
    return 'shader warm-up: ' + compiled + ' compiled, ' + reused + ' cached, ' + failed + ' failed, ' + unsupported + ' unsupported';
  }

  /** Clears the session cache and the counters (tests, soft restarts). */
  public static function reset():Void
  {
    warmedPrograms = [];
    pending = [];
    collecting = false;
    compiled = 0;
    reused = 0;
    failed = 0;
    unsupported = 0;
  }

  #if (SHADERS_ALLOWED && !flash)
  /** GL context every shader is compiled against, when the stage has one. */
  static function renderContext():Context3D
  {
    var stage = FlxG.stage;
    return stage != null ? stage.context3D : null;
  }

  /**
   * Mirrors what the renderer does on the first draw
   * (`OpenGLRenderer.__initShader`): bind the shader to the render context and
   * let it build its program.
   */
  static function initProgram(shader:Shader, context:Context3D):Void
  {
    @:privateAccess
    {
      if (shader.__context == null) shader.__context = context;
      shader.__init();
    }
  }

  /**
   * Cache key of the GLSL a shader compiles. OpenFL keeps one program per
   * context *and* source string; `FlxFixedShader` rewrites the sources with its
   * own `#version` prefix, so the two shader families never share a key even
   * when the GLSL text is identical.
   */
  static function programKey(shader:Shader):String
  {
    var flavor:String = Std.isOfType(shader, FlxFixedShader) ? 'fixed' : 'openfl';
    return flavor + ':' + shader.glVertexSource + ':' + shader.glFragmentSource;
  }

  /** Whether the backend reuses this instance's program for identical GLSL. */
  static function sharesProgram(shader:Shader):Bool
  {
    if (!Std.isOfType(shader, FlxFixedShader)) return true;

    var fixed:FlxFixedShader = cast shader;
    return fixed.save;
  }

  /** `FlxFixedShader(custom = true)` compiles and owns its program itself. */
  static function isSelfManaged(shader:Shader):Bool
  {
    if (!Std.isOfType(shader, FlxFixedShader)) return false;

    var fixed:FlxFixedShader = cast shader;
    return fixed.custom;
  }
  #end

  /** Log label for a shader: the caller's label, else its class name. */
  static function describe(shader:Shader, ?label:String):String
  {
    if (label != null && label.length > 0) return label;

    var className:String = Type.getClassName(Type.getClass(shader));
    return className != null ? className : 'shader';
  }
}
