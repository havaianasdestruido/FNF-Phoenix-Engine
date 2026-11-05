package android.content; public class Context {
        public static final String WINDOW_SERVICE="window", DISPLAY_SERVICE="display"; public static final int MODE_PRIVATE=0;
        public static final android.content.SharedPreferences preferences=new android.content.SharedPreferences();
        public android.content.SharedPreferences getSharedPreferences(String name,int mode){return preferences;}
        public Object getSystemService(String name){return null;}
        public android.content.res.Resources getResources(){return new android.content.res.Resources();}}
