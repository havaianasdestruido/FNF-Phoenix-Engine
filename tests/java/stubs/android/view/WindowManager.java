package android.view; public class WindowManager {
        public Display getDefaultDisplay(){return null;} public static class LayoutParams {
        public static final int LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS=3,FLAG_FULLSCREEN=1024,FLAG_FORCE_NOT_FULLSCREEN=2048;
        public int layoutInDisplayCutoutMode,preferredDisplayModeId,flags;}}
