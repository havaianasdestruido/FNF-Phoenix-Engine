package android.widget; public class FrameLayout extends android.view.View {
        int l,t,r,b; public FrameLayout(android.content.Context c){}
        public void setPadding(int l,int t,int r,int b){this.l=l;this.t=t;this.r=r;this.b=b;}
        public int getPaddingLeft(){return l;} public int getPaddingTop(){return t;}
        public int getPaddingRight(){return r;} public int getPaddingBottom(){return b;}
        public void addView(android.view.View view,android.view.ViewGroup.LayoutParams params){}
        public void requestApplyInsets(){} public android.view.WindowInsets onApplyWindowInsets(android.view.WindowInsets i){return i;}}
