package android.util; public class Log {
        public static int errors,warnings;
        public static int w(String t,String m){warnings++;return 0;}
        public static int e(String t,String m){errors++;return 0;}
        public static int e(String t,String m,Throwable e){errors++;return 0;}}
