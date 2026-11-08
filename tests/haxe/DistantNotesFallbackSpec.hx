import backend.ClientPrefs;
import play.PlayState;
import play.helpers.PlayStateDistantNotes;

/** Unsupported targets must not allocate a camera or force middlescroll. */
class DistantNotesFallbackSpec
{
  static function main():Void
  {
    ClientPrefs.distantNotes = true;
    ClientPrefs.shaders = true;
    final state = new PlayState();
    if (PlayStateDistantNotes.distantNotesEnabled()) throw 'unsupported target enabled perspective';
    PlayStateDistantNotes.setupDistantNotes(state);
    PlayStateDistantNotes.syncDistantNotes(state);
    if (state.camStrum != null) throw 'unsupported target allocated a camera';
    Sys.println('DistantNotesFallbackSpec: PASS');
  }
}
