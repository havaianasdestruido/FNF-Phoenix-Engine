/*
 * Apache License, Version 2.0
 *
 * Copyright (c) 2026 Phoenix Engine contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law and agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * CommitWatermark.hx
 * Bottom-right build-freshness watermark, a sibling of the FPS counter:
 *
 *   42 commits behind   <- top line, fades green -> yellow -> orange -> red
 *   Commit a1b2c3d      <- bottom line, dim grey
 *
 * The top line reports how many commits the running build is behind
 * upstream `main`, answered by GitHub's compare API once per session
 * (non-blocking; a worker thread on native targets with Lima's onUpdate
 * signal delivering the result back to the main thread). It respects the
 * same opt-out as the update checker (`Check for Updates` / flags) and
 * degrades silently to showing only the commit id when offline, on
 * GitHub errors or for commits GitHub does not know (local builds).
 */
package debug;

import backend.ClientPrefs;
import backend.CommitFreshness;
import backend.HaxeCommit;
import backend.PhoenixVersion;
import backend.RuntimeFlags;
import backend.VLog;

import flixel.FlxG;

import haxe.Http;

#if (lime && sys && target.threaded && CHECK_FOR_UPDATES)
import lime.app.Application;
import sys.thread.Deque;
import sys.thread.Thread;
#end

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;

class CommitWatermark extends Sprite
{
  static final MARGIN_X:Float = 10;
  static final MARGIN_Y:Float = 6;
  static final LINE_GAP:Float = 2;
  static final FONT:String = 'VCR OSD Mono';
  static final FONT_SIZE:Int = 13;
  /** Give up if the worker thread has not delivered a result within this many seconds. */
  static final TIMEOUT_SECONDS:Float = 15;

  static final FULL_HASH:Null<String> = HaxeCommit.getGitCommitFullHash();
  static final SHORT_HASH:Null<String> = FULL_HASH == null ? null : FULL_HASH.substr(0, 7);

  var behindField:TextField;
  var commitField:TextField;
  var settled:Bool = false;

  #if (lime && sys && target.threaded && CHECK_FOR_UPDATES)
  var messages:Deque<Dynamic>;
  var polling:Bool = false;
  var elapsed:Float = 0;
  #end

  public function new()
  {
    super();

    commitField = newTextField(CommitFreshness.COLOR_DIM);
    behindField = newTextField(CommitFreshness.COLOR_DIM);

    commitField.text = CommitFreshness.commitLabel(SHORT_HASH);

    if (FULL_HASH == null)
    {
      behindField.visible = false;
    }
    else
    {
      #if CHECK_FOR_UPDATES
      if (ClientPrefs.checkForUpdates)
      {
        behindField.text = CommitFreshness.LABEL_CHECKING;
        behindField.visible = true;
        startCheck();
      }
      else
      {
        behindField.visible = false;
      }
      #else
      behindField.visible = false;
      #end
    }

    addChild(behindField);
    addChild(commitField);

    addEventListener(Event.ADDED_TO_STAGE, function(e:Event) { reposition(); });
    FlxG.signals.gameResized.add(function(w, h) { reposition(); });
    reposition();
  }

  function newTextField(color:Int):TextField
  {
    var field:TextField = new TextField();
    field.selectable = false;
    field.mouseEnabled = false;
    field.defaultTextFormat = new TextFormat(FONT, FONT_SIZE, color);
    field.autoSize = TextFieldAutoSize.LEFT;
    field.multiline = false;
    field.text = '';
    setFieldColor(field, color);
    return field;
  }

  /** Stacks the two lines against the bottom-right corner of the stage. */
  public function reposition():Void
  {
    if (stage == null) return;

    final stageWidth:Float = stage.stageWidth;
    final stageHeight:Float = stage.stageHeight;

    commitField.x = stageWidth - commitField.textWidth - MARGIN_X;
    commitField.y = stageHeight - commitField.height - MARGIN_Y;

    if (behindField.visible)
    {
      behindField.x = stageWidth - behindField.textWidth - MARGIN_X;
      behindField.y = commitField.y - behindField.height - LINE_GAP;
    }
  }

