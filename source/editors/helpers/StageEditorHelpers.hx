package editors.helpers;

import backend.CoolUtil;
import backend.Paths;
import data.StageEditorCore;
import editors.StageEditorState;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import objects.Character;
import objects.StagePropSprite;
import play.helpers.PlayStateStageObjects;

@:access(editors.StageEditorState)
class StageEditorHelpers
{
	/** Stage ids from `stageList.txt` plus every `stages/*.json` folder. */
	public static function listStages():Array<String>
	{
		var stages:Array<String> = [];
		var seen:Map<String, Bool> = [];

		var stageFile:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
		for (name in stageFile)
		{
			if (name != null && name.length > 0 && !seen.exists(name))
			{
				stages.push(name);
				seen.set(name, true);
			}
		}

		#if MODS_ALLOWED
		var directories:Array<String> = [
			Paths.mods('stages/'),
			Paths.mods(Mods.currentModDirectory + '/stages/'),
			Paths.getPreloadPath('stages/')
		];
		for (mod in Mods.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end

		#if sys
		for (directory in directories)
		{
			if (directory == null || !FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
				continue;
			for (file in FileSystem.readDirectory(directory))
			{
				if (!file.toLowerCase().endsWith('.json')) continue;
				var name:String = file.substr(0, file.length - 5);
				if (!seen.exists(name))
				{
					stages.push(name);
					seen.set(name, true);
				}
			}
		}
		#end

		if (stages.length < 1) stages.push('stage');
		return stages;
	}

	/** Point `Paths` at the stage JSON's asset directory. */
	public static function loadJsonDirectory(state:StageEditorState):Void
	{
		var directory:String = 'shared';
		var weekDir:String = state.stageJson != null ? state.stageJson.directory : '';
		if (weekDir != null && weekDir.length > 0) directory = weekDir;
		Paths.setCurrentLevel(directory);
	}

	/** Runtime sprite with a magenta stand-in when the image is missing. */
	public static function buildEditorSprite(data:Dynamic):StagePropSprite
	{
		var spr:StagePropSprite = PlayStateStageObjects.buildSprite(data);
		if (spr == null)
		{
			spr = new StagePropSprite(data != null ? data.x : 0, data != null ? data.y : 0);
			spr.makeGraphic(100, 100, 0xFFFF00FF);
			spr.objectName = data != null && data.name != null ? Std.string(data.name) : 'sprite';
		}
		else if (spr.objectType != 'square' && spr.frameWidth <= 2 && spr.frameHeight <= 2)
		{
			spr.makeGraphic(100, 100, 0xFFFF00FF);
			spr.active = false;
		}
		return spr;
	}

	/** Copy transform/color fields from JSON onto an already loaded sprite. */
	public static function applyObjectToSprite(spr:StagePropSprite, data:Dynamic):Void
	{
		if (spr == null || data == null) return;
		data = StageEditorCore.normalizeObject(data);
		spr.x = data.x;
		spr.y = data.y;
		spr.objectName = data.name != null ? Std.string(data.name) : '';
		spr.objectType = StageEditorCore.canonicalType(data.type);
		spr.danceEvery = data.danceEvery != null ? data.danceEvery : 0;
		spr.filters = data.filters != null ? data.filters : StageEditorCore.FILTER_BOTH_QUALITY;
		spr.firstAnimation = data.firstAnimation != null ? Std.string(data.firstAnimation) : '';
		spr.flipX = data.flipX == true;
		spr.flipY = data.flipY == true;
		spr.antialiasing = data.antialiasing != false;
		spr.visible = data.visible != false;
		spr.alpha = data.alpha != null ? data.alpha : 1;
		spr.angle = data.angle != null ? data.angle : 0;
		spr.color = FlxColor.fromInt(0xFF000000 | StageEditorCore.parseColor(data.color));
		var scroll = StageEditorCore.pair(data.scroll);
		spr.scrollFactor.set(scroll[0], scroll[1]);
		var scale = StageEditorCore.pair(data.scale);
		spr.scale.set(scale[0], scale[1]);
		spr.updateHitbox();
	}

	/** Write the sprite's current x/y back onto a prop object. */
	public static function syncSpriteToData(spr:FlxSprite, data:Dynamic):Void
	{
		if (spr == null || data == null || StageEditorCore.isCharacterType(data.type)) return;
		data.x = spr.x;
		data.y = spr.y;
	}

	/** Place GF/Dad/BF at the stage JSON positions plus their own offsets. */
	public static function repositionCharacters(state:StageEditorState):Void
	{
		if (state.gf != null)
		{
			var pos = StageEditorCore.characterPosition(state.stageJson, 'gf');
			state.gf.setPosition(pos[0] + state.gf.positionArray[0], pos[1] + state.gf.positionArray[1]);
			state.gf.visible = state.stageJson.hide_girlfriend != true;
			state.gf.scrollFactor.set(0.95, 0.95);
		}
		if (state.dad != null)
		{
			var pos = StageEditorCore.characterPosition(state.stageJson, 'dad');
			state.dad.setPosition(pos[0] + state.dad.positionArray[0], pos[1] + state.dad.positionArray[1]);
		}
		if (state.boyfriend != null)
		{
			var pos = StageEditorCore.characterPosition(state.stageJson, 'boyfriend');
			state.boyfriend.setPosition(pos[0] + state.boyfriend.positionArray[0], pos[1] + state.boyfriend.positionArray[1]);
		}
	}

	/** Preview character for a slot id (`gf` / `dad` / `boyfriend`). */
	public static function characterFor(state:StageEditorState, type:String):Character
	{
		return switch (StageEditorCore.canonicalType(type))
		{
			case 'gf': state.gf;
			case 'dad': state.dad;
			default: state.boyfriend;
		};
	}

	/** Pretty JSON for the save dialog. */
	public static function stageJsonText(state:StageEditorState):String
	{
		state.flushSelectedToJson();
		state.stageJson.preload = StageEditorCore.buildPreload(state.stageJson.objects);
		return StageEditorCore.stringify(state.stageJson);
	}

	/**
	 * `mods/<current mod>/stages/<name>.json`, or `mods/stages/` when no mod
	 * is loaded. Goes through `Paths.mods` so Recovery Boot still redirects.
	 */
	public static function currentModStagePath(stageName:String):String
	{
		var mod:String = '';
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null) mod = Mods.currentModDirectory;
		#end
		#if MODS_ALLOWED
		var file:String = StageEditorCore.sanitizeStageFileName(stageName) + '.json';
		var folder:String = StageEditorCore.sanitizeModFolder(mod);
		var key:String = (folder.length < 1 ? 'stages/' : folder + '/stages/') + file;
		return Paths.mods(key);
		#else
		return StageEditorCore.modStagePath(mod, stageName);
		#end
	}

	/** Create `dir` and any missing parents. No-op when `sys` is off. */
	public static function ensureDirectory(dir:String):Void
	{
		#if sys
		if (dir == null || dir.length < 1) return;
		if (FileSystem.exists(dir)) return;
		var slash:Int = dir.lastIndexOf('/');
		if (slash < 0) slash = dir.lastIndexOf('\\');
		if (slash > 0) ensureDirectory(dir.substr(0, slash));
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		#end
	}

	/** Write `data` to `path`, creating parent folders. Returns false off-sys. */
	public static function writeStageFile(path:String, data:String):Bool
	{
		#if sys
		if (path == null || path.length < 1 || data == null) return false;
		var slash:Int = path.lastIndexOf('/');
		if (slash < 0) slash = path.lastIndexOf('\\');
		if (slash > 0) ensureDirectory(path.substr(0, slash));
		File.saveContent(path, data);
		return true;
		#else
		return false;
		#end
	}

	/** Preview character id stored in `_editorMeta`. */
	public static function editorMetaName(stage:Dynamic, slot:String):String
	{
		if (stage == null || stage._editorMeta == null) return slot == 'boyfriend' ? 'bf' : slot;
		var value:Dynamic = Reflect.field(stage._editorMeta, slot);
		if (value == null || Std.string(value).length < 1)
			return slot == 'boyfriend' ? 'bf' : slot;
		return Std.string(value);
	}
}
