package android.view; public class View {
        public static final int SYSTEM_UI_FLAG_VISIBLE=0,SYSTEM_UI_FLAG_IMMERSIVE=1,SYSTEM_UI_FLAG_LAYOUT_STABLE=2,
        SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION=4,SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN=8,SYSTEM_UI_FLAG_HIDE_NAVIGATION=16,
        SYSTEM_UI_FLAG_FULLSCREEN=32,SYSTEM_UI_FLAG_IMMERSIVE_STICKY=64;
        public int systemUiVisibility; public void setSystemUiVisibility(int flags){systemUiVisibility=flags;} public WindowInsets getRootWindowInsets(){return null;}
        public void requestApplyInsets(){} public void requestLayout(){}}
