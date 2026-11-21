package backend;

import haxe.xml.Xml;
import haxe.xml.Fast;

/**
 * XML definitions for characters, stages, weeks, and dialogue.
 *
 * Phoenix ships Psych-style JSON for `assets/preload/characters/*.json`,
 * `assets/preload/stages/*.json`, `assets/preload/weeks/*.json` and per-song
 * `dialogue.json`. The only XML assets used to be Sparrow atlases/UI sheets.
 *
 * This module adds an optional XML counterpart for each of those definition
 * families: a `<name>.xml` resolves to the same in-memory structures as the
 * JSON, so existing JSON content keeps working while new content may be
 * authored in XML. JSON is always tried first; XML is only a fallback, which
 * keeps every current mod and all built-in content fully compatible.
 *
 * The XML shape mirrors the JSON field names: one child element per field,
 * repeated child elements for arrays, and comma-separated text for small
 * numeric or string lists. A boolean is `true`, `1`, `yes` or `on`
 * (case-insensitive). Elements may be empty; missing elements fall back to the
 * same defaults as a missing JSON field.
 */
class XmlDefinitions
{
	// ------------------------------------------------------------------
	// Low-level XML reading
	// ------------------------------------------------------------------

	/** First child element named `name`, or null when absent. */
	public static function child(xml:Fast, name:String):Null<Fast>
	{
		var it = xml.x.elementsNamed(name);
		if (it == null || !it.hasNext()) return null;
		return new Fast(it.next());
	}

	/** All child elements named `name`. */
	public static function children(xml:Fast, name:String):Array<Fast>
	{
		var out:Array<Fast> = [];
		var it = xml.x.elementsNamed(name);
		if (it != null)
			while (it.hasNext()) out.push(new Fast(it.next()));
		return out;
	}

	/** Attribute value, or `default` (or null) when absent. */
	public static function attr(xml:Fast, name:String, ?default:Null<String>):Null<String>
	{
		var v = xml.x.get(name);
		if (v != null) return v;
		return default;
	}

	/** Whether attribute `name` is present. */
	public static function hasAttr(xml:Fast, name:String):Bool
		return xml.x.exists(name);

	/** Text content of an element, or `default` when empty/absent. */
	public static function text(xml:Fast, ?default:Null<String>):String
	{
		try
			return xml.innerData;
		catch (e:Dynamic)
			return default != null ? default : '';
	}

	/** Text content of a child element, or `default` when the child is absent. */
	public static function textOf(?xml:Null<Fast>, ?default:Null<String>):String
	{
		if (xml == null) return default != null ? default : '';
		return text(xml, default);
	}

	/** Attribute value as a Null<Bool>, or null when absent. */
	public static function attrBoolNull(xml:Fast, name:String):Null<Bool>
	{
		var v = xml.x.get(name);
		return v != null ? bool(v) : null;
	}

	/** Attribute value as a Null<Float>, or null when absent/invalid. */
	public static function attrFloatNull(xml:Fast, name:String):Null<Float>
	{
		var v = xml.x.get(name);
		if (v == null) return null;
		var f = Std.parseFloat(v);
		return Math.isNaN(f) ? null : f;
	}

	/** A comma-separated list of floats (e.g. `0,350`). */
	public static function floats(?text:Null<String>):Array<Float>
	{
		if (text == null) return [];
		var out:Array<Float> = [];
		for (p in text.split(','))
		{
			var v = Std.parseFloat(p.trim());
			if (!Math.isNaN(v)) out.push(v);
		}
		return out;
	}

	/** A comma-separated list of ints. */
	public static function ints(?text:Null<String>):Array<Int>
	{
		if (text == null) return [];
		var out:Array<Int> = [];
		for (p in text.split(','))
		{
			p = p.trim();
			if (p.length == 0) continue;
			out.push(Std.parseInt(p));
		}
		return out;
	}

	/** A comma-separated list of strings. */
	public static function strings(?text:Null<String>):Array<String>
	{
		if (text == null) return [];
		var out:Array<String> = [];
		for (p in text.split(','))
		{
			p = p.trim();
			if (p.length > 0) out.push(p);
		}
		return out;
	}

