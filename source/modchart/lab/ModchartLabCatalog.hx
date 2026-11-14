package modchart.lab;

import modchart.ModifierRegistry;
import modchart.PercentStore;
import modchart.lab.LabKnob;
import modchart.lab.LabModifier;

/**
 * Metadata for the Modchart Lab (`editors.ModchartLabState`): which percents
 * each modifier exposes, plus a usable slider range and the value the
 * modifier starts with.
 *
 * The core stays renderer-free, so this table is data only and is covered by
 * `tests/haxe/run-modchart-lab.sh` — it is cross-checked against
 * `ModifierRegistry.names()` so a new modifier cannot ship without a knob
 * definition.
 */
class ModchartLabCatalog
{
	static var entries:Array<LabModifier> = null;
	static var byName:Map<String, LabModifier> = null;

	/**
	 * Every modifier, in registry order (alphabetical, lowercase names).
	 *
	 * @return The shared table; read it, do not mutate it.
	 */
	public static function all():Array<LabModifier>
	{
		ensure();
		return entries;
	}

	/**
	 * Looks a modifier up by name, case-insensitively.
	 *
	 * @param name Registry name.
	 * @return The entry, or `null` when the modifier is unknown.
	 */
	public static function find(name:String):LabModifier
	{
		ensure();
		return byName.get(PercentStore.normalize(name));
	}

	/**
	 * The draggable percents of a modifier.
	 *
	 * @param name Registry name.
	 * @return The knob list, or an empty array for an unknown modifier.
	 */
	public static function knobs(name:String):Array<LabKnob>
	{
		final entry:LabModifier = find(name);
		return entry == null ? [] : entry.knobs;
	}

	/**
	 * The knob that represents a modifier on its own.
	 *
	 * @param name Registry name.
	 * @return The main knob, or `null` for an unknown modifier.
	 */
	public static function mainKnob(name:String):LabKnob
	{
		final list:Array<LabKnob> = knobs(name);
		for (knob in list)
		{
			if (knob.main)
				return knob;
		}
		return list.length > 0 ? list[0] : null;
	}

	/**
	 * Finds one knob of one modifier.
	 *
	 * @param name Registry name.
	 * @param percent Percent name, case-insensitive.
	 * @return The knob, or `null` when either is unknown.
	 */
	public static function knob(name:String, percent:String):LabKnob
	{
		final key:String = PercentStore.normalize(percent);
		for (knob in knobs(name))
		{
			if (PercentStore.normalize(knob.percent) == key)
				return knob;
		}
		return null;
	}

	/**
	 * Registry modifiers the catalog does not describe yet.
	 *
	 * `ModifierRegistry.names()` is the source of truth for the modifier list,
	 * so a modifier added without a knob definition shows up here (the lab
	 * logs it and the interpreter spec fails on it) instead of silently
	 * missing from the picker.
	 *
	 * @return Lowercase registry names with no catalog entry; empty when complete.
	 */
	public static function missing():Array<String>
	{
		ensure();
		final out:Array<String> = [];
		for (name in ModifierRegistry.names())
		{
			if (!byName.exists(PercentStore.normalize(name)))
				out.push(name);
		}
		return out;
	}

	/** Builds the lookup table once; every accessor funnels through here. */
	static function ensure():Void
	{
		if (entries != null)
			return;
		byName = new Map();
		entries = build();
		for (entry in entries)
			byName.set(PercentStore.normalize(entry.name), entry);
	}

