package editors.helpers;

// REFACTOR: dialogue JSON load/save FileReference plumbing extracted from
// editors.DialogueCharacterEditorState and editors.DialogueEditorState (behavior-preserving)

import editors.DialogueCharacterEditorState;
import editors.DialogueEditorState;
import objects.DialogueBoxPsych;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
#if sys
import sys.io.File;
#end
import flixel.FlxG;

@:access(editors.DialogueCharacterEditorState)
@:access(editors.DialogueEditorState)
class DialogueEditorHelpers
{
	// ---- Pure shared: JSON stringify (dialogue save) ----
	/**
	 * Executes the `jsonStringify` operation.
	 * @param data Input value for `data`.
	 * @return Result produced by `jsonStringify`, when applicable.
	 */
	public static function jsonStringify(data:Dynamic):String
	{
		return Json.stringify(data, "\t");
	}

	// ---- Pure shared: read raw json file content ----
	/**
	 * Executes the `readRawJson` operation.
	 * @param path Input value for `path`.
	 * @return Result produced by `readRawJson`, when applicable.
	 */
	public static function readRawJson(path:String):String
	{
		#if sys
		return File.getContent(path);
		#else
		return Assets.getText(path);
		#end
	}

	// ---- Shared: set up a FileReference browse dialog for a JSON file ----
	/**
	 * Executes the `browseForJsonFile` operation.
	 * @param file Input value for `file`.
	 */
	public static function browseForJsonFile(file:FileReference, onLoadComplete:Dynamic->Void, onLoadCancel:Dynamic->Void, onLoadError:Dynamic->Void):Void
	{
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		file.addEventListener(Event.SELECT, onLoadComplete);
		file.addEventListener(Event.CANCEL, onLoadCancel);
		file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		file.browse([jsonFilter]);
	}

	// ---- Shared: save a JSON string through a FileReference dialog ----
	/**
	 * Executes the `saveJsonFile` operation.
	 * @param file Input value for `file`.
	 * @param data Input value for `data`.
	 * @param fileName Input value for `fileName`.
	 */
	public static function saveJsonFile(file:FileReference, data:String, fileName:String, onComplete:Dynamic->Void, onCancel:Dynamic->Void, onError:Dynamic->Void):Void
	{
		file.addEventListener(Event.COMPLETE, onComplete);
		file.addEventListener(Event.CANCEL, onCancel);
		file.addEventListener(IOErrorEvent.IO_ERROR, onError);
		file.save(data, fileName);
	}

	// ---- Shared: remove load listeners + cancel trace ----
	/**
	 * Executes the `cancelLoadFile` operation.
	 * @param file Input value for `file`.
	 */
	public static function cancelLoadFile(file:FileReference, onLoadComplete:Dynamic->Void, onLoadCancel:Dynamic->Void, onLoadError:Dynamic->Void):Void
	{
		file.removeEventListener(Event.SELECT, onLoadComplete);
		file.removeEventListener(Event.CANCEL, onLoadCancel);
		file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		trace("Cancelled file loading.");
	}

	// ---- Shared: remove load listeners + load error trace ----
	/**
	 * Executes the `failLoadFile` operation.
	 * @param file Input value for `file`.
	 */
	public static function failLoadFile(file:FileReference, onLoadComplete:Dynamic->Void, onLoadCancel:Dynamic->Void, onLoadError:Dynamic->Void):Void
	{
		file.removeEventListener(Event.SELECT, onLoadComplete);
		file.removeEventListener(Event.CANCEL, onLoadCancel);
		file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		trace("Problem loading file");
	}

	// ---- Shared: remove save listeners + success notice ----
	/**
	 * Executes the `completeSaveFile` operation.
	 * @param file Input value for `file`.
	 */
	public static function completeSaveFile(file:FileReference, onComplete:Dynamic->Void, onCancel:Dynamic->Void, onError:Dynamic->Void):Void
	{
		file.removeEventListener(Event.COMPLETE, onComplete);
		file.removeEventListener(Event.CANCEL, onCancel);
		file.removeEventListener(IOErrorEvent.IO_ERROR, onError);
		FlxG.log.notice("Successfully saved file.");
	}