	/** A boolean: `true`, `1`, `yes`, `on` are true. */
	public static function bool(?text:Null<String>, ?default:Null<Bool>):Bool
	{
		if (text == null) return default != null ? default : false;
		var t = text.trim().toLowerCase();
		return t == 'true' || t == '1' || t == 'yes' || t == 'on';
	}

	/** A float attribute/text, or `default` when absent/invalid. */
	public static function num(?text:Null<String>, default:Float = 0):Float
	{
		if (text == null) return default;
		var v = Std.parseFloat(text.trim());
		return Math.isNaN(v) ? default : v;
	}

	/** An int attribute/text, or `default` when absent/invalid. */
	public static function integer(?text:Null<String>, default:Int = 0):Int
	{
		if (text == null) return default;
		var t = text.trim();
		if (t.length == 0) return default;
		return Std.parseInt(t);
	}

	// ------------------------------------------------------------------
	// Definition parsers
	// ------------------------------------------------------------------

	/**
	 * Parses a character XML definition into the same structure as
	 * `assets/preload/characters/<name>.json` (`objects.Character.CharacterFile`).
	 *
	 * Example:
	 * <character>
	 *   <image>characters/BOYFRIEND</image>
	 *   <scale>1</scale>
	 *   <sing_duration>4</sing_duration>
	 *   <healthicon>bf</healthicon>
	 *   <position>0,350</position>
	 *   <camera_position>0,0</camera_position>
	 *   <flip_x>true</flip_x>
	 *   <animations>
	 *     <animation>
	 *       <anim>idle</anim>
	 *       <name>BF idle dance</name>
	 *       <fps>24</fps>
	 *       <loop>false</loop>
	 *       <offsets>-5,-1</offsets>
	 *     </animation>
	 *   </animations>
	 * </character>
	 */
	public static function parseCharacter(text:String):Dynamic
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			text = text.substr(1); // strip UTF-8 BOM like the JSON loaders do
		var root = Xml.parse(text).firstElement();
		if (root == null) throw 'Character XML has no root element';
		var fast = new Fast(root);

		var anims:Array<Dynamic> = [];
		var animsEl = child(fast, 'animations');
		if (animsEl != null)
		{
			for (anim in children(animsEl, 'animation'))
			{
				var offsets = ints(textOf(child(anim, 'offsets')));
				if (offsets.length == 0)
				{
					var ox = textOf(child(anim, 'offsetX'));
					var oy = textOf(child(anim, 'offsetY'));
					if (ox != '' && oy != '') offsets = [integer(ox), integer(oy)];
				}
				anims.push({
					anim: textOf(child(anim, 'anim')),
					name: textOf(child(anim, 'name')),
					fps: integer(textOf(child(anim, 'fps')), 24),
					loop: bool(textOf(child(anim, 'loop')), false),
					indices: ints(textOf(child(anim, 'indices'))),
					offsets: offsets
				});
			}
		}

		var position = floats(textOf(child(fast, 'position')));
		if (position.length == 0) position = [0, 0];
		var cameraPosition = floats(textOf(child(fast, 'camera_position')));
		if (cameraPosition.length == 0) cameraPosition = [0, 0];

