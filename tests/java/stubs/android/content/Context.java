package android.content; public class Context {
        public static final String WINDOW_SERVICE="window", DISPLAY_SERVICE="display", UI_MODE_SERVICE="uimode", INPUT_SERVICE="input", VIBRATOR_SERVICE="vibrator";
        public static final int MODE_PRIVATE=0;
        public static final android.content.SharedPreferences preferences=new android.content.SharedPreferences();
        public android.content.SharedPreferences getSharedPreferences(String name,int mode){return preferences;}
        public Object getSystemService(String name){return null;}
        public android.content.pm.PackageManager getPackageManager(){return null;}
        public int checkSelfPermission(String p){return 0;}
        public Intent registerReceiver(BroadcastReceiver r, IntentFilter f){return null;}
        public java.io.File getExternalFilesDir(String t){return null;}
        public String getPackageName(){return "quack.fnf.phoenix";}
        public void startActivity(Intent i){}
        public android.content.res.Resources getResources(){return new android.content.res.Resources();}}
