package quack.fnf.phoenix.android;

import android.app.Activity;
import android.os.Build;
import android.os.Looper;
import android.view.Gravity;
import android.widget.Toast;
import org.haxe.extension.Extension;
import org.libsdl.app.SDLActivity;
import java.nio.charset.StandardCharsets;

/** Host-JVM tests of the real Android JNI entry points and UI-thread handoff. */
public final class PhoenixStdFireTest
{
	private static void check(boolean condition, String message)
	{
		if (!condition)
			throw new AssertionError(message);
	}

	public static void main(String[] args)
	{
		Extension.mainActivity = null;
		check(!PhoenixCore.setAppTitle("No activity"), "title without activity");
		check(!PhoenixCore.showToast("No activity"), "toast without activity");
		check(!PhoenixCore.showMessageBox("No activity", "Title"), "dialog without activity");

		SDLActivity activity = new SDLActivity();
		Extension.mainActivity = activity;
		check(!PhoenixCore.setAppTitle(null) && !PhoenixCore.setAppTitleUtf8(null), "null title");
		check(!PhoenixCore.showToast(null) && !PhoenixCore.showToast("  ") && !PhoenixCore.showToastUtf8(null), "invalid toast text");
		activity.defer = true;
		check(PhoenixCore.setAppTitleUtf8("Nova janela 🔥".getBytes(StandardCharsets.UTF_8)), "queue UTF-8 title");
		check(activity.title == null, "title not set off UI thread");
		activity.queued.run();
		check("Nova janela 🔥".contentEquals(activity.title), "activity title");
		check("Nova janela 🔥".equals(activity.taskDescription.label), "recent task label");

		check(!PhoenixCore.showMessageBoxUtf8(null, new byte[0])
			&& !PhoenixCore.showMessageBoxUtf8(new byte[0], null), "null dialog arguments");
		check(PhoenixCore.showMessageBoxUtf8("Mensagem 世界 🔥".getBytes(StandardCharsets.UTF_8),
			"Aviso 🌍".getBytes(StandardCharsets.UTF_8)), "show UTF-8 native dialog");
		check("Mensagem 世界 🔥".equals(activity.dialogMessage) && "Aviso 🌍".equals(activity.dialogTitle),
			"Unicode dialog arguments reach SDL's Activity");
		check(activity.dialogFlags == 0x40 && activity.buttonFlags[0] == 3 && activity.buttonIds[0] == 0
			&& "OK".equals(activity.buttonTexts[0]) && activity.colors == null, "SDL simple dialog options");
		activity.dialogResult = -1;
		check(!PhoenixCore.showMessageBox("Dismissed", "Title"), "dialog dismissal reports failure");
		activity.dialogResult = 0;
		Looper.onMainThread = true;
		check(!PhoenixCore.showMessageBox("UI thread", "Title"), "UI thread call cannot deadlock");
		Looper.onMainThread = false;

		Build.VERSION.SDK_INT = 29;
		check(PhoenixCore.showToastUtf8("Aviso 🔥".getBytes(StandardCharsets.UTF_8)), "queue UTF-8 toast");
		check(Toast.last == null, "toast not shown off UI thread");
		activity.queued.run();
		Toast first = Toast.last;
		check(first.shown && "Aviso 🔥".equals(first.message), "Unicode text toast shown");
		check(first.duration == Toast.LENGTH_SHORT, "short duration");
		check(first.gravity == (Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL), "legacy bottom placement");

		Build.VERSION.SDK_INT = 33;
		check(PhoenixCore.showToast("Modern"), "queue replacement");
		activity.queued.run();
		check(first.cancelled, "previous toast cancelled");
		check(Toast.last.shown && "Modern".equals(Toast.last.message), "replacement is text-only");
		check(Toast.last.gravity == -1, "Android 11+ owns text toast placement");

		check(PhoenixCore.setAppTitle("Stale"), "queue stale request");
		Extension.mainActivity = new Activity();
		activity.queued.run();
		check("Nova janela 🔥".contentEquals(activity.title), "old activity not modified after replacement");
		Extension.mainActivity.finishing = true;
		check(!PhoenixCore.showToast("Finishing"), "finishing activity rejected");
		check(!PhoenixCore.setAppTitle("Finishing"), "finishing title rejected");
		check(!PhoenixCore.showMessageBox("Non-SDL activity", "Title"), "non-SDL activity rejected");
		Extension.mainActivity = activity;
		activity.finishing = true;
		check(!PhoenixCore.showMessageBox("Finishing", "Title"), "finishing dialog rejected");
		activity.finishing = false;
		activity.destroyed = true;
		check(!PhoenixCore.showMessageBox("Destroyed", "Title"), "destroyed dialog rejected");
		System.out.println("PhoenixStdFire Android bridge passed");
	}
}