		var isPlayerEl = child(fast, 'editor_is_player');
		return {
			animations: anims,
			image: textOf(child(fast, 'image')),
			scale: num(textOf(child(fast, 'scale')), 1),
			sing_duration: num(textOf(child(fast, 'sing_duration')), 4),
			healthicon: textOf(child(fast, 'healthicon'), 'face'),
			position: position,
			camera_position: cameraPosition,
			flip_x: bool(textOf(child(fast, 'flip_x')), false),
			no_antialiasing: bool(textOf(child(fast, 'no_antialiasing')), false),
			healthbar_colors: ints(textOf(child(fast, 'healthbar_colors'))),
			trail_length: integer(textOf(child(fast, 'trail_length')), 4),
			trail_delay: integer(textOf(child(fast, 'trail_delay')), 24),
			trail_alpha: num(textOf(child(fast, 'trail_alpha')), 1),
			trail_diff: num(textOf(child(fast, 'trail_diff')), 0.069),
			flixel_trail: bool(textOf(child(fast, 'flixel_trail')), false),
			noteskin: textOf(child(fast, 'noteskin'), null),
			vocals_file: textOf(child(fast, 'vocals_file'), null),
			health_drain: bool(textOf(child(fast, 'health_drain')), false),
			drain_amount: num(textOf(child(fast, 'drain_amount')), 0),
			drain_floor: num(textOf(child(fast, 'drain_floor')), 0),
			shake_screen: bool(textOf(child(fast, 'shake_screen')), false),
			shake_intensity: num(textOf(child(fast, 'shake_intensity')), 0.0075),
			shake_duration: num(textOf(child(fast, 'shake_duration')), 0.1),
			_editor_isPlayer: isPlayerEl != null ? bool(textOf(isPlayerEl)) : null
		};
	}

	/**
	 * Parses a stage XML definition into the same structure as
	 * `assets/preload/stages/<stage>.json` (`data.StageData.StageFile`).
	 *
	 * Example:
	 * <stage>
	 *   <directory>week6</directory>
	 *   <default_zoom>1.05</default_zoom>
	 *   <is_pixel_stage>true</is_pixel_stage>
	 *   <stage_ui>normal</stage_ui>
	 *   <boyfriend>970,320</boyfriend>
	 *   <girlfriend>580,430</girlfriend>
	 *   <opponent>100,100</opponent>
	 *   <hide_girlfriend>false</hide_girlfriend>
	 *   <camera_speed>1</camera_speed>
	 * </stage>
	 */
	public static function parseStage(text:String):Dynamic
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			text = text.substr(1);
		var root = Xml.parse(text).firstElement();
		if (root == null) throw 'Stage XML has no root element';
		var fast = new Fast(root);

		var isPixelEl = child(fast, 'is_pixel_stage');
		var cameraSpeedEl = child(fast, 'camera_speed');

		return {
			directory: textOf(child(fast, 'directory')),
			defaultZoom: num(textOf(child(fast, 'default_zoom')), 0.9),
			isPixelStage: isPixelEl != null ? bool(textOf(isPixelEl)) : null,
			stageUI: textOf(child(fast, 'stage_ui'), 'normal'),
			boyfriend: floats(textOf(child(fast, 'boyfriend'))),
			girlfriend: floats(textOf(child(fast, 'girlfriend'))),
			opponent: floats(textOf(child(fast, 'opponent'))),
			hide_girlfriend: bool(textOf(child(fast, 'hide_girlfriend')), false),
			shaders: strings(textOf(child(fast, 'shaders'))),
			camera_boyfriend: floats(textOf(child(fast, 'camera_boyfriend'))),
			camera_opponent: floats(textOf(child(fast, 'camera_opponent'))),
			camera_girlfriend: floats(textOf(child(fast, 'camera_girlfriend'))),
			camera_speed: cameraSpeedEl != null ? num(textOf(cameraSpeedEl)) : null
		};
	}

	/**
	 * Parses a week XML definition into the same structure as
	 * `assets/preload/weeks/<week>.json` (`backend.WeekData.WeekFile`).
	 *
	 * Example:
	 * <week>
	 *   <week_background>stage</week_background>
	 *   <week_before>tutorial</week_before>
	 *   <story_name>Daddy Dearest</story_name>
	 *   <week_name>Week 1</week_name>
	 *   <start_unlocked>true</start_unlocked>
	 *   <songs>
	 *     <song>
	 *       <name>Bopeebo</name>
	 *       <character>dad</character>
	 *       <color>146,113,253</color>
	 *     </song>
	 *   </songs>
	 *   <week_characters>dad,bf,gf</week_characters>
	 *   <freeplay_color>146,113,253</freeplay_color>
	 * </week>
	 */
	public static function parseWeek(text:String):Dynamic
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			text = text.substr(1);
		var root = Xml.parse(text).firstElement();
		if (root == null) throw 'Week XML has no root element';
		var fast = new Fast(root);

		var songs:Array<Dynamic> = [];
		var songsEl = child(fast, 'songs');
		if (songsEl != null)
		{
			for (song in children(songsEl, 'song'))
			{
				var color = ints(textOf(child(song, 'color')));
				songs.push([
					textOf(child(song, 'name')),
					textOf(child(song, 'character')),
					color.length > 0 ? color : [146, 113, 253]
				]);
			}
		}

		var weekChars = strings(textOf(child(fast, 'week_characters')));
		if (weekChars.length == 0)
		{
			// Repeated <week_character> elements are also accepted.
			weekChars = [];
			for (c in children(fast, 'week_character')) weekChars.push(textOf(c));
		}

		var hiddenEl = child(fast, 'hidden_until_unlocked');
		var difficulties = textOf(child(fast, 'difficulties'));

		return {
			songs: songs,
			weekCharacters: weekChars,
			weekBackground: textOf(child(fast, 'week_background'), 'stage'),
			weekBefore: textOf(child(fast, 'week_before'), ''),
			storyName: textOf(child(fast, 'story_name'), ''),
			weekName: textOf(child(fast, 'week_name'), ''),
			freeplayColor: ints(textOf(child(fast, 'freeplay_color'))),
			startUnlocked: bool(textOf(child(fast, 'start_unlocked')), true),
			hiddenUntilUnlocked: hiddenEl != null ? bool(textOf(hiddenEl)) : null,
			hideStoryMode: bool(textOf(child(fast, 'hide_story_mode')), false),
			hideFreeplay: bool(textOf(child(fast, 'hide_freeplay')), false),
			difficulties: difficulties != '' ? difficulties : null
		};
	}

	/**
	 * Parses a dialogue XML definition into the same structure as a song's
	 * `dialogue.json` (`objects.DialogueBoxPsych.DialogueFile`).
	 *
	 * Example:
	 * <dialogue>
	 *   <line portrait="bf" expression="talk" box_state="normal" speed="0.05"
	 *       sound="dialogue">Hello, world!</line>
	 *   <line portrait="dad" expression="singLEFT">Dad line.</line>
	 * </dialogue>
	 */
	public static function parseDialogue(text:String):Dynamic
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			text = text.substr(1);
		var root = Xml.parse(text).firstElement();
		if (root == null) throw 'Dialogue XML has no root element';
		var fast = new Fast(root);

		var lines:Array<Dynamic> = [];
		for (line in children(fast, 'line'))
		{
			lines.push({
				portrait: attr(line, 'portrait'),
				expression: attr(line, 'expression'),
				text: text(line),
				boxState: attr(line, 'box_state'),
				speed: attrFloatNull(line, 'speed'),
				sound: attr(line, 'sound')
			});
		}

		return { dialogue: lines };
	}

	/**
	 * Parses a dialogue character XML definition into the same structure as
	 * `assets/preload/images/dialogue/<character>.json`
	 * (`objects.DialogueBoxPsych.DialogueCharacterFile`).
	 *
	 * Example:
	 * <dialogue_character>
	 *   <image>bf</image>
	 *   <dialogue_pos>left</dialogue_pos>
	 *   <no_antialiasing>false</no_antialiasing>
	 *   <position>0,0</position>
	 *   <scale>0.7</scale>
	 *   <animations>
	 *     <animation>
	 *       <anim>talk</anim>
	 *       <loop_name>talkLoop</loop_name>
	 *       <loop_offsets>0,0</loop_offsets>
	 *       <idle_name>talkIdle</idle_name>
	 *       <idle_offsets>0,0</idle_offsets>
	 *     </animation>
	 *   </animations>
	 * </dialogue_character>
	 */
	public static function parseDialogueCharacter(text:String):Dynamic
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			text = text.substr(1);
		var root = Xml.parse(text).firstElement();
		if (root == null) throw 'Dialogue character XML has no root element';
		var fast = new Fast(root);

		var anims:Array<Dynamic> = [];
		var animsEl = child(fast, 'animations');
		if (animsEl != null)
		{
			for (anim in children(animsEl, 'animation'))
			{
				anims.push({
					anim: textOf(child(anim, 'anim')),
					loop_name: textOf(child(anim, 'loop_name')),
					loop_offsets: ints(textOf(child(anim, 'loop_offsets'))),
					idle_name: textOf(child(anim, 'idle_name')),
					idle_offsets: ints(textOf(child(anim, 'idle_offsets')))
				});
			}
		}

		var position = floats(textOf(child(fast, 'position')));
		if (position.length == 0) position = [0, 0];

		return {
			image: textOf(child(fast, 'image')),
			dialogue_pos: textOf(child(fast, 'dialogue_pos'), 'left'),
			no_antialiasing: bool(textOf(child(fast, 'no_antialiasing')), false),
			animations: anims,
			position: position,
			scale: num(textOf(child(fast, 'scale')), 1)
		};
	}
}