	static function build():Array<LabModifier>
	{
		return [
			mod('beat', 'Beat', 'Pulses the field on every beat.', list().add('beat', 0, 1, 0.05, 0, true).axes('beat', -1, 1, 0.05)
				.add('beatSpeed', 0, 4, 0.1, 1).add('beatOffset', -2, 2, 0.1).add('beatMult', 0, 4, 0.1).done()),
			mod('bounce', 'Bounce', 'Beat-synced bounce on any axis.',
				list().add('bounce', 0, 1, 0.05, 0, true).axes('bounce', -1, 1, 0.05).add('bounceSpeed', -2, 2, 0.1).add('bounceOffset', -4, 4, 0.1)
					.done()),
			mod('boost', 'Boost', 'Accelerates (boost), slows (brake) or ripples (wave) the scroll.', list().add('boost', 0, 1, 0.05, 0, true)
				.add('brake', 0, 1, 0.05).add('wave', 0, 2, 0.05).add('waveMult', 0, 3, 0.1, 1).done()),
			mod('bumpy', 'Bumpy', 'Distance-based bumps on position and angle.',
				list().add('bumpy', 0, 1, 0.05, 0, true).axes('bumpy', -1, 1, 0.05).add('bumpyAngle', 0, 1, 0.05).add('bumpyOffset', -4, 4, 0.1)
					.add('bumpyPeriod', -4, 4, 0.1).add('bumpyMult', 0, 3, 0.1, 1).done()),
			mod('centerrotate', 'Center Rotate', 'Rotates the field around the screen centre.', list().axes('centerRotate', -180, 180, 5, 0, true)
				.done()),
			mod('confusion', 'Confusion', 'Spins arrows around their own axes.',
				list().add('confusion', 0, 2, 0.05, 0, true).axes('confusion', -2, 2, 0.05).add('confusionOffset', -180, 180, 5)
					.add('roll', 0, 2, 0.05).add('twirl', 0, 2, 0.05).add('dizzy', 0, 2, 0.05).done()),
			mod('counterclockwise', 'Counter Clockwise', 'Orbits the lanes counter-clockwise.',
				list().add('counterClockWise', 0, 1, 0.05, 0, true).done()),
			mod('drugged', 'Drugged', 'Slow, heavy drift across the field.', list().add('drugged', 0, 1, 0.05, 0, true).done()),
			mod('drunk', 'Drunk', 'Sine wobble driven by song time and distance.',
				list().add('drunk', 0, 1, 0.05, 0, true).axes('drunk', -1, 1, 0.05).add('drunkSpeed', -2, 2, 0.1).add('drunkPeriod', -4, 4, 0.1)
					.add('drunkOffset', -4, 4, 0.1).done()),
			mod('fieldrotate', 'Field Rotate', 'Rotates each side around its own field centre.', list().axes('fieldRotate', -180, 180, 5, 0, true)
				.done()),
			mod('infinite', 'Infinite', 'Lerps arrows onto a lemniscate path.', list().add('infinite', 0, 1, 0.05, 0, true).done()),
			mod('invert', 'Invert', 'Mirrors lanes (invert) or the whole field (flip).',
				list().add('invert', 0, 1, 0.05, 0, true).add('flip', 0, 1, 0.05).done()),
			mod('localrotate', 'Local Rotate', 'Rotates around the receptor line.', list().axes('localRotate', -180, 180, 5, 0, true).done()),
			mod('opponentswap', 'Opponent Swap', 'Slides both sides toward the other.', list().add('opponentSwap', 0, 1, 0.05, 0, true).done()),
			mod('radionic', 'Radionic', 'Radial, hypnotic arrow motion.', list().add('radionic', 0, 1, 0.05, 0, true).done()),
			mod('receptorscroll', 'Receptor Scroll', 'Ping-pongs the receptor line up and down.',
				list().add('receptorScroll', 0, 1, 0.05, 0, true).done()),
			mod('reverse', 'Reverse', 'Mirrors the scroll offset; xmod scales it.',
				list().add('reverse', 0, 1, 0.05, 0, true).add('xmod', 0, 3, 0.05, 1).add('split', 0, 1, 0.05).add('alternate', 0, 1, 0.05)
					.add('cross', 0, 1, 0.05).add('centered', 0, 1, 0.05).add('unboundedReverse', 0, 1, 1).axes('scrollAngle', -180, 180, 5)
					.axes('curvedScroll', -1, 1, 0.05).add('curvedScrollPeriod', -2, 2, 0.05).done()),
			mod('rotate', 'Rotate', 'Rotates the field around the lane centre.', list().axes('rotate', -180, 180, 5, 0, true).done()),
			mod('sawtooth', 'Sawtooth', 'Ramps the field and snaps back each period.',
				list().add('sawtooth', 0, 1, 0.05, 0, true).add('sawtoothPeriod', -4, 4, 0.1).done()),
			mod('scale', 'Scale', 'Scales arrows (1 = normal), or shrinks them (tiny).',
				list().add('scale', 0, 3, 0.05, 1, true).add('scaleX', 0, 3, 0.05, 1).add('scaleY', 0, 3, 0.05, 1).add('tiny', 0, 2, 0.05)
					.add('tinyX', 0, 2, 0.05).add('tinyY', 0, 2, 0.05).done()),
			mod('schmovindrunk', 'Schmovin Drunk', 'Schmovin-style drunk wobble.', list().add('schmovinDrunk', 0, 2, 0.05, 0, true).done()),
			mod('schmovintipsy', 'Schmovin Tipsy', 'Schmovin-style tipsy wobble.', list().add('schmovinTipsy', 0, 2, 0.05, 0, true).done()),
			mod('schmovintornado', 'Schmovin Tornado', 'Schmovin-style tornado arc.',
				list().add('schmovinTornado', 0, 1, 0.05, 0, true).done()),
			mod('skew', 'Skew', 'Shears the arrows. Tracked only — Flixel sprites cannot draw skew.',
				list().add('skewX', -1, 1, 0.05, 0, true).add('skewY', -1, 1, 0.05).done()),
			mod('spiral', 'Spiral', 'Spirals arrows away from their lane.',
				list().add('spiral', 0, 1, 0.05, 0, true).add('spiralDist', 0, 4, 0.1).done()),
			mod('square', 'Square', 'Moves arrows on a square path.',
				list().add('square', 0, 1, 0.05, 0, true).add('squareOffset', -4, 4, 0.1).add('squarePeriod', -4, 4, 0.1).done()),
			mod('stealth', 'Stealth', 'Fades arrows (stealth from 0.5 up), or hides them near the receptor (sudden/hidden).',
				list().add('stealth', 0, 1, 0.05, 0, true).add('dark', 0, 1, 0.05).add('alpha', 0, 1, 0.05, 1).add('sudden', 0, 1, 0.05)
					.add('suddenStart', 0, 10, 0.1, 5).add('suddenEnd', 0, 10, 0.1, 3).add('suddenGlow', 0, 2, 0.05, 1).add('hidden', 0, 1, 0.05)
					.add('hiddenStart', 0, 10, 0.1, 5).add('hiddenEnd', 0, 10, 0.1, 3).add('hiddenGlow', 0, 2, 0.05, 1).done()),
			mod('tipsy', 'Tipsy', 'Slower, wider wobble than drunk.',
				list().add('tipsy', 0, 1, 0.05, 0, true).axes('tipsy', -1, 1, 0.05).add('tipsySpeed', -2, 2, 0.1).add('tipsyOffset', -2, 2, 0.1)
					.done()),
			mod('tornado', 'Tornado', 'Lanes swing in an arc as they approach.', list().add('tornado', 0, 1, 0.05, 0, true).done()),
			mod('transform', 'Transform', 'Offsets arrows in pixels (x/y/z), with per-arrow offsets.',
				list().add('x', -400, 400, 10, 0, true).add('y', -400, 400, 10).add('z', -400, 400, 10).add('xoffset', -400, 400, 10)
					.add('yoffset', -400, 400, 10).add('zoffset', -400, 400, 10).done()),
			mod('vibrate', 'Vibrate', 'Random per-frame jitter (not deterministic).', list().add('vibrate', 0, 2, 0.05, 0, true).done()),
			mod('wiggle', 'Wiggle', 'Gentle beat wiggle, also nudges the arrow angle.', list().add('wiggle', 0, 2, 0.05, 0, true).done()),
			mod('zigzag', 'ZigZag', 'Triangle-wave lane drift.', list().add('zigZag', 0, 2, 0.05, 0, true).done()),
			mod('zoom', 'Zoom', 'Centre (zoom) and per-lane (localZoom) zoom; mini shrinks instead.',
				list().add('zoom', 0, 2, 0.05, 0, true).add('mini', 0, 1, 0.05).add('localZoom', 0, 2, 0.05).add('localMini', 0, 1, 0.05)
					.done())
		];
	}

