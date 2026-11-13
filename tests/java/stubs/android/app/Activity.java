package android.app; public class Activity extends android.content.Context {
        public boolean destroyed, finishing, movedToBack; public Runnable queued; public boolean defer;
        public android.view.Window window=new android.view.Window();
        public boolean isDestroyed(){return destroyed;} public boolean isFinishing(){return finishing;}
        public android.view.Window getWindow(){return window;}
        public android.content.pm.ApplicationInfo getApplicationInfo(){return new android.content.pm.ApplicationInfo();}
        public android.view.Display getDisplay(){return null;}
        public boolean moveTaskToBack(boolean nonRoot){movedToBack=true;return true;}
        public void requestPermissions(String[] p,int code){}
        public void runOnUiThread(Runnable r){if(defer)queued=r;else r.run();}}
