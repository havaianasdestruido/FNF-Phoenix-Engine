package android.content.pm; public class PackageManager {
        public static final int PERMISSION_GRANTED = 0;
        public static final String FEATURE_TOUCHSCREEN = "android.hardware.touchscreen";
        public final java.util.Set<String> features = new java.util.HashSet<String>();
        public boolean hasSystemFeature(String name) { return features.contains(name); }}
