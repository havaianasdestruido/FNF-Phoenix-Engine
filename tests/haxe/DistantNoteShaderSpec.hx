import shaders.DistantNoteShader;

class DistantNoteShaderSpec
{
  static function main()
  {
    var up = new DistantNoteShader();
    var down = new DistantNoteShader(true);
    if (up.uDownscroll.value.length != 1 || up.uDownscroll.value[0])
      throw 'Default must initialize the upscroll uniform';
    if (down.uDownscroll.value.length != 1 || !down.uDownscroll.value[0])
      throw 'Downscroll must initialize its uniform';
    trace('Distant note shader uniform initialization OK');
  }
}
