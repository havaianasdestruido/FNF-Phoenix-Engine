package android.os;

/** Allows a host-JVM test to simulate the Android UI thread. */
public class Looper {
    private static final Looper MAIN = new Looper();
    public static boolean onMainThread;
    public static Looper myLooper() { return onMainThread ? MAIN : null; }
    public static Looper getMainLooper() { return MAIN; }
}
