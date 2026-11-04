#if macro
import haxe.macro.Context;
import haxe.macro.Type;
#end

/**
 * Check the selected badge in an actual SWF target without needing a Flash
 * player. The target-specific branches of PlatformIcons.detect() return a
 * constant, so the typed function body tells us which branch was compiled.
 */
class PlatformIconTargetCheck
{
  #if macro
  public static function expect(expected:String):Void
  {
    if ((expected != 'flash' && expected != 'air') || !Context.defined('flash')
      || Context.defined('air') != (expected == 'air'))
      Context.error('Expected an SWF target for $expected', Context.currentPos());

    var checked:Bool = false;
    Context.onAfterTyping(function(types:Array<ModuleType>)
    {
      for (type in types)
      {
        switch (type)
        {
          case TClassDecl(ref):
            final cls = ref.get();
            if (cls.module != 'backend.PlatformIcons' || cls.name != 'PlatformIcons') continue;

            for (field in cls.statics.get())
            {
              if (field.name != 'detect') continue;
              final actual = returnedLiteral(field.expr());
              if (actual == null)
                Context.error('PlatformIcons.detect() no longer returns a constant for $expected; update the target check', field.pos);
              if (actual != expected)
                Context.error('PlatformIcons.detect(): expected $expected, got $actual', field.pos);
              checked = true;
            }
          default:
        }
      }
    });
    Context.onGenerate(function(_)
    {
      if (!checked) Context.error('PlatformIcons.detect() was not checked for $expected', Context.currentPos());
      Sys.println('Platform icon SWF target passed: $expected');
    });
  }

  /** Unwrap the typed, constant return selected by the compiler's target flags. */
  static function returnedLiteral(expr:Null<TypedExpr>):Null<String>
  {
    if (expr == null) return null;
    return switch (expr.expr)
    {
      case TFunction(fn): returnedLiteral(fn.expr);
      case TBlock([only]): returnedLiteral(only);
      case TReturn(value) | TCast(value, _) | TParenthesis(value) | TMeta(_, value): returnedLiteral(value);
      case TConst(TString(value)): value;
      default: null;
    }
  }
  #end
}
