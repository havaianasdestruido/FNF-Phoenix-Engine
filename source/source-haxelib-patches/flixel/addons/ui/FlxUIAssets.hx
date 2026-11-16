/*
 * PATCHED COPY of flixel-ui's flixel/addons/ui/FlxUIAssets.hx (flixel-ui 2.6.0,
 * the version pinned in hmm.json).
 *
 * source/source-haxelib-patches sits ahead of the haxelibs on the classpath
 * (project.hxp pushes it after "source"; haxelib paths come last), so this file
 * replaces the haxelib's for every compile -- the same mechanism already used
 * for FlxInputText, FlxSlider, FlxUIDropDownMenu and FlxUIInputText below.
 *
 * WHY IT EXISTS
 * The dark editor skin in assets/flixel-ui-dark/ (ported from FNF-Troll-Engine)
 * has to reach flixel-ui's *own* widgets, not just the engine's: FlxUI9SliceSprite
 * defaults to IMG_CHROME, FlxUITypedButton to IMG_BUTTON, FlxUIDropDownMenu to
 * IMG_BOX. Every one of them loads its graphic through these constants and
 * Assets.getBitmapData(), so repointing the constants is the single place that
 * re-skins the haxelib's widgets and ours alike.
 *
 * WHY NOT JUST REUSE flixel-ui's ASSET IDS
 * Registering the dark PNGs under "flixel/flixel-ui/img/..." looks like the
 * obvious override, and it is not. flixel-ui's own include.xml already registers
 * assets/images renamed to exactly that path, and Lime merges haxelib assets
 * only *after* project.hxp has run (HXProject.fromFile -> processHaxelibs ->
 * merge, which concatenates without deduplicating), so project.hxp cannot remove
 * or replace the earlier entry. An embedded build then generates one
 * `__ASSET__flixel_flixel_ui_img_*` class per registration and the Haxe compile
 * fails with "Name __ASSET__... is already defined in this module" -- which is
 * what broke the Windows build when this skin was first added.
 *
 * SCOPE
 * Only the 14 constants whose image assets/flixel-ui-dark/ replaces are
 * repointed. tab_over.png and tab_back_over.png ship in that folder but no
 * constant in flixel-ui 2.6.0 names them (FlxUITabMenu uses IMG_TAB and
 * IMG_TAB_BACK for all six tab states), so they stay registered and unreferenced
 * until a flixel-ui that asks for them. The remaining constants (IMG_BOX,
 * IMG_CHROME_LIGHT, IMG_CHROME_INSET, IMG_HILIGHT, IMG_INVIS, IMG_SWATCH,
 * IMG_TOOLTIP_ARROW, IMG_FINGER_*, the IMG_BUTTON_ARROW_* set) keep flixel-ui's
 * id and therefore the haxelib's original art: drop a dark PNG into
 * assets/flixel-ui-dark/ and repoint its line here to re-skin one of those too.
 *
 * Keep this copy in sync with the pinned flixel-ui version: if the haxelib gains
 * a constant, this file has to gain it too, or the widget using it stops
 * compiling.
 */
package flixel.addons.ui;

class FlxUIAssets
{
	// images
	public static inline var IMG_BUTTON:String = "assets/flixel-ui-dark/button.png";
	public static inline var IMG_BUTTON_ARROW_DOWN:String = "flixel/flixel-ui/img/button_arrow_down.png";
	public static inline var IMG_BUTTON_ARROW_LEFT:String = "flixel/flixel-ui/img/button_arrow_left.png";
	public static inline var IMG_BUTTON_ARROW_RIGHT:String = "flixel/flixel-ui/img/button_arrow_right.png";
	public static inline var IMG_BUTTON_ARROW_UP:String = "flixel/flixel-ui/img/button_arrow_up.png";
	public static inline var IMG_BUTTON_THIN:String = "assets/flixel-ui-dark/button_thin.png";
	public static inline var IMG_BUTTON_TOGGLE:String = "assets/flixel-ui-dark/button_toggle.png";

	public static inline var IMG_BUTTON_SIZE:Int = 18; // each of the above buttons is 18x18

	public static inline var IMG_CHECK_MARK:String = "assets/flixel-ui-dark/check_mark.png";
	public static inline var IMG_CHECK_BOX:String = "assets/flixel-ui-dark/check_box.png";
	public static inline var IMG_CHROME:String = "assets/flixel-ui-dark/chrome.png";
	public static inline var IMG_CHROME_LIGHT:String = "flixel/flixel-ui/img/chrome_light.png";
	public static inline var IMG_CHROME_FLAT:String = "assets/flixel-ui-dark/chrome_flat.png";
	public static inline var IMG_CHROME_INSET:String = "flixel/flixel-ui/img/chrome_inset.png";
	public static inline var IMG_RADIO:String = "assets/flixel-ui-dark/radio.png";
	public static inline var IMG_RADIO_DOT:String = "assets/flixel-ui-dark/radio_dot.png";
	public static inline var IMG_TAB:String = "assets/flixel-ui-dark/tab.png";
	public static inline var IMG_TAB_BACK:String = "assets/flixel-ui-dark/tab_back.png";
	public static inline var IMG_BOX:String = "flixel/flixel-ui/img/box.png";
	public static inline var IMG_DROPDOWN:String = "assets/flixel-ui-dark/dropdown_mark.png";
	public static inline var IMG_PLUS:String = "assets/flixel-ui-dark/plus_mark.png";
	public static inline var IMG_MINUS:String = "assets/flixel-ui-dark/minus_mark.png";
	public static inline var IMG_HILIGHT:String = "flixel/flixel-ui/img/hilight.png";
	public static inline var IMG_INVIS:String = "flixel/flixel-ui/img/invis.png";
	public static inline var IMG_SWATCH:String = "flixel/flixel-ui/img/swatch.png";
	public static inline var IMG_TOOLTIP_ARROW:String = "flixel/flixel-ui/img/tooltip_arrow.png";

	public static inline var IMG_FINGER_SMALL:String = "flixel/flixel-ui/img/finger_small.png";
	public static inline var IMG_FINGER_BIG:String = "flixel/flixel-ui/img/finger_big.png";

	// slice9 rules
	public static inline var SLICE9_BUTTON:String = "6,6,11,11";
	public static inline var SLICE9_BUTTON_THIN:String = "2,2,15,15";
	public static inline var SLICE9_BUTTON_TOGGLE:String = "6,6,11,11";
	public static inline var SLICE9_TAB:String = "6,6,11,11";

	// xml (default definitions)
	public static inline var XML_DEFAULTS_ID:String = "flixel/flixel-ui/xml/defaults";
	public static inline var XML_DEFAULT_POPUP_ID:String = "flixel/flixel-ui/xml/default_popup";
	public static inline var XML_DEFAULT_LOADING_SCREEN_ID:String = "flixel/flixel-ui/xml/default_loading_screen";

	public static var index_size:Map<String, Array<Float>> = null;
}