	static function mod(name:String, label:String, hint:String, knobs:Array<LabKnob>):LabModifier
	{
		return {name: name, label: label, hint: hint, knobs: knobs};
	}

	static function list():LabKnobList
	{
		return new LabKnobList();
	}
}

/** Chainable builder so the table above reads as one line per modifier. */
class LabKnobList
{
	/** Knobs added so far, in insertion order. */
	public var items:Array<LabKnob> = [];

	/** Builder; use `ModchartLabCatalog` instead of constructing this directly. */
	public function new()
	{
	}

	/**
	 * Appends one knob.
	 *
	 * @param percent Percent name, script spelling.
	 * @param min Slider lower bound.
	 * @param max Slider upper bound.
	 * @param step Keyboard nudge.
	 * @param value Value the modifier starts with.
	 * @param main Marks the knob that represents the modifier.
	 * @return This builder, for chaining.
	 */
	public function add(percent:String, min:Float, max:Float, step:Float, ?value:Float = 0, ?main:Bool = false):LabKnobList
	{
		items.push({percent: percent, min: min, max: max, step: step, value: value, main: main});
		return this;
	}

	/**
	 * Appends `<prefix>X`, `<prefix>Y` and `<prefix>Z`.
	 *
	 * @param prefix Shared percent prefix (`rotate`, `bumpy`, ...).
	 * @param min Slider lower bound for every axis.
	 * @param max Slider upper bound for every axis.
	 * @param step Keyboard nudge.
	 * @param value Value each axis starts with.
	 * @param mainFirst Flags the X axis as the modifier's main knob.
	 * @return This builder, for chaining.
	 */
	public function axes(prefix:String, min:Float, max:Float, step:Float, ?value:Float = 0, ?mainFirst:Bool = false):LabKnobList
	{
		add(prefix + 'X', min, max, step, value, mainFirst);
		add(prefix + 'Y', min, max, step, value);
		add(prefix + 'Z', min, max, step, value);
		return this;
	}

	/**
	 * Ends the chain.
	 *
	 * @return The knobs, in insertion order.
	 */
	public function done():Array<LabKnob>
	{
		return items;
	}
}
