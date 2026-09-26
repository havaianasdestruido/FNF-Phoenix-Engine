package quack.fnf.phoenix.android;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;

import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

/**
 * Core bridge between the Android runtime and the Haxe side of Phoenix
 * Engine (see `source/android/platform/`).
 *
 * Everything here is deliberately simple and defensive: static entry points
 * callable over JNI plus a single event channel back into Haxe
 * (`onAndroidEvent(event, arg)`). Lifecycle and device-state callbacks are
 * received because this class is registered as a Lime `android.extension`.
 *
 * Part of the Phoenix Android platform layer. See docs/ANDROID_PLATFORM.md.
 */
public class PhoenixCore extends Extension
{
	public static final String LOG_TAG = "PhoenixCore";

	private static final String PREFS_NAME = "phoenix_platform";
	private static final String RECOVERY_STATE_KEY = "recovery_state";
	private static final int NOTIFICATION_PERMISSION_REQUEST_CODE = 7401;

	/** The Haxe-side dispatcher (android.platform.AndroidBridge). May be null until registered. */
	private static HaxeObject callback = null;

	private static PowerManager.WakeLock wakeLock = null;

	// ------------------------------------------------------------------
	// Callback registration / event dispatch
	// ------------------------------------------------------------------

	public static void registerCallback(HaxeObject object)
	{
		callback = object;
	}

