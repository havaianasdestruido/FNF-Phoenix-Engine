package options;

import flixel.input.FlxInput;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

import backend.ClientPrefs;
import backend.Controls;
import backend.HardwareKeys;
import backend.InputFormatter;
import backend.MusicBeatSubstate;
#if android
import android.platform.AndroidHardwareInput;
#end
import objects.Alphabet;
import objects.AttachedText;

class ControlsSubState extends MusicBeatSubstate {
	private static var curSelected:Int = 1;
	private static var curAlt:Bool = false;

	private static var defaultKey:String = 'Reset to Default Keys';
	private var bindLength:Int = 0;

	var menuOptions:Array<Dynamic> = [
		['GAMEPLAY'],
		['Left', 'note_left'],
		['Down', 'note_down'],
		['Up', 'note_up'],
		['Right', 'note_right'],
		['Taunt', 'taunt'],
		['Use BE', 'bot_energy'],
		[''],
		['UI'],
		['Left', 'ui_left'],
		['Down', 'ui_down'],
		['Up', 'ui_up'],
		['Right', 'ui_right'],
		[''],
		['Reset', 'reset'],
		['Accept', 'accept'],
		['Back', 'back'],
		['Pause', 'pause'],
		[''],
		['VOLUME'],
		['Mute', 'volume_mute'],
		['Up', 'volume_up'],
		['Down', 'volume_down'],
		[''],
		['DEBUG'],
		['Key 1', 'debug_1'],
		['Key 2', 'debug_2']
	];

	#if android
	// Android only: volume buttons as note lanes. Rows start unbound; the section is opt-in per button.
	static final HARDWARE_NOTE:String = 'Volume buttons play notes only during gameplay. Menus keep normal volume.';
	static final HARDWARE_CAPTURE_NOTE:String = 'Press a volume button (Backspace clears). Volume keys are captured for 5s.';
	var hardwareOptions:Array<Dynamic> = [
		['HARDWARE'],
		['Left', 'hw_note_left'],
		['Down', 'hw_note_down'],
		['Up', 'hw_note_up'],
		['Right', 'hw_note_right']
	];
	#end

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var grpInputs:Array<AttachedText> = [];
	private var grpInputsAlt:Array<AttachedText> = [];
	var rebindingKey:Bool = false;
	var nextAccept:Int = 5;

	#if android
	// Hardware capture: AndroidHardwareInput delivers the pressed trigger while a HARDWARE row is being rebound.
	var hardwareNote:FlxText = null;
	var hardwareKeyListener:Int->Bool->Void = null;
	var pendingHardwareKey:Int = -1;
	var capturingHardware:Bool = false;
	#end

