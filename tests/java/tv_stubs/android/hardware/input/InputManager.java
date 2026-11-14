package android.hardware.input; public class InputManager {
        public interface InputDeviceListener {
                void onInputDeviceAdded(int id);
                void onInputDeviceRemoved(int id);
                void onInputDeviceChanged(int id);
        }
        public void registerInputDeviceListener(InputDeviceListener l, android.os.Handler h){}
        public void unregisterInputDeviceListener(InputDeviceListener l){}}
