package psychlua.callbacks;

import backend.Paths;
import play.PlayState;
import psychlua.FunkinLua;

class SoundCallbacks
{
	public static function register(funk:FunkinLua):Void {
		@:privateAccess {
		FunkinLua.registerFunction("playMusic", function(sound:String, volume:Float = 1, loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		FunkinLua.registerFunction("playSound", function(sound:String, volume:Float = 1, ?tag:String = null) {
			if(tag != null && tag.length > 0) {
				tag = tag.replace('.', '');
				if(PlayState.instance.modchartSounds.exists(tag)) {
					PlayState.instance.modchartSounds.get(tag).stop();
				}
				PlayState.instance.modchartSounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, false, null, true, function() {
					PlayState.instance.modchartSounds.remove(tag);
					PlayState.instance.callOnLuas('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
		});
		FunkinLua.registerFunction("stopSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).stop();
				PlayState.instance.modchartSounds.remove(tag);
			}
		});
		FunkinLua.registerFunction("pauseSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).pause();
			}
		});
		FunkinLua.registerFunction("resumeSound", function(tag:String) {
			if(tag != null && tag.length > 1 && PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).play();
			}
		});
		FunkinLua.registerFunction("soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeIn(duration / PlayState.instance.playbackRate, fromValue, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeIn(duration / PlayState.instance.playbackRate, fromValue, toValue);
			}

		});
		FunkinLua.registerFunction("soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeOut(duration / PlayState.instance.playbackRate, toValue);
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).fadeOut(duration / PlayState.instance.playbackRate, toValue);
			}
		});
		FunkinLua.registerFunction("soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					PlayState.instance.modchartSounds.remove(tag);
				}
			}
		});
		FunkinLua.registerFunction("getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).volume;
			}
			return 0;
		});
		FunkinLua.registerFunction("setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			} else if(PlayState.instance.modchartSounds.exists(tag)) {
				PlayState.instance.modchartSounds.get(tag).volume = value;
			}
		});
		FunkinLua.registerFunction("getSoundTime", function(tag:String) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				return PlayState.instance.modchartSounds.get(tag).time;
			}
			return 0;
		});
		FunkinLua.registerFunction("setSoundTime", function(tag:String, value:Float) {
			if(tag != null && tag.length > 0 && PlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = PlayState.instance.modchartSounds.get(tag);
				if(theSound != null) {
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;
					if(wasResumed) theSound.play();
				}
			}
		});
		// Chart-declared extra vocal stems (docs/EXTRA_VOCALS.md), addressed by
		// the `name` the chart gave each stem. All of these are safe no-ops when
		// the song has no extra stems or the Extra Vocal Stems option is off.
		FunkinLua.registerFunction("getExtraVocalNames", function() {
			if(PlayState.instance == null) return [];
			return play.helpers.PlayStateExtraVocals.names(PlayState.instance.extraVocals);
		});
		FunkinLua.registerFunction("setExtraVocalVolume", function(name:String, value:Float) {
			final track = PlayState.instance == null ? null : play.helpers.PlayStateExtraVocals.find(PlayState.instance.extraVocals, name);
			if(track == null || track.sound == null) return false;
			track.sound.volume = value;
			return true;
		});
		FunkinLua.registerFunction("getExtraVocalVolume", function(name:String) {
			final track = PlayState.instance == null ? null : play.helpers.PlayStateExtraVocals.find(PlayState.instance.extraVocals, name);
			return (track == null || track.sound == null) ? 0 : track.sound.volume;
		});
		FunkinLua.registerFunction("setExtraVocalPitch", function(name:String, value:Float) {
			#if FLX_PITCH
			final track = PlayState.instance == null ? null : play.helpers.PlayStateExtraVocals.find(PlayState.instance.extraVocals, name);
			if(track == null || track.sound == null) return false;
			track.sound.pitch = value;
			return true;
			#else
			return false;
			#end
		});
		FunkinLua.registerFunction("getExtraVocalPitch", function(name:String) {
			#if FLX_PITCH
			final track = PlayState.instance == null ? null : play.helpers.PlayStateExtraVocals.find(PlayState.instance.extraVocals, name);
			return (track == null || track.sound == null) ? 1 : track.sound.pitch;
			#else
			return 1;
			#end
		});
		}
	}
}
