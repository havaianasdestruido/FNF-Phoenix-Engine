/*
 * Copyright (C) 2026 Phoenix Engine Contributors
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

package ios.platform;

/**
 * iOS file/storage helpers.
 *
 * iOS sandboxing is simpler than Android SAF: the app's documents directory
 * (`lime.system.System.documentsDirectory`) is readable/writable without
 * extra permissions, and user imports use the system document picker
 * (`UIDocumentPickerViewController`) when hxcpp's ObjC bridge is available.
 *
 * Like the other platform modules, every call is safe on non-iOS targets.
 */
class IOSStorage
{
	/** App documents directory (empty on other platforms). */
	public static function getDocumentsDirectory():String
	{
		#if ios
		return lime.system.System.documentsDirectory;
		#else
		return "";
		#end
	}

	/** Whether the current iOS version supports the modern file picker (iOS 11+). */
	public static function isPickerAvailable():Bool
	{
		#if ios
		return true;
		#else
		return false;
		#end
	}

	/** iOS version string (empty on other platforms). */
	public static function getOSVersion():String
	{
		#if ios
		try
		{
			return lime.system.System.platformVersion;
		}
		catch (e:Dynamic)
		{
			return "";
		}
		#else
		return "";
		#end
	}
}