	// ---- Shared: remove save listeners (cancelled, no message) ----
	/**
	 * Executes the `cancelSaveFile` operation.
	 * @param file Input value for `file`.
	 */
	public static function cancelSaveFile(file:FileReference, onComplete:Dynamic->Void, onCancel:Dynamic->Void, onError:Dynamic->Void):Void
	{
		file.removeEventListener(Event.COMPLETE, onComplete);
		file.removeEventListener(Event.CANCEL, onCancel);
		file.removeEventListener(IOErrorEvent.IO_ERROR, onError);
	}

	// ---- Shared: remove save listeners + save error ----
	/**
	 * Executes the `failSaveFile` operation.
	 * @param file Input value for `file`.
	 */
	public static function failSaveFile(file:FileReference, onComplete:Dynamic->Void, onCancel:Dynamic->Void, onError:Dynamic->Void):Void
	{
		file.removeEventListener(Event.COMPLETE, onComplete);
		file.removeEventListener(Event.CANCEL, onCancel);
		file.removeEventListener(IOErrorEvent.IO_ERROR, onError);
		FlxG.log.error("Problem saving file");
	}

	// ---- per-file: onLoadComplete for editors.DialogueCharacterEditorState ----
	/**
	 * Executes the `onLoadCompleteCharacter` operation.
	 * @param state Input value for `state`.
	 */
	public static function onLoadCompleteCharacter(state:DialogueCharacterEditorState):Void
	{
		state._file.removeEventListener(Event.SELECT, state.onLoadComplete);
		state._file.removeEventListener(Event.CANCEL, state.onLoadCancel);
		state._file.removeEventListener(IOErrorEvent.IO_ERROR, state.onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(state._file.__path != null) fullPath = state._file.__path;

		if(fullPath != null) {
			var rawJson:String = readRawJson(fullPath);
			if(rawJson != null) {
				var loadedChar:DialogueCharacterFile = cast Json.parse(rawJson);
				if(loadedChar.dialogue_pos != null) //Make sure it's really a dialogue character
				{
					var cutName:String = state._file.name.substr(0, state._file.name.length - 5);
					trace("Successfully loaded file: " + cutName);
					state.character.jsonFile = loadedChar;
					state.reloadCharacter();
					state.reloadAnimationsDropDown();
					state.updateCharTypeBox();
					state.updateTextBox();
					state.daText.resetDialogue();
					state.imageInputText.text = state.character.jsonFile.image;
					state.scaleStepper.value = state.character.jsonFile.scale;
					state.xStepper.value = state.character.jsonFile.position[0];
					state.yStepper.value = state.character.jsonFile.position[1];
					state._file = null;
					return;
				}
			}
		}
		state._file = null;
		#else
		trace("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	// ---- per-file: onLoadComplete for editors.DialogueEditorState ----
	/**
	 * Executes the `onLoadCompleteDialogue` operation.
	 * @param state Input value for `state`.
	 */
	public static function onLoadCompleteDialogue(state:DialogueEditorState):Void
	{
		state._file.removeEventListener(Event.SELECT, state.onLoadComplete);
		state._file.removeEventListener(Event.CANCEL, state.onLoadCancel);
		state._file.removeEventListener(IOErrorEvent.IO_ERROR, state.onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(state._file.__path != null) fullPath = state._file.__path;

		if(fullPath != null) {
			var rawJson:String = readRawJson(fullPath);
			if(rawJson != null) {
				var loadedDialog:DialogueFile = cast Json.parse(rawJson);
				if(loadedDialog.dialogue != null && loadedDialog.dialogue.length > 0) //Make sure it's really a dialogue file
				{
					var cutName:String = state._file.name.substr(0, state._file.name.length - 5);
					trace("Successfully loaded file: " + cutName);
					state.dialogueFile = loadedDialog;
					state.changeText();
					state._file = null;
					return;
				}
			}
		}
		state._file = null;
		#else
		trace("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}
}
