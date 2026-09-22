package flxanimate;

import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.FlxAnimate as OriginalFlxAnimate;
import flxanimate.data.AnimationData;
import flxanimate.frames.FlxAnimateFrames;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	/**
	 * Executes the `loadAtlasEx` operation.
	 * @param img Input value for `img`.
	 * @param pathOrStr Input value for `pathOrStr`.
	 * @param myJson Input value for `myJson`.
	 * @return Result produced by `loadAtlasEx`, when applicable.
	 */
	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animJson:AnimAtlas = null;
		if(myJson is String)
		{
			var trimmed:String = pathOrStr.trim();
			trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

			#if sys
			if(trimmed == '.json') myJson = File.getContent(myJson); //is a path
			#end
			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		var trimmed:String = pathOrStr.trim();
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		if(trimmed == '.json') //Path is json
		{
			#if sys
			myData = File.getContent(pathOrStr);
			#else
			myData = Assets.getText(pathOrStr);
			#end
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			#if sys
			myData = File.getContent(pathOrStr);
			#else
			myData = Assets.getText(pathOrStr);
			#end
			isXml = true;
		}
		myData = _removeBOM(myData);

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		anim._loadAtlas(animJson);
		if(!isXml) frames = FlxAnimateFrames.fromSpriteMap(cast myData, img);
		else frames = FlxAnimateFrames.fromSparrow(cast myData, img);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	/**
	 * Executes the `draw` operation.
	 * @return Result produced by `draw`, when applicable.
	 */
	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		super.draw();
	}

	/**
	 * Executes the `destroy` operation.
	 * @return Result produced by `destroy`, when applicable.
	 */
	override function destroy()
	{
		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.curInstance = FlxDestroyUtil.destroy(anim.curInstance);
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			//anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
			anim.metadata.destroy();
			anim.symbolDictionary = null;
		}
	}

	/**
	 * Executes the `_removeBOM` operation.
	 * @param str Input value for `str`.
	 * @return Result produced by `_removeBOM`, when applicable.
	 */
	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	/**
	 * Executes the `pauseAnimation` operation.
	 * @return Result produced by `pauseAnimation`, when applicable.
	 */
	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	/**
	 * Executes the `resumeAnimation` operation.
	 * @return Result produced by `resumeAnimation`, when applicable.
	 */
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}