	public function new() {
		super();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		#if android
		menuOptions.push(['']);
		for (option in hardwareOptions)
			menuOptions.push(option);
		#end
		menuOptions.push(['']);
		menuOptions.push([defaultKey]);

		for (i in 0...menuOptions.length) {
			var isCentered:Bool = false;
			var isDefaultKey:Bool = (menuOptions[i][0] == defaultKey);
			if(unselectableCheck(i, true)) {
				isCentered = true;
			}

			var optionText:Alphabet = new Alphabet(200, 300, menuOptions[i][0], (!isCentered || isDefaultKey));
			optionText.isMenuItem = true;
			if(isCentered) {
				optionText.screenCenter(X);
				optionText.y -= 55;
				optionText.startPosition.y -= 55;
			}
			optionText.changeX = false;
			optionText.distancePerItem.y = 60;
			optionText.targetY = i - curSelected;
			optionText.snapToPosition();
			grpOptions.add(optionText);

			if(!isCentered) {
				addBindTexts(optionText, i);
				bindLength++;
				if(curSelected < 0) curSelected = i;
			}
		}
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		changeSelection();

		addVirtualPad(LEFT_FULL, A_B);

		#if android
		if (hasHardwareRows()) {
			hardwareNote = new FlxText(0, FlxG.height - 60, FlxG.width, HARDWARE_NOTE, 22);
			hardwareNote.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, FlxTextAlign.CENTER);
			hardwareNote.scrollFactor.set();
			add(hardwareNote);
		}
		hardwareKeyListener = onHardwareKeyCaptured;
		AndroidHardwareInput.onKey.add(hardwareKeyListener);
		#end
	}

	#if android
	function hasHardwareRows():Bool
	{
		for (option in menuOptions)
			if (option.length > 1 && isHardwareBind(option[1]))
				return true;
		return false;
	}

	static function isHardwareBind(name:String):Bool
		return name != null && StringTools.startsWith(name, 'hw_');

	function onHardwareKeyCaptured(keyCode:Int, down:Bool):Void
	{
		if (down && capturingHardware)
			pendingHardwareKey = keyCode;
	}

	function startHardwareCapture():Void
	{
		capturingHardware = true;
		pendingHardwareKey = -1;
		AndroidHardwareInput.enableVolumeKeys();
		if (hardwareNote != null)
			hardwareNote.text = HARDWARE_CAPTURE_NOTE;
	}

	function stopHardwareCapture():Void
	{
		if (capturingHardware)
		{
			capturingHardware = false;
			AndroidHardwareInput.disableVolumeKeys();
		}
		if (hardwareNote != null)
			hardwareNote.text = HARDWARE_NOTE;
	}

	override function destroy():Void
	{
		stopHardwareCapture();
		AndroidHardwareInput.onKey.remove(hardwareKeyListener);
		super.destroy();
	}
	#end

	var leaving:Bool = false;
	var bindingTime:Float = 0;
	override function update(elapsed:Float) {
		if(!rebindingKey) {
			if (controls.UI_UP_P) {
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
			}
			if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
				changeAlt();
			}

			if (controls.BACK) {
				ClientPrefs.reloadControls();
				close();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}

			if(controls.ACCEPT && nextAccept <= 0) {
				if(menuOptions[curSelected][0] == defaultKey) {
					ClientPrefs.keyBinds = ClientPrefs.defaultKeys.copy();
					reloadKeys();
					changeSelection();
					FlxG.sound.play(Paths.sound('confirmMenu'));
				} else if(!unselectableCheck(curSelected)) {
					bindingTime = 0;
					rebindingKey = true;
					if (curAlt) {
						grpInputsAlt[getInputTextNum()].alpha = 0.0001;
					} else {
						grpInputs[getInputTextNum()].alpha = 0.0001;
					}
					#if android
					if (isHardwareBind(menuOptions[curSelected][1]))
						startHardwareCapture();
					#end
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
			}
		} else {
			var bound:Bool = false;
			#if android
			if (capturingHardware) {
				if (FlxG.keys.checkStatus(BACKSPACE, JUST_PRESSED)) {
					// Qualified: this file imports flixel.text.FlxText, and
					// FlxTextBorderStyle.NONE shadows the bare NONE here.
					setBindSlot(FlxKey.NONE);
					bound = true;
				} else if (pendingHardwareKey > -1) {
					setBindSlot(HardwareKeys.toBind(pendingHardwareKey));
					bound = true;
				}
			} else
			#end
			{
				var keyPressed:Int = FlxG.keys.firstJustPressed();
				if (keyPressed > -1) {
					setBindSlot(keyPressed);
					bound = true;
				}
			}

			if (bound) {
				reloadKeys();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				rebindingKey = false;
				#if android
				stopHardwareCapture();
				#end
			}

			bindingTime += elapsed;
			if(bindingTime > 5) {
				if (curAlt) {
					grpInputsAlt[getInputTextNum()].alpha = 1;
				} else {
					grpInputs[getInputTextNum()].alpha = 1;
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
				rebindingKey = false;
				bindingTime = 0;
				#if android
				stopHardwareCapture();
				#end
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	/** Writes the key into the slot being rebound; the other slot is cleared if it became a duplicate. */
	function setBindSlot(key:Int):Void {
		var keysArray:Array<FlxKey> = ClientPrefs.keyBinds.get(menuOptions[curSelected][1]);
		keysArray[curAlt ? 1 : 0] = key;

		var opposite:Int = (curAlt ? 0 : 1);
		if(keysArray[opposite] == keysArray[1 - opposite]) {
			keysArray[opposite] = FlxKey.NONE;
		}
		ClientPrefs.keyBinds.set(menuOptions[curSelected][1], keysArray);
	}

	function getInputTextNum() {
		var num:Int = 0;
		for (i in 0...curSelected) {
			if(menuOptions[i].length > 1) {
				num++;
			}
		}
		return num;
	}

	function changeSelection(change:Int = 0) {
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = menuOptions.length - 1;
			if (curSelected >= menuOptions.length)
				curSelected = 0;
		} while(unselectableCheck(curSelected));

		var selectionIndex:Int = 0;

		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}
		for (i in 0...grpInputsAlt.length) {
			grpInputsAlt[i].alpha = 0.6;
		}

		for (item in grpOptions.members) {
			item.targetY = selectionIndex - curSelected;
			selectionIndex++;

			if(!unselectableCheck(selectionIndex-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
					if(curAlt) {
						for (i in 0...grpInputsAlt.length) {
							if(grpInputsAlt[i].sprTracker == item) {
								grpInputsAlt[i].alpha = 1;
								break;
							}
						}
					} else {
						for (i in 0...grpInputs.length) {
							if(grpInputs[i].sprTracker == item) {
								grpInputs[i].alpha = 1;
								break;
							}
						}
					}
				}
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeAlt() {
		curAlt = !curAlt;
		for (i in 0...grpInputs.length) {
			if(grpInputs[i].sprTracker == grpOptions.members[curSelected]) {
				grpInputs[i].alpha = 0.6;
				if(!curAlt) {
					grpInputs[i].alpha = 1;
				}
				break;
			}
		}
		for (i in 0...grpInputsAlt.length) {
			if(grpInputsAlt[i].sprTracker == grpOptions.members[curSelected]) {
				grpInputsAlt[i].alpha = 0.6;
				if(curAlt) {
					grpInputsAlt[i].alpha = 1;
				}
				break;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	private function unselectableCheck(num:Int, ?checkDefaultKey:Bool = false):Bool {
		if(menuOptions[num][0] == defaultKey) {
			return checkDefaultKey;
		}
		return menuOptions[num].length < 2 && menuOptions[num][0] != defaultKey;
	}

	private function addBindTexts(optionText:Alphabet, num:Int) {
		var keys:Array<Dynamic> = ClientPrefs.keyBinds.get(menuOptions[num][1]);
		var text1 = new AttachedText(InputFormatter.getKeyName(keys[0]), 400, -55);
		text1.setPosition(optionText.x + 400, optionText.y - 55);
		text1.sprTracker = optionText;
		grpInputs.push(text1);
		add(text1);

		var text2 = new AttachedText(InputFormatter.getKeyName(keys[1]), 650, -55);
		text2.setPosition(optionText.x + 650, optionText.y - 55);
		text2.sprTracker = optionText;
		grpInputsAlt.push(text2);
		add(text2);
	}

	function reloadKeys() {
		while(grpInputs.length > 0) {
			var item:AttachedText = grpInputs[0];
			item.kill();
			grpInputs.remove(item);
			item.destroy();
		}
		while(grpInputsAlt.length > 0) {
			var item:AttachedText = grpInputsAlt[0];
			item.kill();
			grpInputsAlt.remove(item);
			item.destroy();
		}

		trace('Reloaded keys: ' + ClientPrefs.keyBinds);

		for (i in 0...grpOptions.length) {
			if(!unselectableCheck(i, true)) {
				addBindTexts(grpOptions.members[i], i);
			}
		}


		var selectionIndex:Int = 0;
		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}
		for (i in 0...grpInputsAlt.length) {
			grpInputsAlt[i].alpha = 0.6;
		}

		for (item in grpOptions.members) {
			item.targetY = selectionIndex - curSelected;
			selectionIndex++;

			if(!unselectableCheck(selectionIndex-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
					if(curAlt) {
						for (i in 0...grpInputsAlt.length) {
							if(grpInputsAlt[i].sprTracker == item) {
								grpInputsAlt[i].alpha = 1;
							}
						}
					} else {
						for (i in 0...grpInputs.length) {
							if(grpInputs[i].sprTracker == item) {
								grpInputs[i].alpha = 1;
							}
						}
					}
				}
			}
		}
	}
}
