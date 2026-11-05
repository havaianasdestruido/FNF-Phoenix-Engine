package android.view; public class WindowInsets {
        DisplayCutout c; public WindowInsets(DisplayCutout c){this.c=c;}
        public static class Type {public static int statusBars(){return 1;} public static int navigationBars(){return 2;}}
        public DisplayCutout getDisplayCutout(){if(android.os.Build.VERSION.SDK_INT<28) throw new AssertionError(); return c;}}
