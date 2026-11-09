package backend;

/**
 * Backend alias for `objects.NoteColors`.
 *
 * Some code and docs import note colors from `backend`, others from `objects`.
 * Both packages expose the same implementation so `NoteColors.laneRGB(...)`
 * resolves regardless of the import style used in `Note.hx` or mods.
 *
 * Prefer `objects.NoteColors` for new engine code (the note objects live in
 * `objects`), but `backend.NoteColors` is kept as a stable public path.
 */
typedef NoteColors = objects.NoteColors;
