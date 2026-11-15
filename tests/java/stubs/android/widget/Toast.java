package android.widget;

import android.content.Context;

public class Toast
{
  public static final int LENGTH_SHORT = 0;
  public static Toast last;
  public final String message;
  public final int duration;
  public int gravity = -1;
  public int yOffset = 24;
  public boolean shown, cancelled;

  private Toast(String message, int duration) { this.message = message; this.duration = duration; }
  public static Toast makeText(Context context, CharSequence message, int duration)
  {
    last = new Toast(message.toString(), duration);
    return last;
  }
  public void setGravity(int value, int x, int y) { gravity = value; yOffset = y; }
  public int getYOffset() { return yOffset; }
  public void show() { shown = true; }
  public void cancel() { cancelled = true; }
}
