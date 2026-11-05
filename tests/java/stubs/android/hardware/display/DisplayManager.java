package android.hardware.display; public class DisplayManager {
        public interface DisplayListener {void onDisplayAdded(int i);void onDisplayRemoved(int i);void onDisplayChanged(int i);}
        public void registerDisplayListener(DisplayListener l,Object h){} public void unregisterDisplayListener(DisplayListener l){}}
