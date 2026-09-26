package utils;

// code from https://github.com/Slushi-Github/Slushi-Engine/blob/main/funkinscsource/slushi/others/systemUtils/HiddenProcess.hx

#if cpp
/*
 * Copyright (C)2005-2019 Haxe Foundation
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
import cpp.NativeProcess;

class Stdin extends haxe.io.Output
{
	var p:Dynamic;
	var buf:haxe.io.Bytes;

	/**
	 * Executes the `new` operation.
	 * @param p Input value for `p`.
	 */
	public function new(p:Dynamic)
	{
		this.p = p;
		buf = haxe.io.Bytes.alloc(1);
	}

	/**
	 * Executes the `close` operation.
	 * @return Result produced by `close`, when applicable.
	 */
	public override function close()
	{
		super.close();
		NativeProcess.process_stdin_close(p);
	}

	/**
	 * Executes the `writeByte` operation.
	 * @param c Input value for `c`.
	 * @return Result produced by `writeByte`, when applicable.
	 */
	public override function writeByte(c)
	{
		buf.set(0, c);
		writeBytes(buf, 0, 1);
	}

	/**
	 * Executes the `writeBytes` operation.
	 * @param buf Input value for `buf`.
	 * @param pos Input value for `pos`.
	 * @param len Input value for `len`.
	 * @return Result produced by `writeBytes`, when applicable.
	 */
	public override function writeBytes(buf:haxe.io.Bytes, pos:Int, len:Int):Int
	{
		try
		{
			return NativeProcess.process_stdin_write(p, buf.getData(), pos, len);
		}
		catch (e:Dynamic)
		{
			throw new haxe.io.Eof();
		}
		return 0;
	}
}

class Stdout extends haxe.io.Input
{
	var p:Dynamic;
	var out:Bool;
	var buf:haxe.io.Bytes;

	/**
	 * Executes the `new` operation.
	 * @param p Input value for `p`.
	 * @param out Input value for `out`.
	 */
	public function new(p:Dynamic, out)
	{
		this.p = p;
		this.out = out;
		buf = haxe.io.Bytes.alloc(1);
	}

	/**
	 * Executes the `readByte` operation.
	 * @return Result produced by `readByte`, when applicable.
	 */
	public override function readByte()
	{
		if (readBytes(buf, 0, 1) == 0)
			throw haxe.io.Error.Blocked;
		return buf.get(0);
	}

	/**
	 * Executes the `readBytes` operation.
	 * @param str Input value for `str`.
	 * @param pos Input value for `pos`.
	 * @param len Input value for `len`.
	 * @return Result produced by `readBytes`, when applicable.
	 */
	public override function readBytes(str:haxe.io.Bytes, pos:Int, len:Int):Int
	{
		var result:Int;
		try
		{
			result = out ? NativeProcess.process_stdout_read(p, str.getData(), pos, len) : NativeProcess.process_stderr_read(p, str.getData(), pos, len);
		}
		catch (e:Dynamic)
		{
			throw new haxe.io.Eof();
		}
		if (result == 0)
			throw new haxe.io.Eof();
		return result;
	}
}

class HiddenProcess
{
	var p:Dynamic;

	public var stdout(default, null):haxe.io.Input;
	public var stderr(default, null):haxe.io.Input;
	public var stdin(default, null):haxe.io.Output;

	/**
	 * Executes the `new` operation.
	 * @param cmd Input value for `cmd`.
	 * @param args Input value for `args`.
	 * @param detached Input value for `detached`.
	 */
	public function new(cmd:String, ?args:Array<String>, ?detached:Bool):Void
	{
		if (detached)
			throw "Detached process is not supported on this platform";
		p = try NativeProcess.process_run_with_show(cmd, args, 0)
		catch (e:Dynamic) throw "Process creation failure : " + cmd;
		stdin = new Stdin(p);
		stdout = new Stdout(p, true);
		stderr = new Stdout(p, false);
	}

	/**
	 * Executes the `getPid` operation.
	 * @return Result produced by `getPid`, when applicable.
	 */
	public function getPid():Int
	{
		return NativeProcess.process_pid(p);
	}

	/**
	 * Executes the `exitCode` operation.
	 * @param block Input value for `block`.
	 * @return Result produced by `exitCode`, when applicable.
	 */
	public function exitCode(block:Bool = true):Null<Int>
	{
		return NativeProcess.process_exit(p #if (haxe >= "4.3.0"), block #end);
	}

	/**
	 * Executes the `close` operation.
	 */
	public function close():Void
	{
		NativeProcess.process_close(p);
	}

	/**
	 * Executes the `kill` operation.
	 */
	public function kill():Void
	{
		NativeProcess.process_kill(p);
	}
}
#else
typedef HiddenProcess = #if sys sys.io.Process #else Dynamic #end;
#end