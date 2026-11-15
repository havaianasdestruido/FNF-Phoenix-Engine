using StringTools;

/**
 * Guard CI artifact naming, default modding levels and the release workflows
 * that consume them.
 *
 * Every CI build (Windows and Android, across main.yml, release.yml,
 * release-assets.yml and mobile-release.yml) defaults to full modding support:
 * Lua + Python + HScript (`MODDING_LEVEL=2`).
 *
 * Artifact names end with the script backends the binary really contains, so a
 * build that can run Lua/Python/HScript mods is tellable apart from one that
 * cannot before anything is downloaded:
 *
 *   <commit>_<target>_<HH>_<MM>_LUA_PYTHON_HSCRIPT   MODDING_LEVEL=2 (default)
 *   <commit>_<target>_<HH>_<MM>_LUA_HSCRIPT          MODDING_LEVEL=1
 *   <commit>_<target>_<HH>_<MM>_HSCRIPT              MODDING_LEVEL=0
 *   <commit>_<target>_<HH>_<MM>_NONE                 no script support at all
 *
 * These checks execute `.github/workflows/main.yml`'s "Resolve script modding
 * level" and "Name artifact" steps for real (with `${{ ... }}` expressions
 * substituted) so the naming cannot drift from the flags the build passes.
 *
 *   bash tests/haxe/run-ci-artifact-names.sh
 */
class CIArtifactNamesSpec
{
  static var failures:Int = 0;
  static var checks:Int = 0;

  static final EXPECTED:Array<{target:String, requested:String, level:String, tokens:String}> = [
    {target: 'windows', requested: '0', level: '0', tokens: 'HSCRIPT'},
    {target: 'windows', requested: '1', level: '1', tokens: 'LUA_HSCRIPT'},
    {target: 'windows', requested: '2', level: '2', tokens: 'LUA_PYTHON_HSCRIPT'},
    {target: 'windows', requested: '', level: '2', tokens: 'LUA_PYTHON_HSCRIPT'},
    {target: 'android', requested: '0', level: '0', tokens: 'HSCRIPT'},
    {target: 'android', requested: '1', level: '1', tokens: 'LUA_HSCRIPT'},
    {target: 'android', requested: '2', level: '2', tokens: 'LUA_PYTHON_HSCRIPT'},
    {target: 'android', requested: '', level: '2', tokens: 'LUA_PYTHON_HSCRIPT'}
  ];

  static function check(ok:Bool, label:String):Void
  {
    checks++;
    if (ok) return;
    failures++;
    Sys.println('  FAIL  $label');
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    check(actual == expected, '$label: expected "$expected", got "$actual"');
  }

  static function platformOfTarget(target:String):String
  {
    return target == 'windows' ? 'Windows' : 'Android';
  }

  static inline final GHA_OPEN:String = '$' + '{{';
  static inline final GHA_CLOSE:String = '}}';
  static inline function ghaExpr(body:String):String
  {
    return GHA_OPEN + ' ' + body + ' ' + GHA_CLOSE;
  }

  static function expand(text:String, values:Map<String, String>):String
  {
    var out = new StringBuf();
    var pos:Int = 0;
    while (pos < text.length)
    {
      final start:Int = text.indexOf(GHA_OPEN, pos);
      if (start < 0)
      {
        out.add(text.substr(pos));
        break;
      }
      out.add(text.substring(pos, start));
      final end:Int = text.indexOf(GHA_CLOSE, start + 3);
      if (end < 0)
      {
        out.add(text.substr(start));
        break;
      }
      final expr:String = text.substring(start, end + 2);
      out.add(values.exists(expr) ? values.get(expr) : '');
      pos = end + 2;
    }
    return out.toString();
  }

  static function stepBody(workflow:String, name:String):String
  {
    final marker:String = '      - name: $name\n';
    final idx:Int = workflow.indexOf(marker);
    if (idx < 0)
    {
      check(false, 'missing workflow step: $name');
      return '';
    }
    final rest:String = workflow.substr(idx + marker.length);
    final lines:Array<String> = [];
    for (line in rest.split('\n'))
    {
      if (line.startsWith('      - name:') || line.startsWith('      - uses:') || line.startsWith('      # ='))
        break;
      lines.push(line);
    }
    return lines.join('\n');
  }

  static function stepEnv(body:String):Map<String, String>
  {
    final env:Map<String, String> = [];
    var inside:Bool = false;
    for (line in body.split('\n'))
    {
      if (line == '        env:')
      {
        inside = true;
        continue;
      }
      if (!inside) continue;
      if (!line.startsWith('          ') || line.trim().length == 0)
      {
        inside = false;
        continue;
      }
      final trimmed:String = line.trim();
      final sep:Int = trimmed.indexOf(': ');
      if (sep > 0)
        env.set(trimmed.substr(0, sep), trimmed.substr(sep + 2));
    }
    return env;
  }

