package quack.fnf.phoenix.android;

import android.content.Context;
import android.os.Build;
import android.view.DisplayCutout;
import android.view.WindowInsets;

/** Executes production policy/layout with deliberately minimal Android doubles.
 * Not an Android measurement, SurfaceView, event dispatch or device test.
 */
public final class PhoenixCutoutTest
{
	static void check(boolean condition) {
		if (!condition) throw new AssertionError();
	}
	static void padding(PhoenixCutoutLayout view, int l, int t, int r, int b) {
		check(view.getPaddingLeft() == l && view.getPaddingTop() == t
			&& view.getPaddingRight() == r && view.getPaddingBottom() == b);
	}
	static class ActivityHarness extends quack.fnf.phoenix.MainActivity {
		void create(){onCreate(null);} void resume(){onResume();} void destroy(){onDestroy();}
	}
	static void activityCallbacks() {
		Build.VERSION.SDK_INT = 36;
		PhoenixDisplay.setCutoutMode("never");
		ActivityHarness first = new ActivityHarness();
		first.create();
		check(first.content instanceof PhoenixCutoutLayout);
		PhoenixCutoutLayout oldContent = (PhoenixCutoutLayout) first.content;
		oldContent.onApplyWindowInsets(new WindowInsets(new DisplayCutout(55,0,0,0)));
		padding(oldContent,55,0,0,0);
		PhoenixDisplay.setCutoutMode("always");
		padding(oldContent,0,0,0,0);
		first.resume();
		first.onWindowFocusChanged(true);
		padding(oldContent,0,0,0,0);
		first.destroy();
		ActivityHarness second = new ActivityHarness();
		second.create();
		PhoenixCutoutLayout newContent = (PhoenixCutoutLayout) second.content;
		check(newContent != oldContent);
		newContent.onApplyWindowInsets(new WindowInsets(new DisplayCutout(0,0,55,0)));
		padding(newContent,0,0,0,0);
		PhoenixDisplay.setCutoutMode("never");
		padding(newContent,0,0,55,0);
		padding(oldContent,0,0,0,0);
		android.widget.FrameLayout otherOwner = new android.widget.FrameLayout(new Context());
		otherOwner.setPadding(1,2,3,4);
		second.setContentView(otherOwner);
		PhoenixCutoutLayout replacement = (PhoenixCutoutLayout) second.content;
		check(replacement != newContent);
		replacement.onApplyWindowInsets(new WindowInsets(new DisplayCutout(0,25,0,0)));
		padding(replacement,0,25,0,0); // Active-view replacement reapplies selection.
		check(otherOwner.getPaddingLeft()==1 && otherOwner.getPaddingTop()==2
			&& otherOwner.getPaddingRight()==3 && otherOwner.getPaddingBottom()==4);
		otherOwner.setPadding(6,7,8,9); // Later changes by another owner survive.
		PhoenixDisplay.setCutoutMode("always");
		PhoenixDisplay.setCutoutMode("never");
		check(otherOwner.getPaddingLeft()==6 && otherOwner.getPaddingTop()==7
			&& otherOwner.getPaddingRight()==8 && otherOwner.getPaddingBottom()==9);
		for (int sdk : new int[]{21,27,28,29,30,34}) {
			Build.VERSION.SDK_INT = sdk;
			ActivityHarness legacy = new ActivityHarness();
			legacy.create();
			check(!(legacy.content instanceof PhoenixCutoutLayout));
		}
	}
	static class Host extends android.app.Activity implements PhoenixDisplay.CutoutHost {
		boolean respect;
		public void setRespectCutoutInsets(boolean value){respect=value;}
	}
	static void lifecycle() {
		Build.VERSION.SDK_INT = 36;
		org.haxe.extension.Extension.mainActivity = null;
		PhoenixDisplay.setCutoutMode("never"); // Retain intent without an Activity.
		Host first = new Host();
		org.haxe.extension.Extension.mainActivity = first;
		PhoenixDisplay.applyCutoutToActivity(first);
		check(first.respect && first.window.attrs.layoutInDisplayCutoutMode == 3);
		PhoenixDisplay.setCutoutMode("always");
		check(!first.respect && first.window.attrs.layoutInDisplayCutoutMode == 3);
		// Queued work must not update an Activity that has been replaced.
		first.defer = true;
		PhoenixDisplay.setCutoutMode("never");
		int previousUpdates = first.window.updates;
		Host second = new Host();
		org.haxe.extension.Extension.mainActivity = second;
		first.destroyed = true;
		first.queued.run();
		check(first.window.updates == previousUpdates);
		PhoenixDisplay.applyCutoutToActivity(second); // Recreation/resume path.
		check(second.respect);
		PhoenixDisplay.applyCutoutToActivity(second); // Idempotent resume/focus.
		check(second.respect);
		second.defer = true;
		PhoenixDisplay.setCutoutMode("always");
		Runnable old = second.queued;
		PhoenixDisplay.setCutoutMode("never");
		old.run(); // Latest selection, not the stale queued mode.
		check(second.respect);
		second.finishing = true;
		int updates = second.window.updates;
		PhoenixDisplay.applyCutoutToActivity(second);
		check(updates == second.window.updates);
		second.finishing = false;
		second.window = null;
		PhoenixDisplay.applyCutoutToActivity(second); // Missing window, bounded retry.
		second.window = new android.view.Window();
		second.window.fail = true;
		int errors = android.util.Log.errors;
		PhoenixDisplay.applyCutoutToActivity(second);
		check(android.util.Log.errors == errors + 1); // Failure is diagnosed, not thrown.
		second.window.fail = false;
		for (int sdk : new int[]{27,28,29,30,34,35,36}) {
			Build.VERSION.SDK_INT = sdk;
			second.defer = false;
			PhoenixDisplay.setCutoutMode("never");
			if (sdk >= 28) check(second.window.attrs.layoutInDisplayCutoutMode == (sdk >= 35 ? 3 : 2));
			PhoenixDisplay.setCutoutMode("always");
			if (sdk >= 28) check(!second.respect && second.window.attrs.layoutInDisplayCutoutMode == (sdk >= 30 ? 3 : 1));
		}
		PhoenixDisplay.applyCutoutToActivity(null);
	}
	static void immersiveLifecycle() {
		Build.VERSION.SDK_INT = 36;
		Host host = new Host();
		org.haxe.extension.Extension.mainActivity = host;
		org.haxe.extension.Extension.mainContext = host;
		PhoenixDisplay.applyDisplayToActivity(host);
		check((host.window.attrs.flags & android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN) != 0);
		check((host.window.attrs.flags & android.view.WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN) == 0);
		check(host.window.controller.hidden == 3 && host.window.controller.behavior == 2);
		PhoenixDisplay.setImmersive("off");
		check(host.window.controller.shown == 3);
		check((host.window.attrs.flags & android.view.WindowManager.LayoutParams.FLAG_FORCE_NOT_FULLSCREEN) != 0);
		PhoenixDisplay.applyDisplayToActivity(host); // Resume/focus keeps the latest requested mode.
		check(host.window.controller.shown == 3);
		PhoenixDisplay.setImmersive("lean");
		check(host.window.controller.hidden == 3 && host.window.controller.behavior == 1);
		PhoenixDisplay.setImmersive("full");
		check(host.window.controller.behavior == 2);
		// A controller can be absent before the window is attached; lifecycle retries.
		android.view.WindowInsetsController controller = host.window.controller;
		host.window.controller = null;
		PhoenixDisplay.applyImmersiveToActivity(host);
		host.window.controller = controller;
		PhoenixDisplay.applyImmersiveToActivity(host);
		check(controller.hidden == 3);
		// Pre-R uses legacy UI flags, but the same window-flag contract.
		Build.VERSION.SDK_INT = 29;
		PhoenixDisplay.applyImmersiveToActivity(host);
		check((host.window.decor.systemUiVisibility & android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY) != 0);
		PhoenixDisplay.setImmersive("off");
		check(host.window.decor.systemUiVisibility == android.view.View.SYSTEM_UI_FLAG_VISIBLE);
		PhoenixDisplay.setImmersive("full");
		// Stale queued work must not touch a replaced Activity.
		host.defer = true;
		PhoenixDisplay.setImmersive("off");
		Runnable stale = host.queued;
		Host replacement = new Host();
		org.haxe.extension.Extension.mainActivity = replacement;
		stale.run();
		check(host.window.controller.shown == 0);
		Build.VERSION.SDK_INT = 36;
		PhoenixDisplay.applyDisplayToActivity(replacement);
		check(replacement.window.controller.shown == 3);
	}
	static void nativePreferenceMirror() {
		Build.VERSION.SDK_INT = 36;
		Host host = new Host();
		org.haxe.extension.Extension.mainActivity = host;
		org.haxe.extension.Extension.mainContext = host;
		PhoenixDisplay.setCutoutMode("always");
		check("always".equals(host.preferences.value));
		// Simulate a cold process: static mode starts safe, then native restore runs.
		PhoenixDisplay.setCutoutMode("never");
		host.preferences.value = "always";
		PhoenixDisplay.restoreCutoutMode(host);
		PhoenixDisplay.applyCutoutToActivity(host);
		check(!host.respect);
		// Haxe load is authoritative and repairs a stale/corrupt native mirror.
		PhoenixDisplay.setCutoutMode("never");
		check("never".equals(host.preferences.value));
		host.preferences.value = "bogus";
		PhoenixDisplay.restoreCutoutMode(host);
		PhoenixDisplay.applyCutoutToActivity(host);
		check(host.respect);
		host.preferences.fail = true;
		int errors = android.util.Log.errors;
		PhoenixDisplay.restoreCutoutMode(host);
		PhoenixDisplay.setCutoutMode("always");
		check(android.util.Log.errors == errors + 2);
		host.preferences.fail = false;
	}
	public static void main(String[] args) {
		lifecycle();
		immersiveLifecycle();
		nativePreferenceMirror();
		activityCallbacks();
		for (int sdk : new int[] {21, 27, 28, 29, 30, 34, 35, 36}) {
			check(PhoenixCutoutPolicy.windowMode(sdk, "never") == (sdk < 28 ? 0 : 2));
			check(PhoenixCutoutPolicy.windowMode(sdk, "always") == (sdk < 28 ? 0 : sdk < 30 ? 1 : 3));
			check(PhoenixCutoutPolicy.windowMode(sdk, "shortEdges") == (sdk < 28 ? 0 : 1));
			check(PhoenixCutoutPolicy.windowMode(sdk, "default") == 0);
			check(PhoenixCutoutPolicy.windowMode(sdk, null) == 0);
			check(PhoenixCutoutPolicy.needsSafeInsets(sdk, 36, "never") == (sdk >= 35));
			check(!PhoenixCutoutPolicy.needsSafeInsets(sdk, 34, "never"));
			check(!PhoenixCutoutPolicy.needsSafeInsets(sdk, 36, "always"));
		}
		Build.VERSION.SDK_INT = 36;
		PhoenixCutoutLayout view = new PhoenixCutoutLayout(new Context());
		WindowInsets portrait = new WindowInsets(new DisplayCutout(0, 40, 0, 0));
		view.setRespectCutout(true);
		check(view.onApplyWindowInsets(portrait) == portrait); // No consumption.
		padding(view, 0, 40, 0, 0);
		for (int i = 0; i < 20; i++) {
			view.setRespectCutout(false);
			padding(view, 0, 0, 0, 0);
			view.setRespectCutout(true);
			view.onApplyWindowInsets(portrait);
			padding(view, 0, 40, 0, 0);
		}
		view.onApplyWindowInsets(new WindowInsets(new DisplayCutout(50, 0, 0, 0)));
		padding(view, 50, 0, 0, 0);
		view.onApplyWindowInsets(new WindowInsets(new DisplayCutout(0, 0, 50, 0)));
		padding(view, 0, 0, 50, 0);
		view.onApplyWindowInsets(new WindowInsets(null));
		padding(view, 0, 0, 0, 0);
		PhoenixCutoutLayout recreated = new PhoenixCutoutLayout(new Context());
		recreated.setRespectCutout(true);
		recreated.onApplyWindowInsets(portrait);
		padding(recreated, 0, 40, 0, 0);
		padding(view, 0, 0, 0, 0); // No static state crossing instances.
		recreated.setRespectCutout(false);
		recreated.onApplyWindowInsets(portrait);
		padding(recreated, 0, 0, 0, 0);
		// API <28 must not call the cutout API (double throws if it does).
		Build.VERSION.SDK_INT = 27;
		recreated.onApplyWindowInsets(portrait);
		System.out.println("Cutout policy/layout tests passed");
	}
}
