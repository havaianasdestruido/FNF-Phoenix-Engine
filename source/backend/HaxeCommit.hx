/*
 * Apache License, Version 2.0
 *
 * Copyright (c) 2021 MasterEric
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * HaxeCommit.hx
 * Retrieves the first seven characters of the commit hash for this repo and stores it as a variable.
 * @see https://code.haxe.org/category/macros/add-git-commit-hash-in-build.html
 */
package backend;

// this is from enigma engine btw, kudos to EliteMasterEric
// yes it's on the haxe cookbook, but I'm lazy :P
class HaxeCommit
{
	/**
	 * First seven characters of the commit this build was made from, or null
	 * when the build has no `-Dcommit` stamp (or is running for IDE
	 * completion), see project.hxp's `configureCompileDefines`.
	 */
	public static macro function getGitCommitHash():haxe.macro.Expr.ExprOf<String>
	{
		#if (!commit || display)
		return macro $v{null};
		#else
		final pos = haxe.macro.Context.currentPos();

		try
		{
			final process = new sys.io.Process('git', ['rev-parse', 'HEAD']);
			if (process.exitCode() != 0)
			{
				process.close();
				haxe.macro.Context.info('[WARN] Could not determine current git commit; is this a proper Git repository?', pos);
				return macro $v{null};
			}

			final commitHash:String = StringTools.trim(process.stdout.readLine());
			process.close();

			if (commitHash.length == 0) return macro $v{null};

			return macro $v{commitHash.substr(0, 7)};
		}
		catch (e:Dynamic)
		{
			haxe.macro.Context.info('[WARN] Could not determine current git commit: ' + Std.string(e), pos);
			return macro $v{null};
		}
		#end
	}

	/**
	 * The same lookup as getGitCommitHash, but returns the full 40-character
	 * hash (or null when the build does not embed commit data, e.g. local
	 * builds without `-Dcommit`, or when git is unavailable). The bottom-right
	 * freshness watermark needs the full SHA: GitHub's compare API answers
	 * 404 for abbreviated hashes.
	 *
	 * Both macros repeat the small git probe instead of sharing a helper: a
	 * `$v{...}` splice (and `haxe.macro.Context` itself) is only reachable
	 * inside a macro body, so a shared plain function cannot build these
	 * expressions - `macro` inside one fails with "Uncaught exception
	 * macro-in-macro".
	 */
	public static macro function getGitCommitFullHash():haxe.macro.Expr.ExprOf<String>
	{
		#if (!commit || display)
		return macro $v{null};
		#else
		final pos = haxe.macro.Context.currentPos();

		try
		{
			final process = new sys.io.Process('git', ['rev-parse', 'HEAD']);
			if (process.exitCode() != 0)
			{
				process.close();
				haxe.macro.Context.info('[WARN] Could not determine current git commit; is this a proper Git repository?', pos);
				return macro $v{null};
			}

			final commitHash:String = StringTools.trim(process.stdout.readLine());
			process.close();

			if (commitHash.length == 0) return macro $v{null};

			return macro $v{commitHash};
		}
		catch (e:Dynamic)
		{
			haxe.macro.Context.info('[WARN] Could not determine current git commit: ' + Std.string(e), pos);
			return macro $v{null};
		}
		#end
	}
}
