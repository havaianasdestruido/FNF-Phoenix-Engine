package android.view; public class InputDevice {
        public static final int SOURCE_GAMEPAD=0x00000401, SOURCE_JOYSTICK=0x01000010;
        public static int[] getDeviceIds(){return new int[0];}
        public static InputDevice getDevice(int id){return null;}
        public int getId(){return 0;} public String getName(){return "";} public String getDescriptor(){return "";}
        public int getSources(){return 0;} public boolean isVirtual(){return false;}
        public int getVendorId(){return 0;} public int getProductId(){return 0;}
        public android.os.Vibrator getVibrator(){return new android.os.Vibrator();}}
