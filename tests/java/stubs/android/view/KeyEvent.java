package android.view; public class KeyEvent {
        public static final int ACTION_DOWN=0, ACTION_UP=1;
        public static final int KEYCODE_BACK=4, KEYCODE_VOLUME_UP=24, KEYCODE_VOLUME_DOWN=25, KEYCODE_MENU=82;
        public int action, keyCode, repeatCount;
        public KeyEvent(){}
        public KeyEvent(int repeat){repeatCount=repeat;}
        public KeyEvent(int action, int keyCode, int repeat){this.action=action;this.keyCode=keyCode;this.repeatCount=repeat;}
        public int getAction(){return action;}
        public int getKeyCode(){return keyCode;}
        public int getRepeatCount(){return repeatCount;}}
