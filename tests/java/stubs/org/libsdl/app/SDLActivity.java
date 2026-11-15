package org.libsdl.app;

/** Minimal SDL Activity double for PhoenixCore's native-dialog bridge. */
public class SDLActivity extends android.app.Activity {
    public int dialogFlags, dialogResult = 0;
    public String dialogTitle, dialogMessage;
    public int[] buttonFlags, buttonIds, colors;
    public String[] buttonTexts;

    public int messageboxShowMessageBox(int flags, String title, String message,
            int[] flagsForButtons, int[] ids, String[] texts, int[] dialogColors) {
        dialogFlags = flags;
        dialogTitle = title;
        dialogMessage = message;
        buttonFlags = flagsForButtons;
        buttonIds = ids;
        buttonTexts = texts;
        colors = dialogColors;
        return dialogResult;
    }
}
