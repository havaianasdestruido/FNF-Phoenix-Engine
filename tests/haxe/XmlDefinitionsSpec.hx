import backend.XmlDefinitions;

/** Verifies the XML definitions for characters, stages, weeks, and dialogue. */
class XmlDefinitionsSpec
{
	static function equal(actual:Dynamic, expected:Dynamic, message:String):Void
	{
		if (actual != expected) throw message + ': expected ' + Std.string(expected) + ', got ' + Std.string(actual);
	}

	static function check(value:Bool, message:String):Void
	{
		if (!value) throw message;
	}

	static function main():Void
	{
		// ---------- Character ----------
		var charXml =
			'<character>' +
			'  characters/BOYFRIEND</image>' +
			'  <scale>1.5</scale>' +
			'  <sing_duration>4</sing_duration>' +
			'  <healthicon>bf</healthicon>' +
			'  <position>0,350</position>' +
			'  <camera_position>0,0</camera_position>' +
			'  <flip_x>true</flip_x>' +
			'  <no_antialiasing>false</no_antialiasing>' +
			'  <healthbar_colors>49,176,209</healthbar_colors>' +
			'  <vocals_file>bf</vocals_file>' +
			'  <editor_is_player>true</editor_is_player>' +
			'  <health_drain>true</health_drain>' +
			'  <drain_amount>0.03</drain_amount>' +
			'  <drain_floor>0.2</drain_floor>' +
			'  <shake_screen>true</shake_screen>' +
			'  <animations>' +
			'    <animation>' +
			'      <anim>idle</anim>' +
			'      <name>BF idle dance</name>' +
			'      <fps>24</fps>' +
			'      <loop>false</loop>' +
			'      <offsets>-5,-1</offsets>' +
			'    </animation>' +
			'    <animation>' +
			'      <anim>singLEFT</anim>' +
			'      <name>BF NOTE LEFT0</name>' +
			'      <fps>24</fps>' +
			'      <loop>false</loop>' +
			'      <offsets>5,-6</offsets>' +
			'    </animation>' +
			'    <animation>' +
			'      <anim>singDOWN</anim>' +
			'      <name>BF NOTE DOWN0</name>' +
			'      <fps>24</fps>' +
			'      <loop>false</loop>' +
			'      <offsetX>-20</offsetX>' +
			'      <offsetY>-51</offsetY>' +
			'      <indices>1,2,3</indices>' +
			'    </animation>' +
			'  </animations>' +
			'</character>';
		var character = XmlDefinitions.parseCharacter(charXml);
		equal(character.image, 'characters/BOYFRIEND', 'character image');
		check(character.scale == 1.5, 'character scale');
		equal(character.sing_duration, 4, 'character sing_duration');
		equal(character.healthicon, 'bf', 'character healthicon');
		equal(character.position.join(','), '0,350', 'character position');
		equal(character.camera_position.join(','), '0,0', 'character camera_position');
		check(character.flip_x == true, 'character flip_x');
		check(character.no_antialiasing == false, 'character no_antialiasing');
		equal(character.healthbar_colors.join(','), '49,176,209', 'character healthbar_colors');
		equal(character.vocals_file, 'bf', 'character vocals_file');
		check(character._editor_isPlayer == true, 'character editor_is_player');
		check(character.health_drain == true, 'character health_drain');
		check(character.drain_amount == 0.03, 'character drain_amount');
		check(character.drain_floor == 0.2, 'character drain_floor');
		check(character.shake_screen == true, 'character shake_screen');

		equal(character.animations.length, 3, 'character animation count');
		equal(character.animations[0].anim, 'idle', 'first animation anim');
		equal(character.animations[0].name, 'BF idle dance', 'first animation name');
		check(character.animations[0].fps == 24, 'first animation fps');
		check(character.animations[0].loop == false, 'first animation loop');
		equal(character.animations[0].offsets.join(','), '-5,-1', 'first animation offsets');
		equal(character.animations[1].offsets.join(','), '5,-6', 'second animation offsets');
		equal(character.animations[2].offsets.join(','), '-20,-51', 'third animation offsets via elements');
		equal(character.animations[2].indices.join(','), '1,2,3', 'third animation indices');

		// Defaults when elements are absent.
		var minimalChar = XmlDefinitions.parseCharacter('<character>characters/TEST</image></character>');
		equal(minimalChar.image, 'characters/TEST', 'minimal character image');
		check(minimalChar.scale == 1, 'minimal character scale default');
		equal(minimalChar.position.join(','), '0,0', 'minimal character position default');
		check(minimalChar._editor_isPlayer == null, 'minimal character editor_is_player default');

		// ---------- Stage ----------
		var stageXml =
			'<stage>' +
			'  <directory>week6</directory>' +
			'  <default_zoom>1.05</default_zoom>' +
			'  <is_pixel_stage>true</is_pixel_stage>' +
			'  <stage_ui>normal</stage_ui>' +
			'  <hide_girlfriend>false</hide_girlfriend>' +
			'  <camera_speed>1</camera_speed>' +
			'  <shaders>rain,glitch</shaders>' +
			'  <boyfriend>970,320</boyfriend>' +
			'  <girlfriend>580,430</girlfriend>' +
			'  <opponent>100,100</opponent>' +
			'  <camera_boyfriend>-100,-100</camera_boyfriend>' +
			'</stage>';
		var stage = XmlDefinitions.parseStage(stageXml);
		equal(stage.directory, 'week6', 'stage directory');
		check(stage.defaultZoom == 1.05, 'stage defaultZoom');
		check(stage.isPixelStage == true, 'stage isPixelStage');
		equal(stage.stageUI, 'normal', 'stage stageUI');
		equal(stage.boyfriend.join(','), '970,320', 'stage boyfriend');
		equal(stage.girlfriend.join(','), '580,430', 'stage girlfriend');
		equal(stage.opponent.join(','), '100,100', 'stage opponent');
		check(stage.hide_girlfriend == false, 'stage hide_girlfriend');
		equal(stage.shaders.join(','), 'rain,glitch', 'stage shaders');
		equal(stage.camera_boyfriend.join(','), '-100,-100', 'stage camera_boyfriend');
		check(stage.camera_speed == 1, 'stage camera_speed');

		var minimalStage = XmlDefinitions.parseStage('<stage><directory>stage</directory></stage>');
		equal(minimalStage.directory, 'stage', 'minimal stage directory');
		check(minimalStage.defaultZoom == 0.9, 'minimal stage defaultZoom default');
		check(minimalStage.isPixelStage == null, 'minimal stage isPixelStage null default');
		check(minimalStage.camera_speed == null, 'minimal stage camera_speed null default');

		// ---------- Week ----------
		var weekXml =
			'<week>' +
			'  <week_background>stage</week_background>' +
			'  <week_before>tutorial</week_before>' +
			'  <story_name>Daddy Dearest</story_name>' +
			'  <week_name>Week 1</week_name>' +
			'  <start_unlocked>true</start_unlocked>' +
			'  <hide_story_mode>false</hide_story_mode>' +
			'  <hide_freeplay>false</hide_freeplay>' +
			'  <songs>' +
			'    <song>' +
			'      <name>Bopeebo</name>' +
			'      <character>dad</character>' +
			'      <color>146,113,253</color>' +
			'    </song>' +
			'    <song>' +
			'      <name>Fresh</name>' +
			'      <character>dad</character>' +
			'      <color>146,113,253</color>' +
			'    </song>' +
			'  </songs>' +
			'  <week_characters>dad,bf,gf</week_characters>' +
			'  <freeplay_color>146,113,253</freeplay_color>' +
			'</week>';
		var week = XmlDefinitions.parseWeek(weekXml);
		equal(week.songs.length, 2, 'week song count');
		equal(week.songs[0][0], 'Bopeebo', 'week first song name');
		equal(week.songs[0][1], 'dad', 'week first song character');
		equal(week.songs[0][2].join(','), '146,113,253', 'week first song color');
		equal(week.weekCharacters.join(','), 'dad,bf,gf', 'week weekCharacters');
		equal(week.weekBackground, 'stage', 'week weekBackground');
		equal(week.weekBefore, 'tutorial', 'week weekBefore');
		equal(week.storyName, 'Daddy Dearest', 'week storyName');
		equal(week.weekName, 'Week 1', 'week weekName');
		equal(week.freeplayColor.join(','), '146,113,253', 'week freeplayColor');
		check(week.startUnlocked == true, 'week startUnlocked');
		check(week.hideStoryMode == false, 'week hideStoryMode');
		check(week.hideFreeplay == false, 'week hideFreeplay');
		check(week.hiddenUntilUnlocked == null, 'week hiddenUntilUnlocked null default');
		check(week.difficulties == null, 'week difficulties null default');

		// Repeated <week_character> elements are also accepted.
		var weekRepeated = XmlDefinitions.parseWeek(
			'<week week_name="Repeated">' +
			'<week_character>dad</week_character>' +
			'<week_character>bf</week_character>' +
			'</week>');
		equal(weekRepeated.weekCharacters.join(','), 'dad,bf', 'week repeated characters');

		// ---------- Dialogue ----------
		var dialogueXml =
			'<dialogue>' +
			'<line portrait="bf" expression="talk" box_state="normal" speed="0.05" sound="dialogue">Hello!</line>' +
			'<line portrait="dad" expression="singLEFT">Dad line.</line>' +
			'</dialogue>';
		var dialogue = XmlDefinitions.parseDialogue(dialogueXml);
		equal(dialogue.dialogue.length, 2, 'dialogue line count');
		equal(dialogue.dialogue[0].portrait, 'bf', 'dialogue first portrait');
		equal(dialogue.dialogue[0].expression, 'talk', 'dialogue first expression');
		equal(dialogue.dialogue[0].text, 'Hello!', 'dialogue first text');
		equal(dialogue.dialogue[0].boxState, 'normal', 'dialogue first boxState');
		check(dialogue.dialogue[0].speed == 0.05, 'dialogue first speed');
		equal(dialogue.dialogue[0].sound, 'dialogue', 'dialogue first sound');
		equal(dialogue.dialogue[1].portrait, 'dad', 'dialogue second portrait');
		equal(dialogue.dialogue[1].text, 'Dad line.', 'dialogue second text');
		check(dialogue.dialogue[1].speed == null, 'dialogue second speed null default');
		check(dialogue.dialogue[1].sound == null, 'dialogue second sound null default');

		// ---------- Dialogue character ----------
		var dcharXml =
			'<dialogue_character>' +
			'  characters/bf</image>' +
			'  <dialogue_pos>right</dialogue_pos>' +
			'  <no_antialiasing>false</no_antialiasing>' +
			'  <position>10,20</position>' +
			'  <scale>0.7</scale>' +
			'  <animations>' +
			'    <animation>' +
			'      <anim>talk</anim>' +
			'      <loop_name>talkLoop</loop_name>' +
			'      <loop_offsets>0,0</loop_offsets>' +
			'      <idle_name>talkIdle</idle_name>' +
			'      <idle_offsets>0,0</idle_offsets>' +
			'    </animation>' +
			'  </animations>' +
			'</dialogue_character>';
		var dchar = XmlDefinitions.parseDialogueCharacter(dcharXml);
		equal(dchar.image, 'bf', 'dialogue character image');
		equal(dchar.dialogue_pos, 'right', 'dialogue character dialogue_pos');
		check(dchar.no_antialiasing == false, 'dialogue character no_antialiasing');
		equal(dchar.position.join(','), '10,20', 'dialogue character position');
		check(dchar.scale == 0.7, 'dialogue character scale');
		equal(dchar.animations.length, 1, 'dialogue character animation count');
		equal(dchar.animations[0].anim, 'talk', 'dialogue character animation anim');
		equal(dchar.animations[0].loop_name, 'talkLoop', 'dialogue character animation loop_name');
		equal(dchar.animations[0].loop_offsets.join(','), '0,0', 'dialogue character animation loop_offsets');
		equal(dchar.animations[0].idle_name, 'talkIdle', 'dialogue character animation idle_name');
		equal(dchar.animations[0].idle_offsets.join(','), '0,0', 'dialogue character animation idle_offsets');

		trace('XmlDefinitionsSpec passed');
	}
}
