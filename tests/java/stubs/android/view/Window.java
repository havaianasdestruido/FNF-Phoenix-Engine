package android.view; public class Window {
        public int updates; public boolean fail; public WindowManager.LayoutParams attrs=new WindowManager.LayoutParams();
        public View decor=new View(); public WindowInsetsController controller=new WindowInsetsController();
        public WindowManager.LayoutParams getAttributes(){return attrs;}
        public void setAttributes(WindowManager.LayoutParams a){if(fail)throw new IllegalStateException("test");updates++;attrs=a;}
        public void addFlags(int flags){attrs.flags|=flags;} public void clearFlags(int flags){attrs.flags&=~flags;}
        public View getDecorView(){return decor;} public WindowInsetsController getInsetsController(){return controller;}}
