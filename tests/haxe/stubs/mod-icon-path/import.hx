// Minimal stand-in for source/import.hx: only the imports/aliases that
// backend/Paths.hx relies on, so the real Paths.hx compiles against the tiny
// stubs in this directory without the game's Flixel/OpenFL haxelibs.
#if !macro
import backend.Paths;
#if sys
import sys.*;
import sys.io.*;
#end
#if MODS_ALLOWED
import backend.Mods;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import haxe.Json;
import utils.*;
using StringTools;
#end
