package org.haxe.extension; public class Extension {
        public static android.app.Activity mainActivity; public static android.content.Context mainContext;
        public boolean onBackPressed(){return true;}
        public boolean onRequestPermissionsResult(int r,String[] p,int[] g){return true;}
        public void onCreate(android.os.Bundle s){} public void onStart(){} public void onResume(){}
        public void onPause(){} public void onStop(){} public void onRestart(){}
        public void onLowMemory(){} public void onTrimMemory(int l){}
        public void onSaveInstanceState(android.os.Bundle b){} public void onRestoreInstanceState(android.os.Bundle b){}
        public void onDestroy(){}}
