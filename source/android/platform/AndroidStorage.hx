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

package android.platform;

import flixel.util.FlxSignal;
import haxe.io.Bytes;
#if android
import lime.system.JNI;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#end

/**
 * Android Storage Access Framework (SAF) integration plus content:// URI
 * support. Use this to import/export user files through the native document
 * picker (`ACTION_OPEN_DOCUMENT`, `ACTION_CREATE_DOCUMENT`,
 * `ACTION_OPEN_DOCUMENT_TREE`).
 *
 * Picker results arrive through `onResult` with the document URI, display
 * name and (for open requests) the file contents.
 */
class AndroidStorage
{
	// Request codes, mirrored from PhoenixStorage.java.
	public static inline final REQUEST_OPEN_DOCUMENT:Int = 9101;
	public static inline final REQUEST_CREATE_DOCUMENT:Int = 9102;
	public static inline final REQUEST_OPEN_DOCUMENT_TREE:Int = 9103;

	/** Fired with every picker result (including cancellation). */
	public static var onResult(get, never):FlxTypedSignal<AndroidStorageResult->Void>;

	static inline function get_onResult():FlxTypedSignal<AndroidStorageResult->Void>
		return AndroidBridge.onStorageResult;

	// ------------------------------------------------------------------
	// Pickers
	// ------------------------------------------------------------------

