package android.content; public class SharedPreferences {
    public String value; public boolean fail; public Editor edit(){return new Editor();}
    public String getString(String key,String fallback){if(fail)throw new IllegalStateException("test");return value==null?fallback:value;}
    public class Editor {public Editor putString(String key,String v){value=v;return this;} public Editor remove(String key){value=null;return this;} public void apply(){if(fail)throw new IllegalStateException("test");}}}
