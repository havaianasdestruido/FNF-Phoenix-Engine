package psychlua.callbacks;

import backend.MusicBeatState;
import objects.StrumNote;
import play.PlayState;
import psychlua.FunkinLua;
import headers.PsychLua;
import psychlua.FunkinLua.LuaTweenOptions;
import psychlua.TweenValueValidation;

class TweenCallbacks
{
	static final rejectedTweenWarnings:Map<String, Bool> = new Map();

	static function sanitizeTweenValues(funk:FunkinLua, callback:String, tag:String, target:Dynamic, values:Dynamic):Dynamic
	{
		final sanitized:Dynamic = TweenValueValidation.sanitize(target, values);
		if (sanitized == null)
		{
			final key:String = funk.scriptName + '|' + callback;
			if (!rejectedTweenWarnings.exists(key))
			{
				rejectedTweenWarnings.set(key, true);
				final tagInfo:String = tag == null ? '' : ' (tag "$tag")';
				LuaUtils.luaTrace(funk.lua, '$callback: skipped a tween with a non-numeric or non-finite property$tagInfo', false, false, FlxColor.RED);
			}
		}
		return sanitized;
	}

	public static function register(funk:FunkinLua):Void {
		@:privateAccess {
		// Tween callbacks
		FunkinLua.registerFunction("startTween", function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null)
			{
				if(values != null)
				{
					final tweenValues:Dynamic = sanitizeTweenValues(funk, 'startTween', tag, penisExam, values);
					if (tweenValues == null) return null;
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if(tag != null)
					{
						var variables = MusicBeatState.getVariables();
						var originalTag:String = 'tween_' + tag.trim().replace(' ', '_').replace('.', '');
						variables.set(tag, FlxTween.tween(penisExam, tweenValues, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
	
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) PlayState.instance.callOnLuas(myOptions.onUpdate, [originalTag, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) PlayState.instance.callOnLuas(myOptions.onStart, [originalTag, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tag);
								if(myOptions.onComplete != null) PlayState.instance.callOnLuas(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					}
					else FlxTween.tween(penisExam, tweenValues, duration, myOptions != null ? {
						type: myOptions.type,
						ease: myOptions.ease,
						startDelay: myOptions.startDelay,
						loopDelay: myOptions.loopDelay,

						onUpdate: function(twn:FlxTween) {
							if(myOptions.onUpdate != null) PlayState.instance.callOnLuas(myOptions.onUpdate, [null, vars]);
						},
						onStart: function(twn:FlxTween) {
							if(myOptions.onStart != null) PlayState.instance.callOnLuas(myOptions.onStart, [null, vars]);
						},
						onComplete: function(twn:FlxTween) {
							if(myOptions.onComplete != null) PlayState.instance.callOnLuas(myOptions.onComplete, [null, vars]);
						}
					} : null);
				}
				else LuaUtils.luaTrace(funk.lua, 'startTween: No values on 2nd argument!', false, false, FlxColor.RED);
			}
			else LuaUtils.luaTrace(funk.lua, 'startTween: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			return null;
		});

		FunkinLua.registerFunction("doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'doTweenX', tag, penisExam, {x: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenX | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		FunkinLua.registerFunction("doTweenScale", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'doTweenScale', tag, penisExam, {"scale.x": value,"scale.y": value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenScale | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		FunkinLua.registerFunction("doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'doTweenY', tag, penisExam, {y: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenY | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		FunkinLua.registerFunction("doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'doTweenAngle', tag, penisExam, {angle: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenAngle | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		FunkinLua.registerFunction("doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'doTweenAlpha', tag, penisExam, {alpha: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenAlpha | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		FunkinLua.registerFunction("doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				if(vars == 'camHud' || vars == 'camGame' || vars == 'Hud' || vars == 'Game') {
					final tweenValues:Dynamic = sanitizeTweenValues(funk, 'doTweenZoom', tag, penisExam, {zoom: value});
					if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
							PlayState.instance.modchartTweens.remove(tag);
						}
					}));
				}
				else
				{
					LuaUtils.luaTrace(funk.lua, "doTweenZoom | Can't tween object " + vars + ". Value needs to be a camera.", false, false, FlxColor.RED);
				}
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenZoom | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		FunkinLua.registerFunction("doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = funk.tweenPrepare(tag, vars);
			if(penisExam != null) {
				if (targetColor == null) {
					LuaUtils.luaTrace(funk.lua, 'doTweenColor: skipped a tween with an invalid color', false, false, FlxColor.RED);
					return;
				}
				var color:Null<Int> = Std.parseInt(targetColor);
				if(!targetColor.startsWith('0x')) color = Std.parseInt('0xff' + targetColor);
				if (color == null) {
					LuaUtils.luaTrace(funk.lua, 'doTweenColor: skipped a tween with an invalid color', false, false, FlxColor.RED);
					return;
				}

				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				PlayState.instance.modchartTweens.set(tag, FlxTween.color(penisExam, duration / PlayState.instance.playbackRate, curColor, color, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.modchartTweens.remove(tag);
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
					}
				}));
			} else {
				LuaUtils.luaTrace(funk.lua, 'doTweenColor | Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});

		// Tween helpers for strums
		FunkinLua.registerFunction("noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenX', tag, testicle, {x: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenY', tag, testicle, {y: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenAngle', tag, testicle, {angle: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenDirection', tag, testicle, {direction: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("mouseClicked", function(button:String) {
			var mouseState = FlxG.mouse.justPressed;
			switch(button){
				case 'middle':
					mouseState = FlxG.mouse.justPressedMiddle;
				case 'right':
					mouseState = FlxG.mouse.justPressedRight;
			}


			return mouseState;
		});
		FunkinLua.registerFunction("mousePressed", function(button:String) {
			var mouseState = FlxG.mouse.pressed;
			switch(button){
				case 'middle':
					mouseState = FlxG.mouse.pressedMiddle;
				case 'right':
					mouseState = FlxG.mouse.pressedRight;
			}
			return mouseState;
		});
		FunkinLua.registerFunction("mouseReleased", function(button:String) {
			var mouseState = FlxG.mouse.justReleased;
			switch(button){
				case 'middle':
					mouseState = FlxG.mouse.justReleasedMiddle;
				case 'right':
					mouseState = FlxG.mouse.justReleasedRight;
			}
			return mouseState;
		});
		FunkinLua.registerFunction("noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenAngle', tag, testicle, {angle: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("noteTweenAlpha", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenAlpha', tag, testicle, {alpha: value});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration / PlayState.instance.playbackRate, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("noteTweenScaleX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final scaleValue:Null<Float> = TweenValueValidation.finiteNumber(value);
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenScaleX', tag, testicle, {"scale.x": scaleValue == null ? value : scaleValue * 0.7});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		FunkinLua.registerFunction("noteTweenScaleY", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String) {
			funk.cancelTween(tag);
			if(note < 0) note = 0;
			var testicle:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];

			if(testicle != null) {
				final scaleValue:Null<Float> = TweenValueValidation.finiteNumber(value);
				final tweenValues:Dynamic = sanitizeTweenValues(funk, 'noteTweenScaleY', tag, testicle, {"scale.y": scaleValue == null ? value : scaleValue * 0.7});
				if (tweenValues != null) PlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, tweenValues, duration, {ease: LuaUtils.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						PlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						PlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});

		FunkinLua.registerFunction("cancelTween", function(tag:String) {
			funk.cancelTween(tag);
		});

		FunkinLua.registerFunction("runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			funk.cancelTimer(tag);
			PlayState.instance.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) {
					PlayState.instance.modchartTimers.remove(tag);
				}
				PlayState.instance.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
		});
		FunkinLua.registerFunction("cancelTimer", function(tag:String) {
			funk.cancelTimer(tag);
		});

		/*FunkinLua.registerFunction("getPropertyAdvanced", function(varsStr:String) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = LuaUtils.resolveClassCompat(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.getProperty(curProp, variables[variables.length-1]);
			} else if(variables.length == 2) {
				return Reflect.getProperty(leClass, variables[variables.length-1]);
			}
			return null;
		});
		FunkinLua.registerFunction("setPropertyAdvanced", function(varsStr:String, value:Dynamic) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = LuaUtils.resolveClassCompat(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.setProperty(curProp, variables[variables.length-1], value);
			} else if(variables.length == 2) {
				return Reflect.setProperty(leClass, variables[variables.length-1], value);
			}
		});*/
		}
	}
}

