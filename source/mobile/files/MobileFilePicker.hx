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

package mobile.files;

import haxe.io.Bytes;
#if android
import android.platform.AndroidStorage;
#elseif sys
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
#end

/**
 * Cross-platform file picker facade.
 *
 * On Android it drives the native Storage Access Framework document picker
 * (`ACTION_OPEN_DOCUMENT` / `ACTION_CREATE_DOCUMENT` /
 * `ACTION_OPEN_DOCUMENT_TREE`); on desktop it uses Lime's native file
 * dialogs. Results come back through callbacks with `null` meaning the user
 * canceled (or the operation is unsupported on this target).
 *
 * This is what editors (charting, character, ...) should use instead of
 * calling `lime.ui.FileDialog` directly, so imports/exports work on mobile.
 */
class MobileFilePicker
{
	static var activeDialog:Dynamic = null; // kept alive until the OS dialog resolves

	/**
	 * Opens a file picker and reads the picked file into memory.
	 *
	 * @param onResult   called with the picked file, or null when canceled
	 * @param extensions optional extension filter, e.g. ["json"]
	 * @param title      optional picker title
	 * @return false when picking is not supported on this target
	 */
	public static function openFile(onResult:PickedFile->Void, ?extensions:Array<String>, ?title:String):Bool
	{
		if (onResult == null)
			return false;

		#if android
		var handler:AndroidStorageResult->Void = null;
		handler = function(result:AndroidStorageResult)
		{
			AndroidStorage.onResult.remove(handler);

			if (!result.ok || result.uri.length == 0)
			{
				onResult(null);
				return;
			}

			onResult({
				name: result.name,
				uri: result.uri,
				path: "",
				data: result.data
			});
		};
		AndroidStorage.onResult.add(handler);
		AndroidStorage.openDocumentByExtensions(extensions ?? [], title);
		return true;
		#elseif sys
		var dialog = new FileDialog();
		activeDialog = dialog;

		dialog.onOpen.add(function(data:Dynamic)
		{
			var bytes:Bytes = data;
			activeDialog = null;
			onResult({
				name: "",
				uri: "",
				path: "",
				data: bytes
			});
		});
		dialog.onCancel.add(function()
		{
			activeDialog = null;
			onResult(null);
		});

		var filter:String = (extensions != null && extensions.length > 0) ? extensions[0] : null;
		return dialog.open(filter, null, title);
		#else
		onResult(null);
		return false;
		#end
	}

	/**
	 * Opens a "save as" picker and writes the data to the picked location.
	 *
	 * @param onDone called with the resulting path (desktop) or content URI
	 *               (Android), or null when canceled/unsupported
	 * @return false when saving is not supported on this target
	 */
	public static function saveFile(data:Bytes, suggestedName:String, ?mime:String, ?title:String, onDone:String->Void = null):Bool
	{
		if (data == null)
			return false;

		#if android
		var handler:AndroidStorageResult->Void = null;
		handler = function(result:AndroidStorageResult)
		{
			AndroidStorage.onResult.remove(handler);

			if (!result.ok || result.uri.length == 0)
			{
				if (onDone != null)
					onDone(null);
				return;
			}

			var success = AndroidStorage.writeUriBytes(result.uri, data);
			if (onDone != null)
				onDone(success ? result.uri : null);
		};
		AndroidStorage.onResult.add(handler);
		AndroidStorage.createDocument(mime ?? guessMime(suggestedName), suggestedName);
		return true;
		#elseif sys
		var dialog = new FileDialog();
		activeDialog = dialog;

		dialog.onSave.add(function(path:String)
		{
			activeDialog = null;
			if (onDone != null)
				onDone(path);
		});
		dialog.onCancel.add(function()
		{
			activeDialog = null;
			if (onDone != null)
				onDone(null);
		});

		var extension:String = suggestedName != null ? haxe.io.Path.extension(suggestedName) : null;
		return dialog.save(data, extension, suggestedName, title);
		#else
		if (onDone != null)
			onDone(null);
		return false;
		#end
	}

	/** Convenience wrapper for saving text content. */
	public static function saveText(text:String, suggestedName:String, ?mime:String, ?title:String, onDone:String->Void = null):Bool
	{
		return saveFile(Bytes.ofString(text ?? ""), suggestedName, mime, title, onDone);
	}

	/**
	 * Opens a directory picker.
	 * @param onResult called with the picked directory path (desktop) or
	 *                 tree URI (Android), or null when canceled
	 */
	public static function openFolder(onResult:String->Void, ?title:String):Bool
	{
		if (onResult == null)
			return false;

		#if android
		var handler:AndroidStorageResult->Void = null;
		handler = function(result:AndroidStorageResult)
		{
			AndroidStorage.onResult.remove(handler);
			onResult(result.ok && result.uri.length > 0 ? result.uri : null);
		};
		AndroidStorage.onResult.add(handler);
		AndroidStorage.openDocumentTree();
		return true;
		#elseif sys
		var dialog = new FileDialog();
		activeDialog = dialog;

		dialog.onSelect.add(function(path:String)
		{
			activeDialog = null;
			onResult(path);
		});
		dialog.onCancel.add(function()
		{
			activeDialog = null;
			onResult(null);
		});

		return dialog.browse(FileDialogType.OPEN_DIRECTORY, null, null, title);
		#else
		onResult(null);
		return false;
		#end
	}

	static function guessMime(fileName:String):String
	{
		var extension = haxe.io.Path.extension(fileName ?? "");
		var mime = #if android AndroidStorage.extensionToMime(extension) #else null #end;
		return mime ?? 'application/octet-stream';
	}
}

/** A file returned by `MobileFilePicker.openFile`. */
typedef PickedFile =
{
	/** Display name of the picked file (may be "" on desktop). */
	var name:String;

	/** Android content:// URI ("" on desktop). */
	var uri:String;

	/** Filesystem path when one applies ("" for SAF picks). */
	var path:String;

	/** File contents. */
	var data:Bytes;
}

#if android
private typedef AndroidStorageResult = android.platform.AndroidBridge.AndroidStorageResult;
#end
