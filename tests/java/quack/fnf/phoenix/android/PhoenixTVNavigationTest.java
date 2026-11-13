package quack.fnf.phoenix.android;

import android.app.UiModeManager;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.view.KeyEvent;
import java.util.ArrayList;
import java.util.List;
import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

/**
 * Host-JVM regression tests for PhoenixCore TV detection, system Back routing,
 * task backgrounding, and MainActivity/PhoenixInput KEYCODE_MENU forwarding.
 */
public final class PhoenixTVNavigationTest
{
	static void check(boolean condition)
	{
		if (!condition)
			throw new AssertionError("TV navigation assertion failed");
	}

	static final class DeviceHarness extends quack.fnf.phoenix.MainActivity
	{
		final UiModeManager uiMode = new UiModeManager();
		final PackageManager pm = new PackageManager();

		@Override public Object getSystemService(String name)
		{
			if (UI_MODE_SERVICE.equals(name))
				return uiMode;
			return null;
		}

		@Override public PackageManager getPackageManager()
		{
			return pm;
		}
	}

	static final class EventLog extends HaxeObject
	{
		final List<String> events = new ArrayList<String>();

		@Override public void call2(String func, Object arg0, Object arg1)
		{
			if ("onAndroidEvent".equals(func))
				events.add(arg0 + ":" + arg1);
		}
	}

	static void tvDetection()
	{
		Extension.mainContext = null;
		check(!PhoenixCore.isAndroidTV());
		check(PhoenixCore.hasTouchscreen()); // Uncertain -> fail safe to touch-enabled.

		DeviceHarness device = new DeviceHarness();
		Extension.mainContext = device;
		device.pm.features.add(PackageManager.FEATURE_TOUCHSCREEN);
		check(!PhoenixCore.isAndroidTV());
		check(PhoenixCore.hasTouchscreen());

		// TV detected via UiModeManager.
		device.uiMode.modeType = Configuration.UI_MODE_TYPE_TELEVISION;
		check(PhoenixCore.isAndroidTV());

		// TV detected via Leanback system feature even if UiModeManager reports normal.
		device.uiMode.modeType = Configuration.UI_MODE_TYPE_NORMAL;
		device.pm.features.add("android.software.leanback");
		check(PhoenixCore.isAndroidTV());

		// Touchless Android TV box without touchscreen feature.
		device.pm.features.remove("android.software.leanback");
		device.pm.features.remove(PackageManager.FEATURE_TOUCHSCREEN);
		check(!PhoenixCore.isAndroidTV());
		check(!PhoenixCore.hasTouchscreen());

		// Legacy television feature also triggers TV detection.
		device.pm.features.add("android.hardware.type.television");
		check(PhoenixCore.isAndroidTV());
	}

	static void backAndTaskBackgrounding()
	{
		EventLog log = new EventLog();
		PhoenixCore.registerCallback(log);
		PhoenixCore core = new PhoenixCore();

		// System Back returns false so GameActivity does not finish() behind Haxe menus.
		check(!core.onBackPressed());
		check(log.events.size() == 1 && "nav:back".equals(log.events.get(0)));

		Extension.mainActivity = null;
		check(!PhoenixCore.moveTaskToBack());

		DeviceHarness activity = new DeviceHarness();
		Extension.mainActivity = activity;
		check(PhoenixCore.moveTaskToBack());
		check(activity.movedToBack);

		PhoenixCore.registerCallback(null);
	}

	static void menuKeyRouting()
	{
		EventLog log = new EventLog();
		PhoenixCore.registerCallback(log);
		PhoenixInput.setVolumeKeysIntercepted(false);

		DeviceHarness activity = new DeviceHarness();
		check(activity.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MENU, 0)));
		// Repeats are consumed without re-dispatching pause toggles.
		check(activity.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MENU, 1)));
		// Key-up for MENU consumes without double-triggering.
		check(activity.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MENU, 0)));
		// Fallback onKeyDown/onKeyUp handlers also suppress repeats and route MENU.
		check(activity.onKeyDown(KeyEvent.KEYCODE_MENU, new KeyEvent(1)));
		check(activity.onKeyUp(KeyEvent.KEYCODE_MENU, new KeyEvent(0)));

		check(log.events.size() == 1 && "nav:menu".equals(log.events.get(0)));

		// Unrelated keys remain unintercepted when volume interception is disabled.
		check(!activity.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_VOLUME_UP, 0)));
		PhoenixInput.setVolumeKeysIntercepted(true);
		check(activity.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_VOLUME_UP, 0)));
		check(log.events.size() == 2 && ("hwkey:down:" + KeyEvent.KEYCODE_VOLUME_UP).equals(log.events.get(1)));

		PhoenixInput.setVolumeKeysIntercepted(false);
		PhoenixCore.registerCallback(null);
	}

	public static void main(String[] args)
	{
		tvDetection();
		backAndTaskBackgrounding();
		menuKeyRouting();
		System.out.println("Android TV navigation tests passed");
	}
}