	/**
	 * Opens the native document picker.
	 * @param mimeTypes comma separated MIME types, e.g. "application/json"
	 *                  (empty/null = any type).
	 */
	public static function openDocument(?mimeTypes:String, ?title:String):Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		openDocument_jni(mimeTypes ?? "", title ?? "");
		#end
	}

	/** Convenience wrapper for openDocument with a list of extensions mapped to MIME types. */
	public static function openDocumentByExtensions(extensions:Array<String>, ?title:String):Void
	{
		var mimes:Array<String> = [];
		for (extension in extensions)
		{
			var mime = extensionToMime(extension);
			if (mime != null && !mimes.contains(mime))
				mimes.push(mime);
		}
		openDocument(mimes.length > 0 ? mimes.join(',') : null, title);
	}

	/** Opens the native "create file" picker (save-as). */
	public static function createDocument(mime:String, suggestedName:String):Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		createDocument_jni(mime ?? "application/octet-stream", suggestedName ?? "");
		#end
	}

	/** Opens the native directory picker. */
	public static function openDocumentTree():Void
	{
		#if android
		AndroidBridge.ensureRegistered();
		openDocumentTree_jni();
		#end
	}

	// ------------------------------------------------------------------
	// content:// URI support
	// ------------------------------------------------------------------

	public static function isContentUri(uri:String):Bool
	{
		return uri != null && StringTools.startsWith(uri, 'content://');
	}

	/** Reads a content:// URI into memory. */
	public static function readUriBytes(uri:String):Null<Bytes>
	{
		#if android
		var data:Dynamic = readUriBytes_jni(uri);
		if (data == null)
			return null;
		return try Bytes.ofData(data) catch (e:Dynamic) null;
		#else
		return null;
		#end
	}

	/** Reads a content:// URI as UTF-8 text. */
	public static function readUriText(uri:String):Null<String>
	{
		var bytes = readUriBytes(uri);
		return bytes == null ? null : bytes.toString();
	}

	/** Writes bytes to a content:// URI previously returned by createDocument. */
	public static function writeUriBytes(uri:String, data:Bytes):Bool
	{
		#if android
		if (data == null)
			return false;
		return writeUriBytes_jni(uri, data.getData());
		#else
		return false;
		#end
	}

	public static function writeUriText(uri:String, text:String):Bool
	{
		return writeUriBytes(uri, Bytes.ofString(text ?? ""));
	}

	/** Display name of a content:// (or file) URI, "" when unknown. */
	public static function getDisplayName(uri:String):String
	{
		#if android
		var name:String = getDisplayName_jni(uri);
		return name ?? "";
		#else
		return "";
		#end
	}

	/** Size in bytes of a content:// (or file) URI, -1 when unknown. */
	public static function getUriSize(uri:String):Int
	{
		#if android
		var size:Float = getUriSize_jni(uri);
		return Std.int(size);
		#else
		return -1;
		#end
	}

	/**
	 * Copies a content:// URI into the app's storage directory so it can be
	 * used through regular filesystem paths. Returns the destination path or
	 * null on failure.
	 */
	public static function importUri(uri:String, destinationPath:String):Null<String>
	{
		#if (android && sys)
		if (copyUriToFile_jni(uri, destinationPath))
			return destinationPath;
		return null;
		#else
		return null;
		#end
	}

	/** Copies a regular file into a content:// URI (for export flows). */
	public static function exportFileToUri(filePath:String, uri:String):Bool
	{
		#if (android && sys)
		if (!FileSystem.exists(filePath))
			return false;
		return writeUriBytes(uri, File.getBytes(filePath));
		#else
		return false;
		#end
	}

	/** Persists read/write permission grants for a picked URI across reboots. */
	public static function persistUriPermission(uri:String, writable:Bool = true):Void
	{
		#if android
		persistUriPermission_jni(uri, writable);
		#end
	}

	/** Maps common file extensions to MIME types. */
	public static function extensionToMime(extension:String):Null<String>
	{
		if (extension == null)
			return null;

		extension = extension.toLowerCase();
		if (StringTools.startsWith(extension, '.'))
			extension = extension.substr(1);

		return switch (extension)
		{
			case 'json': 'application/json';
			case 'txt': 'text/plain';
			case 'xml': 'application/xml';
			case 'png': 'image/png';
			case 'jpg', 'jpeg': 'image/jpeg';
			case 'gif': 'image/gif';
			case 'webp': 'image/webp';
			case 'ogg': 'audio/ogg';
			case 'mp3': 'audio/mpeg';
			case 'wav': 'audio/wav';
			case 'zip': 'application/zip';
			case 'pdf': 'application/pdf';
			case 'lua': 'text/x-lua';
			default: null;
		}
	}

	// ------------------------------------------------------------------
	// JNI bindings
	// ------------------------------------------------------------------

	#if android
	static var _openDocument:Dynamic = null;

	static function openDocument_jni(mimeTypes:String, title:String):Void
	{
		if (_openDocument == null)
			_openDocument = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'openDocument',
				'(Ljava/lang/String;Ljava/lang/String;)V');
		_openDocument(mimeTypes, title);
	}

	static var _createDocument:Dynamic = null;

	static function createDocument_jni(mime:String, name:String):Void
	{
		if (_createDocument == null)
			_createDocument = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'createDocument',
				'(Ljava/lang/String;Ljava/lang/String;)V');
		_createDocument(mime, name);
	}

	static var _openDocumentTree:Dynamic = null;

	static function openDocumentTree_jni():Void
	{
		if (_openDocumentTree == null)
			_openDocumentTree = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'openDocumentTree', '()V');
		_openDocumentTree();
	}

	static var _readUriBytes:Dynamic = null;

	static function readUriBytes_jni(uri:String):Dynamic
	{
		if (_readUriBytes == null)
			_readUriBytes = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'readUriBytes', '(Ljava/lang/String;)[B');
		return _readUriBytes(uri);
	}

	static var _writeUriBytes:Dynamic = null;

	static function writeUriBytes_jni(uri:String, data:Dynamic):Bool
	{
		if (_writeUriBytes == null)
			_writeUriBytes = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'writeUriBytes', '(Ljava/lang/String;[B)Z');
		return _writeUriBytes(uri, data);
	}

	static var _getDisplayName:Dynamic = null;

	static function getDisplayName_jni(uri:String):String
	{
		if (_getDisplayName == null)
			_getDisplayName = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'getDisplayName',
				'(Ljava/lang/String;)Ljava/lang/String;');
		return _getDisplayName(uri);
	}

	static var _getUriSize:Dynamic = null;

	static function getUriSize_jni(uri:String):Float
	{
		if (_getUriSize == null)
			_getUriSize = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'getUriSize', '(Ljava/lang/String;)J');
		return _getUriSize(uri);
	}

	static var _copyUriToFile:Dynamic = null;

	static function copyUriToFile_jni(uri:String, destination:String):Bool
	{
		if (_copyUriToFile == null)
			_copyUriToFile = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'copyUriToFile',
				'(Ljava/lang/String;Ljava/lang/String;)Z');
		return _copyUriToFile(uri, destination);
	}

	static var _persistUriPermission:Dynamic = null;

	static function persistUriPermission_jni(uri:String, writable:Bool):Void
	{
		if (_persistUriPermission == null)
			_persistUriPermission = JNI.createStaticMethod('quack.fnf.phoenix.android.PhoenixStorage', 'persistUriPermission',
				'(Ljava/lang/String;Z)V');
		_persistUriPermission(uri, writable);
	}
	#end
}