  static function stepScript(body:String):String
  {
    final marker:String = '        run: |\n';
    final idx:Int = body.indexOf(marker);
    if (idx < 0) return '';
    final out:Array<String> = [];
    for (line in body.substr(idx + marker.length).split('\n'))
    {
      if (line.trim().length > 0 && line.length >= 10)
        out.push(line.substr(10));
    }
    return out.join('\n');
  }

  static function tempDir():String
  {
    var base:Null<String> = null;
    for (name in ['TMPDIR', 'TEMP', 'TMP'])
    {
      base = Sys.getEnv(name);
      if (base != null && base.length > 0 && sys.FileSystem.exists(base)) break;
      base = null;
    }
    if (base == null) base = '/tmp';
    final dir:String = haxe.io.Path.removeTrailingSlashes(base.split('\\').join('/'))
      + '/phoenix-ci-names-' + Std.random(1000000);
    sys.FileSystem.createDirectory(dir);
    return dir;
  }

  static function removeTree(path:String):Void
  {
    if (!sys.FileSystem.exists(path)) return;
    if (sys.FileSystem.isDirectory(path))
    {
      for (entry in sys.FileSystem.readDirectory(path)) removeTree('$path/$entry');
      sys.FileSystem.deleteDirectory(path);
    }
    else sys.FileSystem.deleteFile(path);
  }

  static function runStep(workflow:String, name:String, values:Map<String, String>):{code:Int, stdout:String, stderr:String, output:String}
  {
    final body:String = stepBody(workflow, name);
    final rawEnv = stepEnv(body);
    final script:String = expand(stepScript(body), values);
    final tmp:String = tempDir();
    final outPath:String = '$tmp/output';
    final summaryPath:String = '$tmp/summary.md';
    final scriptPath:String = '$tmp/step.sh';
    sys.io.File.saveContent(scriptPath, script + '\n');

    final prevEnv:Map<String, Null<String>> = [];
    function setTempEnv(k:String, v:String):Void
    {
      if (!prevEnv.exists(k)) prevEnv.set(k, Sys.getEnv(k));
      Sys.putEnv(k, v);
    }

    for (k in rawEnv.keys())
      setTempEnv(k, expand(rawEnv.get(k), values));
    setTempEnv('GITHUB_OUTPUT', outPath);
    setTempEnv('GITHUB_STEP_SUMMARY', summaryPath);

    final proc = new sys.io.Process('bash', ['-e', scriptPath]);
    final stdout:String = proc.stdout.readAll().toString();
    final stderr:String = proc.stderr.readAll().toString();
    final code:Int = proc.exitCode();
    proc.close();

    for (k in prevEnv.keys())
      Sys.putEnv(k, prevEnv.get(k));

    final output:String = sys.FileSystem.exists(outPath) ? sys.io.File.getContent(outPath) : '';
    removeTree(tmp);
    return {code: code, stdout: stdout, stderr: stderr, output: output};
  }

  static function readOutput(text:String, key:String):Null<String>
  {
    final prefix:String = '$key=';
    for (line in text.split('\n'))
    {
      final clean:String = line.rtrim();
      if (clean.startsWith(prefix))
        return clean.substr(prefix.length);
    }
    return null;
  }

  static function resolveLevel(workflow:String, target:String, requested:String):{level:Null<String>, tokens:Null<String>, code:Int, stdout:String, stderr:String}
  {
    final values:Map<String, String> = [
      ghaExpr('matrix.target') => target,
      ghaExpr('matrix.name') => platformOfTarget(target),
      ghaExpr('matrix.desktop') => (target == 'windows' ? 'true' : 'false'),
      ghaExpr('inputs.moddingLevel') => requested
    ];
    final res = runStep(workflow, 'Resolve script modding level', values);
    return {
      level: readOutput(res.output, 'level'),
      tokens: readOutput(res.output, 'tokens'),
      code: res.code,
      stdout: res.stdout,
      stderr: res.stderr
    };
  }

  static function gitShortHead():String
  {
    final proc = new sys.io.Process('git', ['rev-parse', '--short=7', 'HEAD']);
    final out:String = proc.stdout.readAll().toString().trim();
    proc.exitCode();
    proc.close();
    return out;
  }

  static function countOccurrences(haystack:String, needle:String):Int
  {
    return haystack.split(needle).length - 1;
  }

