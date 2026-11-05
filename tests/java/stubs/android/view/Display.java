package android.view; public class Display {
        public void getRealSize(android.graphics.Point p){} public int getRotation(){return 0;}
        public float getRefreshRate(){return 60;} public Mode[] getSupportedModes(){return new Mode[0];}
        public static class Mode {public float getRefreshRate(){return 60;} public int getModeId(){return 0;}}}
