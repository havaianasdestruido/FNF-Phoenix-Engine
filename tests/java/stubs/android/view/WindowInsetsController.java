package android.view; public class WindowInsetsController {
        public static final int BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE=2,BEHAVIOR_SHOW_BARS_BY_SWIPE=1;
        public int shown,hidden,behavior=-1; public void show(int t){shown=t;hidden=0;} public void hide(int t){hidden=t;shown=0;} public void setSystemBarsBehavior(int b){behavior=b;}}