  static function main():Void
  {
    final mainWorkflow:String = sys.io.File.getContent('.github/workflows/main.yml');

    // 1. Both Windows and Android resolve to full Lua + Python + HScript by default
    //    and honor explicit 0/1/2 requests without clamping Android to 0.
    for (entry in EXPECTED)
    {
      final label:String = '${entry.target} requested="${entry.requested}"';
      final res = resolveLevel(mainWorkflow, entry.target, entry.requested);
      equal(res.code, 0, '$label exit code (${res.stderr})');
      equal(res.level, entry.level, '$label resolved level');
      equal(res.tokens, entry.tokens, '$label resolved tokens');
      check(!res.stdout.contains('cannot ship the Lua/Python VMs'), '$label does not clamp mobile script VMs');
    }

    // 2. Invalid modding level fails the run cleanly.
    final invalid = resolveLevel(mainWorkflow, 'windows', '3');
    check(invalid.code != 0, 'invalid moddingLevel=3 exits non-zero');
    check(invalid.stdout.contains('::error::'), 'invalid moddingLevel=3 prints ::error::');

    // 3. Compile steps pass the resolved MODDING_LEVEL to Lime on both targets.
    for (pair in [
      {step: 'Compile (Windows)', flag: '"-DMODDING_LEVEL=$$env:MODDING_LEVEL"'},
      {step: 'Compile (Android)', flag: '"-DMODDING_LEVEL=$$MODDING_LEVEL"'}
    ])
    {
      final body:String = stepBody(mainWorkflow, pair.step);
      check(body.contains(pair.flag), '${pair.step} passes ${pair.flag}');
      check(body.contains('MODDING_LEVEL: ' + ghaExpr('steps.modding-level.outputs.level')),
        '${pair.step} binds MODDING_LEVEL from modding-level step');
    }

    // 4. Artifact names carry the exact script backend tokens.
    final commit:String = gitShortHead();
    final safeTokenRe:EReg = ~/^[A-Z]+(_[A-Z]+)*$/;
    for (entry in EXPECTED)
    {
      final res = resolveLevel(mainWorkflow, entry.target, entry.requested);
      check(res.tokens != null && safeTokenRe.match(res.tokens), 'artifact-safe tokens for ${entry.target}/${entry.requested}');
      final values:Map<String, String> = [
        ghaExpr('matrix.target') => entry.target,
        ghaExpr('matrix.name') => platformOfTarget(entry.target),
        ghaExpr('steps.modding-level.outputs.tokens') => (res.tokens ?? ''),
        ghaExpr('steps.modding-level.outputs.level') => (res.level ?? '2')
      ];
      final named = runStep(mainWorkflow, 'Name artifact', values);
      equal(named.code, 0, 'Name artifact exit code for ${entry.target}/${entry.requested}');
      final artName:Null<String> = readOutput(named.output, 'name');
      final pattern:EReg = new EReg('^' + commit + '_' + entry.target + '_[0-9]{2}_[0-9]{2}_' + entry.tokens + '$', '');
      check(artName != null && pattern.match(artName),
        'artifact name for ${entry.target}/${entry.requested} matches <commit>_<target>_HH_MM_${entry.tokens} (got "$artName")');
    }
    check(mainWorkflow.contains('name: ' + ghaExpr('steps.artifact-name.outputs.name')),
      'upload-artifact uses steps.artifact-name.outputs.name');

    // 5. Every build/release workflow defaults to MODDING_LEVEL=2 (Lua + Python + HScript)
    //    and exposes the same choice input on manual dispatch.
    for (filename in ['main.yml', 'release.yml', 'release-assets.yml', 'mobile-release.yml'])
    {
      final wf:String = sys.io.File.getContent('.github/workflows/$filename');
      check(wf.contains('run-name:'), '$filename defines run-name');
      final header:String = wf.split('run-name:')[1].split('\non:')[0];
      check(header.contains('MODDING_LEVEL'), '$filename run-name mentions MODDING_LEVEL');
      check(header.contains("'2'"), '$filename run-name defaults to MODDING_LEVEL 2');

      check(wf.contains('      moddingLevel:\n'), '$filename has moddingLevel input');
      for (inputSection in wf.split('      moddingLevel:\n').slice(1))
        check(inputSection.contains('default: "2"'), '$filename defaults moddingLevel to "2"');
      final dispatchBlock:String = wf.split('  workflow_dispatch:\n')[1];
      for (opt in ['"0"', '"1"', '"2"'])
        check(dispatchBlock.contains('- $opt'), '$filename lists workflow_dispatch moddingLevel option $opt');
    }

    for (filename in ['release.yml', 'release-assets.yml', 'mobile-release.yml'])
    {
      final wf:String = sys.io.File.getContent('.github/workflows/$filename');
      check(wf.contains('uses: ./.github/workflows/main.yml'), '$filename delegates to main.yml');
      check(wf.contains('moddingLevel: ' + ghaExpr('github.event.inputs.moddingLevel')),
        '$filename forwards github.event.inputs.moddingLevel (empty -> default 2 in main.yml)');
    }

    // 6. Release artifact download steps match platform globs regardless of token suffix.
    for (spec in [
      {file: 'release.yml', platforms: ['windows']},
      {file: 'mobile-release.yml', platforms: ['android']},
      {file: 'release-assets.yml', platforms: ['windows', 'android']}
    ])
    {
      final wf:String = sys.io.File.getContent('.github/workflows/${spec.file}');
      for (platform in spec.platforms)
        check(wf.contains('pattern: "*_${platform}_*"'), '${spec.file} downloads *_${platform}_*');
      equal(countOccurrences(wf, 'merge-multiple: true'), spec.platforms.length, '${spec.file} merge-multiple count');
    }

    if (failures > 0)
    {
      Sys.println('CIArtifactNamesSpec: $failures of $checks checks FAILED');
      Sys.exit(1);
    }
    Sys.println('CIArtifactNamesSpec: ok ($checks checks)');
  }
}
