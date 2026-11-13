package android.content; public class Intent {
        public static final String ACTION_MAIN="android.intent.action.MAIN";
        public static final String ACTION_BATTERY_CHANGED="android.intent.action.BATTERY_CHANGED";
        public static final int FLAG_ACTIVITY_NEW_TASK=0x10000000;
        public Intent(){} public Intent(String action){}
        public android.net.Uri getData(){return null;}
        public String getAction(){return null;}
        public Intent setData(android.net.Uri data){return this;}
        public Intent addFlags(int flags){return this;}
        public int getIntExtra(String name,int d){return d;}}
