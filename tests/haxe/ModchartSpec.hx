import modchart.ModchartEase;
import modchart.ModchartManager;
import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModifierRegistry;
import modchart.PercentStore;
import modchart.PlayField;

/**
 * Renderer-free contract tests for the `modchart` core: percent storage,
 * the beat event timeline, the modifier chain and every shipped modifier.
 * Run by `tests/haxe/run-modchart.sh` on the Haxe interpreter (no Flixel).
 */
class ModchartSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok)
			throw label;
	}

	static function approx(actual:Float, expected:Float, label:String):Void
	{
		if (Math.abs(actual - expected) > 0.01)
			throw '$label: expected $expected, got $actual';
	}

	static function field():PlayField
	{
		final pf:PlayField = new PlayField();
		pf.screenWidth = 1280;
		pf.screenHeight = 720;
		pf.receptorX = [[100, 200, 300, 400], [700, 800, 900, 1000]];
		pf.receptorY = [[50, 50, 50, 50], [50, 50, 50, 50]];
		return pf;
	}

	static function params(?lane:Int = 0, ?player:Int = 0, ?distance:Float = 200):ModchartParams
	{
		final p:ModchartParams = new ModchartParams();
		p.songTime = 1000;
		p.curBeat = 4;
		p.distance = distance;
		p.lane = lane;
		p.player = player;
		p.isTapArrow = true;
		p.receptorX = 100 + lane * 100 + player * 600;
		p.receptorY = 50;
		return p;
	}

	static function main():Void
	{
		percentStore();
		modifierRegistry();
		eventTimeline();
		reverseAndXmod();
		drunkAndTipsy();
		visualModifiers();
		rotationModifiers();
		allModifiersRun();
		Sys.println('ModchartSpec: PASS');
	}

	static function percentStore():Void
	{
		final store:PercentStore = new PercentStore();
		check(store.get('drunk', 0) == 0, 'unset percent is zero');
		store.set('Drunk', 0.5, -1);
		approx(store.get('drunk', 0), 0.5, 'case-insensitive set');
		approx(store.get('DRUNK', 1), 0.5, 'both players set');
		store.set('drunk', 0.25, 1);
		approx(store.get('drunk', 0), 0.5, 'per-player set keeps other side');
		approx(store.get('drunk', 1), 0.25, 'per-player set');
		check(!store.isIdle(), 'non-zero store is not idle');
		store.set('drunk', 0, -1);
		check(store.isIdle(), 'zeroed store is idle');
		store.clear();
		check(store.names().length == 0, 'clear empties store');
	}

	static function modifierRegistry():Void
	{
		check(ModifierRegistry.exists('drunk'), 'drunk registered');
		check(ModifierRegistry.exists('TORNADO'), 'registry is case-insensitive');
		check(!ModifierRegistry.exists('notAMod'), 'unknown mod rejected');
		check(ModifierRegistry.names().length >= 30, 'shipped modifier count');
		final manager:ModchartManager = new ModchartManager();
		check(manager.addModifier('drunk'), 'addModifier installs');
		check(!manager.addModifier('drunk'), 'duplicate addModifier is a no-op');
		check(!manager.addModifier('notAMod'), 'unknown addModifier fails soft');
		check(manager.isActive(), 'manager active with a modifier');
		check(manager.modifierNames().indexOf('Drunk') != -1, 'modifierNames lists installed');
		manager.clear();
		check(!manager.isActive(), 'clear deactivates');
	}

	static function eventTimeline():Void
	{
		final manager:ModchartManager = new ModchartManager();
		manager.addModifier('drunk');
		manager.setPercent('drunk', 1, -1);

		manager.ease('drunk', 4, 4, 0, ModchartEase.linear, -1);
		manager.update(6);
		approx(manager.getPercent('drunk', 0), 0.5, 'ease midpoint');
		manager.update(9);
		approx(manager.getPercent('drunk', 0), 0, 'ease end value');

		manager.set('tornado', 10, 1, -1);
		manager.update(9.5);
		approx(manager.getPercent('tornado', 0), 0, 'set waits for its beat');
		manager.update(10);
		approx(manager.getPercent('tornado', 0), 1, 'set fires on its beat');

		manager.setPercent('drunk', 0.2, -1);
		manager.add('drunk', 12, 2, 0.6, ModchartEase.linear, -1);
		manager.update(13);
		approx(manager.getPercent('drunk', 0), 0.5, 'add midpoint');
		manager.update(15);
		approx(manager.getPercent('drunk', 0), 0.8, 'add end value');

		var fired:Int = 0;
		manager.callback(16, function(e) {
			fired++;
			check(e.fireBeat == 16, 'callback reports the beat it fired on');
		});
		manager.update(15.5);
		check(fired == 0, 'callback waits');
		manager.update(16);
		check(fired == 1, 'callback fires once');
		manager.update(16);
		check(fired == 1, 'callback does not refire');

		var repeats:Int = 0;
		manager.repeater(18, 2, function(e) repeats++);
		manager.update(18);
		check(repeats == 1, 'repeater fires on its beat');
		manager.update(18.5);
		check(repeats == 1, 'repeater waits for the interval');
		manager.update(20);
		check(repeats == 2, 'repeater fires every length beats');
		manager.update(26);
		check(repeats == 5, 'repeater catches up after a beat jump');

		// A timeline alone (no modifier) must keep updating so callbacks run.
		final callbackOnly:ModchartManager = new ModchartManager();
		var hits:Int = 0;
		callbackOnly.callback(1, function(e) hits++);
		check(callbackOnly.isActive(), 'scheduled callbacks keep the modchart active');
		callbackOnly.update(1);
		check(hits == 1, 'callback-only timeline still fires');
		check(!callbackOnly.isActive(), 'finished timeline deactivates');

		// Eases capture each side's own start value.
		final perPlayer:ModchartManager = new ModchartManager();
		perPlayer.addModifier('drunk');
		perPlayer.setPercent('drunk', 0.2, 0);
		perPlayer.setPercent('drunk', 0.6, 1);
		perPlayer.ease('drunk', 30, 2, 1, ModchartEase.linear, -1);
		perPlayer.update(31);
		approx(perPlayer.getPercent('drunk', 0), 0.6, 'ease start captured per player (opponent)');
		approx(perPlayer.getPercent('drunk', 1), 0.8, 'ease start captured per player (player)');

		manager.setAdd('drunk', 22, 0.2, -1);
		manager.update(22);
		approx(manager.getPercent('drunk', 0), 1.0, 'setAdd adds to current');

		// Per-player scheduling: player 1 only.
		manager.set('drunk', 24, 0.3, 1);
		manager.update(24);
		approx(manager.getPercent('drunk', 0), 1.0, 'player-scoped set leaves other side');
		approx(manager.getPercent('drunk', 1), 0.3, 'player-scoped set');
	}

	static function reverseAndXmod():Void
	{
		final manager:ModchartManager = new ModchartManager();
		manager.addModifier('reverse');
		final pf:PlayField = manager.playfields[0];
		pf.screenWidth = 1280;
		pf.screenHeight = 720;
		pf.receptorX = [[100, 200, 300, 400], [700, 800, 900, 1000]];
		pf.receptorY = [[50, 50, 50, 50], [50, 50, 50, 50]];

		manager.setPercent('reverse', 1, -1);
		var out = pf.transform(new ModchartVec3(100, -150), params(0, 0));
		approx(out.pos.y, 250, 'reverse mirrors the scroll offset');
		approx(out.pos.x, 100, 'reverse keeps x');

		manager.setPercent('reverse', 0, -1);
		manager.setPercent('xmod', 2, -1);
		out = pf.transform(new ModchartVec3(100, -150), params(0, 0));
		approx(out.pos.y, -350, 'xmod scales the scroll offset');

		// Receptors only move with `centered`.
		manager.setPercent('xmod', 1, -1);
		manager.setPercent('centered', 1, -1);
		final receptorParams:ModchartParams = params(0, 0, 0);
		receptorParams.isReceptor = true;
		out = pf.transform(new ModchartVec3(100, 50), receptorParams);
		approx(out.pos.x, 640, 'centered pulls receptor to centre x');
		approx(out.pos.y, 360, 'centered pulls receptor to centre y');
	}

	static function drunkAndTipsy():Void
	{
		final pf:PlayField = field();
		pf.addModifier('drunk');
		pf.setPercent('drunk', 1, -1);
		final base:ModchartVec3 = new ModchartVec3(100, -150);
		final out = pf.transform(base.clone(), params(0, 0));
		check(out.pos.x != base.x, 'drunk offsets x');
		approx(out.pos.y, base.y, 'drunk leaves y alone by default');

		final tipsyField:PlayField = field();
		tipsyField.addModifier('tipsy');
		tipsyField.setPercent('tipsy', 1, -1);
		final tipsyOut = tipsyField.transform(base.clone(), params(0, 0));
		check(tipsyOut.pos.y != base.y, 'tipsy offsets y');

		// Zero percents are the identity.
		final idle:PlayField = field();
		idle.addModifier('drunk');
		idle.addModifier('tornado');
		idle.addModifier('bounce');
		final idleOut = idle.transform(base.clone(), params(0, 0));
		approx(idleOut.pos.x, base.x, 'idle modifiers keep x');
		approx(idleOut.pos.y, base.y, 'idle modifiers keep y');
	}

	static function visualModifiers():Void
	{
		final stealth:PlayField = field();
		stealth.addModifier('stealth');
		stealth.setPercent('stealth', 1, -1);
		var out = stealth.transform(new ModchartVec3(0, 0), params(0, 0, 0));
		approx(out.visuals.alpha, 0, 'stealth hides arrows at the receptor');

		final scale:PlayField = field();
		scale.addModifier('scale');
		scale.setPercent('scale', 2, -1);
		out = scale.transform(new ModchartVec3(0, 0), params(0, 0));
		approx(out.visuals.scaleX, 2, 'scale doubles scaleX');
		approx(out.visuals.scaleY, 2, 'scale doubles scaleY');

		final confusion:PlayField = field();
		confusion.addModifier('confusion');
		confusion.setPercent('confusion', 1, -1);
		out = confusion.transform(new ModchartVec3(0, 0), params(0, 0));
		check(out.visuals.angleZ != 0, 'confusion spins arrows');

		final zoom:PlayField = field();
		zoom.addModifier('zoom');
		zoom.setPercent('zoom', 1, -1);
		out = zoom.transform(new ModchartVec3(640, 360), params(0, 0));
		approx(out.pos.x, 640, 'zoom keeps the centre fixed');
		check(out.visuals.scaleX != 1, 'zoom scales arrows');
	}

	static function rotationModifiers():Void
	{
		final pf:PlayField = field();
		pf.addModifier('rotate');
		pf.setPercent('rotateZ', 90, -1);
		final out = pf.transform(new ModchartVec3(400, 360), params(0, 0));
		// 100px right of the origin (300,360) rotated 90° ends 100px below it.
		approx(out.pos.x, 300, 'rotateZ x');
		approx(out.pos.y, 460, 'rotateZ y');

		final transform:PlayField = field();
		transform.addModifier('transform');
		transform.setPercent('x', 25, -1);
		transform.setPercent('y', -10, -1);
		final shifted = transform.transform(new ModchartVec3(100, 100), params(0, 0));
		approx(shifted.pos.x, 125, 'transform x offset');
		approx(shifted.pos.y, 90, 'transform y offset');
	}

	static function allModifiersRun():Void
	{
		for (name in ModifierRegistry.names())
		{
			final pf:PlayField = field();
			check(pf.addModifier(name), 'install $name');
			// Drive every percent the modifier might read to a non-zero value
			// via the manager API surface used by scripts.
			pf.setPercent(name, 1, -1);
			pf.setPercent(name + 'X', 1, -1);
			pf.setPercent(name + 'Y', 1, -1);
			pf.setPercent(name + 'Z', 1, -1);
			pf.setPercent(name + 'Speed', 1, -1);
			pf.setPercent(name + 'Offset', 1, -1);
			pf.setPercent(name + 'Period', 1, -1);
			pf.setPercent(name + 'Mult', 1, -1);
			final out = pf.transform(new ModchartVec3(100, -150), params(0, 0));
			check(out.pos != null && out.visuals != null, '$name returns an output');
			check(!Math.isNaN(out.pos.x) && !Math.isNaN(out.pos.y), '$name produces finite positions');
		}
		// Extra playfields compose instead of replacing each other.
		final manager:ModchartManager = new ModchartManager();
		manager.addModifier('transform');
		manager.setPercent('x', 10, -1);
		manager.addPlayfield();
		check(manager.playfields.length == 2, 'addPlayfield grows the manager');
		check(manager.getPercent('x', 0, 1) == 0, 'new playfield starts at zero');
	}
}
