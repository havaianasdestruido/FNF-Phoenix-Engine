package android.view; public class DisplayCutout {
        int l,t,r,b; public DisplayCutout(int l,int t,int r,int b) {this.l=l;this.t=t;this.r=r;this.b=b;}
        public int getSafeInsetLeft(){return l;} public int getSafeInsetTop(){return t;}
        public int getSafeInsetRight(){return r;} public int getSafeInsetBottom(){return b;}}
