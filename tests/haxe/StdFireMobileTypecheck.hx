import backend.StdFire;

/** Typecheck mobile branches against the actual pinned Lime Window/JNI APIs. */
class StdFireMobileTypecheck
{
  static function main():Void
  {
    StdFire.engineTitleChanged('Engine');
    StdFire.nativeTitleRename('Título 🔥');
    StdFire.nativeMSGBox('Mensagem 世界', 'Aviso 🌍');
    StdFire.nativeWarn('Aviso 🔥');
    StdFire.nativeTitleRename(null);
  }
}