	/**
	 * Sends `onAndroidEvent(event, arg)` to the registered Haxe dispatcher.
	 * Safe to call from any thread; the Haxe side uses JNISafety to marshal
	 * onto the main thread.
	 */
	public static void dispatch(String event, String arg)
	{
		HaxeObject target = callback;
		if (target == null)
			return;

		try
		{
			target.call2("onAndroidEvent", event, arg);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "dispatch(" + event + ") failed: " + e);
		}
	}

	// ------------------------------------------------------------------
	// Lifecycle (delivered by GameActivity because we extend Extension)
	// ------------------------------------------------------------------

	@Override public void onCreate(Bundle state)
	{
		dispatch("lifecycle", "onCreate");
	}

	@Override public void onStart()
	{
		dispatch("lifecycle", "onStart");
	}

	@Override public void onResume()
	{
		dispatch("lifecycle", "onResume");
	}

	@Override public void onPause()
	{
		dispatch("lifecycle", "onPause");
	}

	@Override public void onStop()
	{
		dispatch("lifecycle", "onStop");
	}

	@Override public void onRestart()
	{
		dispatch("lifecycle", "onRestart");
	}

	@Override public void onDestroy()
	{
		releaseWakeLock();
		dispatch("lifecycle", "onDestroy");
	}

	@Override public void onLowMemory()
	{
		dispatch("memory", "low");
	}

	@Override public void onTrimMemory(int level)
	{
		dispatch("memory", "trim:" + level);
	}

	// ------------------------------------------------------------------
	// Device info
	// ------------------------------------------------------------------

	public static int getSDKInt()
	{
		return Build.VERSION.SDK_INT;
	}

	public static String getDeviceInfo()
	{
		// manufacturer|model|device|arch
		String arch = System.getProperty("os.arch");
		if (arch == null)
			arch = "unknown";
		return Build.MANUFACTURER + "|" + Build.MODEL + "|" + Build.DEVICE + "|" + arch;
	}

	// ------------------------------------------------------------------
	// Deep links / intents
	// ------------------------------------------------------------------

	/**
	 * Called by MainActivity for every intent delivered while running
	 * (including the launch intent). Forwards VIEW data URIs (used by the
	 * `phoenix://` deep link scheme) to Haxe.
	 */
	public static void handleNewIntent(Intent intent)
	{
		if (intent == null)
			return;

		Uri data = intent.getData();
		if (data != null)
		{
			dispatch("deeplink", data.toString());
			return;
		}

		// Non-data intents are forwarded as action strings so Haxe can react
		// if it wants to (currently informational only).
		String action = intent.getAction();
		if (action != null && !Intent.ACTION_MAIN.equals(action))
			dispatch("intent", action);
	}

	// ------------------------------------------------------------------
	// Thermal status (API 30+)
	// ------------------------------------------------------------------

	private static PowerManager.ThermalStatusListener thermalListener = null;

	/** @return one of the THERMAL_STATUS_* constants, or -1 when unsupported. */
	public static int getThermalStatus()
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || mainContext == null)
			return -1;

		PowerManager power = (PowerManager) mainContext.getSystemService(Context.POWER_SERVICE);
		if (power == null)
			return -1;

		return power.getCurrentThermalStatus();
	}

	public static void registerThermalListener()
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || mainContext == null)
			return;

		PowerManager power = (PowerManager) mainContext.getSystemService(Context.POWER_SERVICE);
		if (power == null)
			return;

		unregisterThermalListener();
		thermalListener = new PowerManager.ThermalStatusListener()
		{
			@Override public void onThermalStatusChanged(int status)
			{
				dispatch("thermal", String.valueOf(status));
			}
		};
		power.addThermalStatusListener(thermalListener);
	}

	public static void unregisterThermalListener()
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || mainContext == null || thermalListener == null)
			return;

		PowerManager power = (PowerManager) mainContext.getSystemService(Context.POWER_SERVICE);
		if (power != null)
			power.removeThermalStatusListener(thermalListener);
		thermalListener = null;
	}

	// ------------------------------------------------------------------
	// Battery state
	// ------------------------------------------------------------------

	/** @return "level(0..1)|charging|plugged" or null when unavailable. */
	public static String getBatteryInfo()
	{
		if (mainContext == null)
			return null;

		try
		{
			Intent batteryIntent = mainContext.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
			if (batteryIntent == null)
				return null;

			int level = batteryIntent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
			int scale = batteryIntent.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
			int status = batteryIntent.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
			int plugged = batteryIntent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1);

			float percent = (scale > 0) ? (level / (float) scale) : -1f;
			boolean charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL;
			return percent + "|" + charging + "|" + plugged;
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "getBatteryInfo failed: " + e);
			return null;
		}
	}

	// ------------------------------------------------------------------
	// Screen wake lock
	// ------------------------------------------------------------------

	public static void acquireWakeLock()
	{
		if (mainContext == null)
			return;

		try
		{
			if (wakeLock == null)
			{
				PowerManager power = (PowerManager) mainContext.getSystemService(Context.POWER_SERVICE);
				if (power == null)
					return;
				wakeLock = power.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ON_AFTER_RELEASE, "phoenix:gameplay");
				wakeLock.setReferenceCounted(false);
			}

			if (!wakeLock.isHeld())
				wakeLock.acquire(4 * 60 * 60 * 1000L); // hard cap: 4 hours
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "acquireWakeLock failed: " + e);
		}
	}

	public static void releaseWakeLock()
	{
		try
		{
			if (wakeLock != null && wakeLock.isHeld())
				wakeLock.release();
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "releaseWakeLock failed: " + e);
		}
	}

	// ------------------------------------------------------------------
	// Process-death recovery
	// ------------------------------------------------------------------

	/**
	 * Persists an opaque state blob (JSON) that survives process death.
	 * Pass null/empty to clear it (call this when state becomes stale, e.g.
	 * when leaving the song the blob describes).
	 */
	public static void setRecoveryState(String state)
	{
		if (mainContext == null)
			return;

		try
		{
			SharedPreferences prefs = mainContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
			if (state == null || state.length() == 0)
				prefs.edit().remove(RECOVERY_STATE_KEY).apply();
			else
				prefs.edit().putString(RECOVERY_STATE_KEY, state).apply();
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "setRecoveryState failed: " + e);
		}
	}

	/** @return the last persisted recovery blob, or an empty string. Never null. */
	public static String getRecoveryState()
	{
		if (mainContext == null)
			return "";

		try
		{
			SharedPreferences prefs = mainContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
			String value = prefs.getString(RECOVERY_STATE_KEY, "");
			return value == null ? "" : value;
		}
		catch (Exception e)
		{
			return "";
		}
	}

	@Override public void onSaveInstanceState(Bundle outState)
	{
		// SharedPreferences already survives process death; mirror the blob
		// into the instance state as well so warm restarts can read it back
		// synchronously if the Java side ever needs it.
		String state = getRecoveryState();
		if (state != null && state.length() > 0)
			outState.putString(RECOVERY_STATE_KEY, state);
	}

	@Override public void onRestoreInstanceState(Bundle savedState)
	{
		String state = savedState.getString(RECOVERY_STATE_KEY, "");
		if (state != null && state.length() > 0)
			dispatch("recovery", state);
	}

	// ------------------------------------------------------------------
	// Permissions (also backs the `android.*` compatibility bindings used
	// by StorageUtil, matching the extension-androidtools API surface)
	// ------------------------------------------------------------------

	/**
	 * @param permissionsCsv comma separated permission names, with or
	 *                       without the "android.permission." prefix.
	 */
	public static void requestPermissions(String permissionsCsv)
	{
		Activity activity = mainActivity;
		if (activity == null || permissionsCsv == null || permissionsCsv.length() == 0)
			return;

		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M)
			return; // all install-time permissions are granted implicitly

		String[] permissions = permissionsCsv.split(",");
		java.util.List<String> needed = new java.util.ArrayList<String>();
		for (String permission : permissions)
		{
			permission = permission.trim();
			if (permission == null || permission.length() == 0)
				continue;

			String full = permission.startsWith("android.permission.") ? permission : "android.permission." + permission;
			if (activity.checkSelfPermission(full) != PackageManager.PERMISSION_GRANTED)
				needed.add(full);
		}

		if (needed.isEmpty())
			return;

		try
		{
			activity.requestPermissions(needed.toArray(new String[0]), NOTIFICATION_PERMISSION_REQUEST_CODE);
		}
		catch (Exception e)
		{
			Log.e(LOG_TAG, "requestPermissions failed: " + e);
		}
	}

	/** @return comma separated subset of the given permissions currently granted. */
	public static String getGrantedPermissions(String permissionsCsv)
	{
		if (permissionsCsv == null || mainContext == null)
			return "";

		java.util.List<String> granted = new java.util.ArrayList<String>();
		for (String permission : permissionsCsv.split(","))
		{
			permission = permission.trim();
			if (permission.length() == 0)
				continue;

			String full = permission.startsWith("android.permission.") ? permission : "android.permission." + permission;
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M
				|| mainContext.checkSelfPermission(full) == PackageManager.PERMISSION_GRANTED)
			{
				granted.add(full);
			}
		}

		StringBuilder builder = new StringBuilder();
		for (String permission : granted)
		{
			if (builder.length() > 0)
				builder.append(',');
			builder.append(permission);
		}
		return builder.toString();
	}

	@Override public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults)
	{
		if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE)
		{
			StringBuilder granted = new StringBuilder();
			for (int i = 0; i < permissions.length; i++)
			{
				if (grantResults[i] == PackageManager.PERMISSION_GRANTED)
				{
					if (granted.length() > 0)
						granted.append(',');
					granted.append(permissions[i]);
				}
			}
			dispatch("permissions", granted.toString());
		}
		return true;
	}

	// ------------------------------------------------------------------
	// Storage paths / settings helpers (extension-androidtools parity)
	// ------------------------------------------------------------------

	public static String getExternalFilesDir()
	{
		if (mainContext == null)
			return "";

		try
		{
			java.io.File dir = mainContext.getExternalFilesDir(null);
			if (dir == null)
				return "";
			return dir.getAbsolutePath();
		}
		catch (Exception e)
		{
			return "";
		}
	}

	public static String getExternalStorageDirectory()
	{
		try
		{
			java.io.File dir = android.os.Environment.getExternalStorageDirectory();
			return dir == null ? "" : dir.getAbsolutePath();
		}
		catch (Exception e)
		{
			return "";
		}
	}

	public static boolean isExternalStorageManager()
	{
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || mainContext == null)
			return false;

		try
		{
			return android.os.Environment.isExternalStorageManager();
		}
		catch (Exception e)
		{
			return false;
		}
	}

	/**
	 * Opens a Settings screen by action name (e.g.
	 * "MANAGE_APP_ALL_FILES_ACCESS_PERMISSION" or any android.settings.*
	 * action), falling back to the main settings page.
	 */
	public static void requestSetting(String setting)
	{
		if (mainContext == null || setting == null)
			return;

		String action = setting.startsWith("android.settings.") ? setting : "android.settings." + setting;
		try
		{
			Intent intent = new Intent(action);
			// Some settings pages accept (or expect) the package URI.
			if (action.contains("MANAGE_APP_ALL_FILES_ACCESS_PERMISSION") || action.contains("APPLICATION_DETAILS"))
				intent.setData(Uri.parse("package:" + mainContext.getPackageName()));
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			mainContext.startActivity(intent);
		}
		catch (Exception e)
		{
			try
			{
				Intent fallback = new Intent(Settings.ACTION_SETTINGS);
				fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				mainContext.startActivity(fallback);
			}
			catch (Exception ignored) {}
		}
	}

	/** Requests the POST_NOTIFICATIONS runtime permission (API 33+). */
	public static void requestNotificationPermission()
	{
		if (Build.VERSION.SDK_INT < 33)
			return;

		requestPermissions("android.permission.POST_NOTIFICATIONS");
	}
}
