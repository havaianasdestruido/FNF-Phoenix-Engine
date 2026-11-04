// HScript template — every hook the engine fires (Lua + Python + HScript parity).
// See website/docs/modding/script-hooks.md for the authoritative table;
// this file is the executable checklist. Drop it into
// mods/<mod>/scripts/ or mods/<mod>/data/<song>/ (as .hx or .hscript)
// and watch the debug overlay.
//
// A standalone HScript mod is plain Haxe run by hscript-improved:
//   * `game` is the PlayState instance, `Paths`, `ClientPrefs`, `Conductor`,
//     `FlxG`, `FlxSprite`, `FlxTween`, ... are already in scope;
//   * anything else: `import some.package.ClassName;` at the top of the file
//     (unsandboxed mods), or `addHaxeLibrary('ClassName', 'some.package');`
//   * flat engine globals (`curBeat`, `songName`, `downscroll`, ...) are kept
//     up to date by the engine — read them, but do not redeclare them with
//     `var`, which would shadow the engine's copy;
//   * top-level `var`/`function` are private to this file; share state with
//     other scripts through setVar()/getVar() or `game.variables`.
//
// Hooks that can cancel engine behaviour must `return Function_Stop;` to do so;
// `return Function_StopLua;` (alias `Function_StopAll`) stops propagation to
// later scripts. Hooks without a `return` are treated as `Function_Continue`.
//
// Set `hscriptDebugMode = true;` at the top level to see hook errors and
// debugPrint() output on screen while developing.

// ---------------------------------------------------------------------------
// Lifecycle — called once per script load / unload, and every frame
// ---------------------------------------------------------------------------

function onCreate() {
	// When the script is first loaded; many PlayState fields do not exist yet.
	// Prefer onCreatePost for normal setup.
}

function onCreatePost() {
	// End of create(), every PlayState field is ready — the recommended setup point.
	// Example:
	//   var spr = new FlxSprite(100, 100);
	//   spr.makeGraphic(200, 50, FlxColor.RED);
	//   game.add(spr);
}

function onDestroy() {
	// Song fade-out finished, the script is being removed.
}

function onUpdate(elapsed:Float) {
	// Start of the frame, before engine logic.
}

function onUpdatePost(elapsed:Float) {
	// End of the frame.
}

// ---------------------------------------------------------------------------
// Song flow — countdown, sections, timing
// ---------------------------------------------------------------------------

function onStartCountdown() {
	// Before the countdown. Return Function_Stop to suppress it (use for
	// dialogue), then call game.startCountdown() when ready.
	return Function_Continue;
}

function onCountdownStarted() {
	// The countdown actually began.
}

function onCountdownTick(counter:Int) {
	// counter = 0 -> "Three", 1 -> "Two", 2 -> "One", 3 -> "Go!"
	// counter = 4 -> nothing (fired alongside onSongStart, rarely useful)
}

function onSongStart() {
	// Vocals + inst started, songPosition = 0
}

function onEndSong() {
	// Song finished / transition starting.
	// Return Function_Stop to block the transition (for cutscenes).
	return Function_Continue;
}

function onBeatHit() {
	// Triggered 4 times per section (on every beat)
}

function onStepHit() {
	// Triggered 16 times per section (on every step)
}

function onSectionHit() {
	// Once per section
}

// ---------------------------------------------------------------------------
// Pause / resume / game-over / dialogue
// ---------------------------------------------------------------------------

function onPause() {
	// Pause pressed while not in a cutscene.
	// Return Function_Stop to block pausing.
	return Function_Continue;
}

function onResume() {
	// Game was resumed from pause (not necessarily the pause menu).
}

function onGameOver() {
	// Fired every frame while health <= 0.
	// Return Function_Stop to block entering the game-over screen.
	return Function_Continue;
}

function onGameOverStart() {
	// The game-over screen just opened.
}

function onGameOverConfirm(retry:Bool) {
	// Player pressed Enter/Esc on game-over.
	// retry == false when Esc was pressed; true for Enter.
}