  function startCheck():Void
  {
    #if CHECK_FOR_UPDATES
    final sha:Null<String> = FULL_HASH;
    if (sha == null) return;

    #if (lime && sys && target.threaded)
    try
    {
      if (Application.current != null)
      {
        messages = new Deque<Dynamic>();
        elapsed = 0;
        polling = true;
        Application.current.onUpdate.add(onPoll);
        Thread.create(function()
        {
          performRequest(sha, function(data:String)
          {
            messages.add({payload: data, error: null});
          }, function(error:String)
          {
            messages.add({payload: null, error: error});
          });
        });
        return;
      }
    }
    catch (e:Dynamic)
    {
      stopPolling();
      finish(null, 'Could not start the freshness check: ' + e);
      return;
    }
    #end

    performRequest(sha, function(data:String) finish(data, null), function(error:String) finish(null, error));
    #end
  }

  #if (lime && sys && target.threaded && CHECK_FOR_UPDATES)
  function onPoll(delta:Float):Void
  {
    if (!polling) return;

    var message:Dynamic = messages.pop(false);
    if (message == null)
    {
      elapsed += delta;
      if (elapsed >= TIMEOUT_SECONDS)
      {
        stopPolling();
        finish(null, 'Timed out waiting for GitHub.');
      }
      return;
    }
    stopPolling();
    finish(message.payload, message.error);
  }

  function stopPolling():Void
  {
    if (polling && Application.current != null) Application.current.onUpdate.remove(onPoll);
    polling = false;
  }
  #end

  function performRequest(sha:String, onData:String->Void, onError:String->Void):Void
  {
    var finished:Bool = false;
    function fail(message:String):Void
    {
      if (finished) return;
      finished = true;
      onError(message);
    }

    try
    {
      final url:String = RuntimeFlags.url('urls.compareApi', PhoenixVersion.COMPARE_API_URL) + sha;
      final http:Http = new Http(url);
      http.setHeader('Accept', 'application/vnd.github+json');
      http.setHeader('User-Agent', 'Phoenix-Engine-Commit-Watermark');
      http.setHeader('X-GitHub-Api-Version', '2022-11-28');
      #if sys
      http.cnxTimeout = 10;
      #end
      http.onStatus = function(status:Int):Void
      {
        if (status < 200 || status >= 300) fail('GitHub returned HTTP ' + status + '.');
      };
      http.onError = function(error:String):Void fail('Freshness check failed: ' + error);
      http.onData = function(data:String):Void
      {
        if (finished) return;
        finished = true;
        onData(data);
      };
      http.request(false);
    }
    catch (e:Dynamic)
    {
      fail('Freshness check failed: ' + e);
    }
  }

  /** Settles the top line: fades the hue by age, or greys out when unknown. */
  function finish(payload:Null<String>, error:Null<String>):Void
  {
    if (settled) return;
    settled = true;

    if (error != null)
    {
      VLog.log('CommitWatermark', error);
      applyBehind(null);
      return;
    }

    applyBehind(CommitFreshness.parseBehindCount(payload));
  }

  function applyBehind(behind:Null<Int>):Void
  {
    if (!behindField.visible) behindField.visible = true;
    behindField.text = CommitFreshness.behindLabel(behind);
    setFieldColor(behindField, behind == null ? CommitFreshness.COLOR_DIM : CommitFreshness.behindColor(behind));
    reposition();
  }

  function setFieldColor(field:TextField, color:Int):Void
  {
    #if flash
    var colorUInt:UInt = color;
    if (colorUInt != field.textColor) field.textColor = colorUInt;
    #else
    if (color != field.textColor) field.textColor = color;
    #end
  }
}
