package org.haxe.lime; public class GameActivity extends android.app.Activity {
        public android.view.View content;
        protected void onCreate(android.os.Bundle b){org.haxe.extension.Extension.mainActivity=this;org.haxe.extension.Extension.mainContext=this;setContentView(new android.view.View());}
        protected void onResume(){} public void onWindowFocusChanged(boolean f){}
        protected void onDestroy(){destroyed=true;}
        public void setContentView(android.view.View v){content=v;}
        public android.content.Intent getIntent(){return null;} public void setIntent(android.content.Intent i){}
        protected void onNewIntent(android.content.Intent i){}
        public boolean onKeyDown(int c,android.view.KeyEvent e){return false;}
        public boolean onKeyUp(int c,android.view.KeyEvent e){return false;}}
