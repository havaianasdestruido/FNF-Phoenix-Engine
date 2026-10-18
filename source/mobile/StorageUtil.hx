/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile;

import backend.CoolUtil;
#if android
import lime.system.JNI;
#end
#if sys
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
#end

/**
 * A storage class for mobile.
 * @author Karim Akra and Homura Akemi (HomuHomu833)
 */
class StorageUtil
{
  #if sys
  #if android
  static var getExternalFilesDirJNI:Dynamic = null;

  static function getAndroidStorageDirectory():String
  {
    // PhoenixCore handles Android returning a null File. The raw Context
    // binding would call java.io.File.getAbsolutePath on that null object.
    if (getExternalFilesDirJNI == null) getExternalFilesDirJNI = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixCore', 'getExternalFilesDir',
      '()Ljava/lang/String;');
    return getExternalFilesDirJNI();
  }
  #end

  public static function getStorageDirectory():String
  {
    final directory:String = #if android getAndroidStorageDirectory() #elseif ios lime.system.System.documentsDirectory #else Sys.getCwd() #end;
    // Never turn an unavailable Android directory into "/" or a relative
    // path: that would send asset copies, mods and crash logs to the wrong root.
    if (directory == null || directory.length == 0 || !Path.isAbsolute(directory)) throw new haxe.Exception("The app storage directory is unavailable.");
    return Path.addTrailingSlash(directory);
  }

  /**
   * Prepares app-owned storage before any relative asset/mod access.
   * Android's getExternalFilesDir needs no storage or media permission on our
   * API-21+ targets. SAF handles access to user-selected files elsewhere.
   * Returns false after showing an error so Main can stop startup safely.
   */
  public static function initStorageDirectory():Bool
  {
    try
    {
      final directory:String = getStorageDirectory();
      if (!FileSystem.exists(directory)) FileSystem.createDirectory(directory);
      if (!FileSystem.isDirectory(directory)) throw new haxe.Exception('Not a directory: $directory');
      Sys.setCwd(directory);
      return true;
    }
    catch (e:Dynamic)
    {
      CoolUtil.showPopUp('The game could not open its app storage.\nMake sure device storage is available, then reopen the game.\n\n${Std.string(e)}',
        'Storage unavailable');
      return false;
    }
  }

  public static function saveContent(fileName:String, fileData:String, ?alert:Bool = true):Void
  {
    try
    {
      if (!FileSystem.exists('saves')) FileSystem.createDirectory('saves');

      File.saveContent('saves/$fileName', fileData);
      if (alert) CoolUtil.showPopUp('$fileName has been saved.', "Success!");
    }
    catch (e:Dynamic)
      if (alert) CoolUtil.showPopUp('$fileName couldn\'t be saved.\n(${e.message})', "Error!") else
        trace('$fileName couldn\'t be saved. (${e.message})');
  }
  #end
}