function onNextDialogue(line:Int) {
	// Next dialogue line is about to show; line is 1-indexed.
}

function onSkipDialogue(line:Int) {
	// A line was skipped while it was still typing; line is 1-indexed.
}

// ---------------------------------------------------------------------------
// Notes — hit / miss / spawn
// ---------------------------------------------------------------------------

function onSpawnNote(id:Int, noteData:Int, noteType:String, isSustainNote:Bool, strumTime:Float) {
	// A note is entering play. id is its group index; noteData 0..3 (L/D/U/R).
	// The note object itself is game.notes.members[id].
}

function goodNoteHit(id:Int, direction:Int, noteType:String, isSustainNote:Bool) {
	// Player hit a note (after calculations)
	// direction 0=Left 1=Down 2=Up 3=Right; noteType is the type string
}

function opponentNoteHit(id:Int, direction:Int, noteType:String, isSustainNote:Bool) {
	// Opponent hit a note — same arguments as goodNoteHit
}

function goodNoteSkip(id:Int, direction:Int, noteType:String, isSustainNote:Bool) {
	// A player note was skipped (e.g. hidden/botplay path); only when
	// ClientPrefs.noSkipFuncs == false.
}

function opponentNoteSkip(id:Int, direction:Int, noteType:String, isSustainNote:Bool) {
	// Same as goodNoteSkip for the opponent side
}

function noteMiss(id:Int, direction:Int, noteType:String, isSustainNote:Bool) {
	// Player missed a note by letting it pass.
}

function noteMissPress(direction:Int) {
	// Ghost miss: player pressed with no note to hit.
}

function onGhostTap(key:Int) {
	// A tap that hit nothing, with ghost tapping enabled (noteMissPress wrapper)
}

function onKeyPress(key:Int) {
	// Raw lane input pressed; key is 0..3
}

function onKeyRelease(key:Int) {
	// Raw lane input released; key is 0..3
}

// ---------------------------------------------------------------------------
// Camera / rating / score
// ---------------------------------------------------------------------------

function onMoveCamera(focus:String) {
	// focus is 'boyfriend', 'dad' or 'gf'
	if (focus == 'boyfriend') {
	} else if (focus == 'dad') {
	} else if (focus == 'gf') {
	}
}

function onRecalculateRating() {
	// Fired BEFORE the rating calculation.
	// Return Function_Stop and set game.ratingPercent / game.ratingName /
	// game.ratingFC yourself to supply your own.
	return Function_Continue;
}

function onUpdateScore(miss:Bool) {
	// Score text is about to update; miss == true if this was a miss update.
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

function onEvent(name:String, value1:String, value2:String, strumTime:Float) {
	// An event note fired (game.triggerEvent() does NOT call this).
}

function eventEarlyTrigger(name:String, value1:String, value2:String, strumTime:Float) {
	// Return a millisecond offset to fire the named event earlier.
	// Example: if (name == 'Kill Henchmen') return 280;
}

// ---------------------------------------------------------------------------
// Tweens / timers / sound — async completions
// ---------------------------------------------------------------------------

function onTweenCompleted(tag:String) {
	// A script tween finished (Lua/Python doTweenX tags land here too)
}

function onTimerCompleted(tag:String, loops:Int, loopsLeft:Int) {
	// A timer loop finished; loops / loopsLeft count completed vs remaining loops
}

function onSoundFinished(tag:String) {
	// A script sound finished
}

// ---------------------------------------------------------------------------
// Custom substates — opened from script via openCustomSubstate(name, pauseGame)
// The live substate is also published as the `customSubstate` global
// (and its name as `customSubstateName`) for HScript scripts.
// ---------------------------------------------------------------------------

function onCustomSubstateCreate(name:String) {
}

function onCustomSubstateCreatePost(name:String) {
}

function onCustomSubstateUpdate(name:String, elapsed:Float) {
}

function onCustomSubstateUpdatePost(name:String, elapsed:Float) {
}

function onCustomSubstateDestroy(name:String) {
}
