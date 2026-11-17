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
		return readGitHash(true);
	}

	/**
	 * The same lookup as getGitCommitHash, but returns the full 40-character
	 * hash (or null when the build does not embed commit data, e.g. local
	 * builds without `-Dcommit`, or when git is unavailable). The bottom-right
	 * freshness watermark needs the full SHA: GitHub's compare API answers
	 * 404 for abbreviated hashes.
	 */
	public static macro function getGitCommitFullHash():haxe.macro.Expr.ExprOf<String>
	{
		return readGitHash(false);
	}

	/**
	 * Shared body of both macros: runs `git rev-parse HEAD` at compile time
	 * and returns it as a string literal.
	 *
	 * Yields a null literal instead of a hash when: the build has no
	 * `-Dcommit` define (the default for builds made before the define was
	 * wired in project.hxp), the IDE is only completing code (`#if display`,
	 * where we must not spawn git on every hint), this is not a git checkout,
	 * git is not installed or the command fails. A build therefore never
	 * breaks because of the commit stamp; it just reports "Development build".
	 *
	 * @param short Return the abbreviated (7 character) hash instead of the full SHA.
	 */
	static function readGitHash(short:Bool):haxe.macro.Expr
	{
		#if (!commit || display)
		return macro $v{null};
		#else
		var pos:haxe.macro.Expr.Position = haxe.macro.Context.currentPos();

		try
		{
			var process = new sys.io.Process('git', ['rev-parse', 'HEAD']);
			if (process.exitCode() != 0)
			{
				haxe.macro.Context.info('[WARN] Could not determine current git commit; is this a proper Git repository?', pos);
				return macro $v{null};
			}

			// read the output of the process
			var commitHash:String = StringTools.trim(process.stdout.readLine());
			process.close();

			if (commitHash.length == 0) return macro $v{null};

			// haxe.macro.Context.info('[INFO] We are building in git commit ${commitHash}', pos);

			// Generates a string expression
			return macro $v{short ? commitHash.substr(0, 7) : commitHash};
		}
		catch (e:Dynamic)
		{
			haxe.macro.Context.info('[WARN] Could not determine current git commit: ' + Std.string(e), pos);
			return macro $v{null};
		}
		#end
	}
}
