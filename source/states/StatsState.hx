package states;

import backend.ClientPrefs;
import backend.DiscordClient;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import backend.Paths;
import backend.PlayerSettings;
import backend.PlayerStats;
import backend.PlayerStats.ModPlayEntry;
import backend.PlayerStats.PlayerStatsSnapshot;
import backend.PlayerStats.SongPlayEntry;
import backend.ViewportVisuals;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.system.Clipboard;
import mobile.MobileControls;
import objects.Alphabet;
import objects.HoldToConfirm;
import objects.MovingCheckerboard;
import objects.TouchTarget;

using StringTools;

/**
 * Lifetime player statistics dashboard, linked from the Awards section
 * (`states.AchievementsMenuState` / `states.MainMenuState`'s `awards` entry).
 *
 * Shows lifetime playtime (updating live while open and never stopping at the
 * 50-hour badge), songs finished, full combos, deaths, a per-judgement note
 * breakdown, and the most-played songs and mods.
 */
class StatsState extends MusicBeatState
{
  static inline final HEADER_HEIGHT:Int = 56;
  static inline final FOOTER_HEIGHT:Int = 44;
  static inline final TAB_WIDTH:Int = 250;
  static inline final TAB_HEIGHT:Int = 38;
  static inline final TAB_GAP:Int = 16;
  static inline final CARD_GAP:Int = 14;
  static inline final MAX_TOP_ENTRIES:Int = 10;
  static inline final MIN_LIST_ROWS:Int = 5;
  static inline final SCROLL_SPEED:Float = 440;
  static inline final WHEEL_STEP:Float = 54;
  static inline final HINT_SECONDS:Float = 3.5;

  static inline final COLOR_CARD_BG:Int = 0xB80A1320;
  static inline final COLOR_BAR_BG:Int = 0xAA000000;
  static inline final COLOR_TAB_ACTIVE:Int = 0xFF1F4E79;
  static inline final COLOR_TAB_IDLE:Int = 0x77192838;
  static inline final COLOR_ACCENT_CYAN:Int = 0xFF5CE1E6;
  static inline final COLOR_ACCENT_GOLD:Int = 0xFFFFD166;
  static inline final COLOR_ACCENT_LIME:Int = 0xFF7CFC8A;
  static inline final COLOR_ACCENT_CORAL:Int = 0xFFFF6B6B;
  static inline final COLOR_MUTED:Int = 0xFFB8C7D6;
  static inline final COLOR_DIM:Int = 0xFF8DA3B8;

  static inline final COLOR_PERFECT:Int = 0xFFFFD84D;
  static inline final COLOR_SICK:Int = 0xFF33E6FF;
  static inline final COLOR_GOOD:Int = 0xFF7CFC8A;
  static inline final COLOR_BAD:Int = 0xFFFFA533;
  static inline final COLOR_POOR:Int = 0xFFFF5E5E;
  static inline final COLOR_MISS:Int = 0xFFCC3344;

  static inline final COLOR_RANK_1:Int = 0xFFFFD166;
  static inline final COLOR_RANK_2:Int = 0xFFE0E6ED;
  static inline final COLOR_RANK_3:Int = 0xFFDF9A68;

  /** When true, Back returns to `AchievementsMenuState` instead of `MainMenuState`. */
  var returnToAwards:Bool = false;

  var menuBackground:FlxSprite;
  var headerBg:FlxSprite;
  var footerBg:FlxSprite;
  var achTabBg:FlxSprite;
  var achTabText:FlxText;
  var statsTabBg:FlxSprite;
  var statsTabAccent:FlxSprite;
  var statsTabText:FlxText;
  var hintText:FlxText;

  var contentCamera:FlxCamera;
  var contentGroup:FlxTypedGroup<FlxSprite>;
  var playtimeValueText:FlxText;

  var lastDisplayedSecond:Int = -1;
  var scrollOffset:Float = 0;
  var maxScroll:Float = 0;
  var baseHint:String = '';
  var hintTimer:Float = 0;
  var leaving:Bool = false;

  /**
   * @param returnToAwards whether Back returns to `AchievementsMenuState`
   *                       (true when opened from Awards; false for direct entry).
   */
  public function new(returnToAwards:Bool = false)
  {
    super();
    this.returnToAwards = returnToAwards;
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    ViewportVisuals.cover(menuBackground, 1.1);
    layoutChrome();
    rebuildContent();
  }

  override function create():Void
  {
    PlayerStats.load();
    MusicBeatState.windowNameSuffix = ' - Player Stats';
    Paths.clearStoredMemory();

    #if DISCORD_ALLOWED
    DiscordClient.changePresence('Player Stats', null);
    #end

    menuBackground = new FlxSprite().loadGraphic(Paths.image('menuBGBlue'));
    menuBackground.antialiasing = ClientPrefs.globalAntialiasing;
    ViewportVisuals.cover(menuBackground, 1.1);
    menuBackground.scrollFactor.set(0, 0);
    add(menuBackground);
    add(new MovingCheckerboard(0xFF5AB6E1, -18, -12));

    contentCamera = new FlxCamera();
    contentCamera.bgColor = 0x00000000;
    FlxG.cameras.add(contentCamera, false);

    contentGroup = new FlxTypedGroup<FlxSprite>();
    add(contentGroup);

    buildChrome();
    layoutChrome();
    rebuildContent();

    addVirtualPad(UP_DOWN, A_B_C);
    addVirtualPadCamera();

    Paths.clearUnusedMemory();
    super.create();
  }

  override function closeSubState():Void
  {
    if (virtualPad != null) virtualPad.visible = MobileControls.enabled;
    super.closeSubState();
  }

  override function update(elapsed:Float):Void
  {
    #if !FLX_NO_MOUSE
    if (!FlxG.mouse.visible && !backend.TouchlessUI.isActive()
      && (Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10))
      FlxG.mouse.visible = true;
    #end

    // Tick the displayed playtime once a second while the screen stays open.
    final wholeSecond:Int = Math.floor(Math.max(0, PlayerStats.playtimeSeconds));
    if (playtimeValueText != null && wholeSecond != lastDisplayedSecond)
    {
      lastDisplayedSecond = wholeSecond;
      playtimeValueText.text = PlayerStats.formatPlaytime(PlayerStats.playtimeSeconds);
    }

    var scrollDelta:Float = 0;
    if (controls.UI_UP) scrollDelta -= SCROLL_SPEED * elapsed;
    if (controls.UI_DOWN) scrollDelta += SCROLL_SPEED * elapsed;
    #if !FLX_NO_MOUSE
    if (FlxG.mouse.wheel != 0) scrollDelta -= FlxG.mouse.wheel * WHEEL_STEP;
    #end
    if (scrollDelta != 0 && maxScroll > 0 && contentCamera != null)
    {
      scrollOffset = FlxMath.bound(scrollOffset + scrollDelta, 0, maxScroll);
      contentCamera.scroll.y = scrollOffset;
    }

    if (hintTimer > 0)
    {
      hintTimer -= elapsed;
      if (hintTimer <= 0) setHint(baseHint);
    }

    if (!leaving)
    {
      if (controls.BACK || FlxG.keys.justPressed.ESCAPE)
      {
        leave();
      }
      #if ACHIEVEMENTS_ALLOWED
      else if (FlxG.keys.justPressed.TAB || controls.ACCEPT
        || (achTabBg != null && TouchTarget.justPressedOver(achTabBg)))
      {
        openAchievements();
      }
      #else
      else if (controls.ACCEPT)
      {
        copySummary();
      }
      #end
      else if (FlxG.keys.justPressed.C)
      {
        copySummary();
      }
      else if ((controls.RESET || (virtualPad != null && virtualPad.buttonC != null && virtualPad.buttonC.justPressed))
        && PlayerStats.hasAnyData())
      {
        openResetPrompt();
      }
    }

    super.update(elapsed);
  }

  override function destroy():Void
  {
    PlayerStats.flushIfDirty();
    if (contentCamera != null)
    {
      FlxG.cameras.remove(contentCamera);
      contentCamera = null;
    }
    super.destroy();
  }

  // -- Header / footer chrome ------------------------------------------------

  function buildChrome():Void
  {
    headerBg = new FlxSprite(0, 0).makeGraphic(1, 1, COLOR_BAR_BG);
    headerBg.scrollFactor.set(0, 0);
    add(headerBg);

    #if ACHIEVEMENTS_ALLOWED
    achTabBg = new FlxSprite(0, 9).makeGraphic(1, 1, COLOR_TAB_IDLE);
    achTabBg.scrollFactor.set(0, 0);
    add(achTabBg);

    achTabText = new FlxText(0, 15, TAB_WIDTH, 'ACHIEVEMENTS', 22);
    achTabText.setFormat(Paths.font('vcr.ttf'), 22, COLOR_MUTED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    achTabText.borderSize = 1.5;
    achTabText.scrollFactor.set(0, 0);
    add(achTabText);
    #end

    statsTabBg = new FlxSprite(0, 9).makeGraphic(1, 1, COLOR_TAB_ACTIVE);
    statsTabBg.scrollFactor.set(0, 0);
    add(statsTabBg);

    statsTabAccent = new FlxSprite(0, 9 + TAB_HEIGHT - 3).makeGraphic(1, 1, COLOR_ACCENT_CYAN);
    statsTabAccent.scrollFactor.set(0, 0);
    add(statsTabAccent);

    statsTabText = new FlxText(0, 15, TAB_WIDTH, 'PLAYER STATS', 22);
    statsTabText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    statsTabText.borderSize = 1.5;
    statsTabText.scrollFactor.set(0, 0);
    add(statsTabText);

    footerBg = new FlxSprite(0, FlxG.height - FOOTER_HEIGHT).makeGraphic(1, 1, COLOR_BAR_BG);
    footerBg.scrollFactor.set(0, 0);
    add(footerBg);

    baseHint = buildBaseHint();
    hintText = new FlxText(12, FlxG.height - FOOTER_HEIGHT + 12, FlxG.width - 24, baseHint, 16);
    hintText.setFormat(Paths.font('vcr.ttf'), 16, COLOR_MUTED, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    hintText.borderSize = 1;
    hintText.scrollFactor.set(0, 0);
    add(hintText);
  }

  function buildBaseHint():String
  {
    final backLabel:String = #if ACHIEVEMENTS_ALLOWED (returnToAwards ? 'Awards' : 'Menu') #else 'Menu' #end;
    if (MobileControls.enabled)
    {
      #if ACHIEVEMENTS_ALLOWED
      return 'UP/DOWN: Scroll   |   A: Achievements   |   C: Reset Stats   |   B: ' + backLabel;
      #else
      return 'UP/DOWN: Scroll   |   A: Copy   |   C: Reset Stats   |   B: ' + backLabel;
      #end
    }
    #if ACHIEVEMENTS_ALLOWED
    return 'TAB / ENTER: Achievements   |   UP/DOWN: Scroll   |   C: Copy   |   R: Reset   |   ESC: ' + backLabel;
    #else
    return 'UP/DOWN: Scroll   |   C: Copy   |   R: Reset   |   ESC: ' + backLabel;
    #end
  }

  function layoutChrome():Void
  {
    if (headerBg != null)
    {
      headerBg.setPosition(0, 0);
      headerBg.setGraphicSize(FlxG.width, HEADER_HEIGHT);
      headerBg.updateHitbox();
    }

    #if ACHIEVEMENTS_ALLOWED
    final totalTabsWidth:Float = TAB_WIDTH * 2 + TAB_GAP;
    final startX:Float = Math.round((FlxG.width - totalTabsWidth) * 0.5);
    if (achTabBg != null)
    {
      achTabBg.setPosition(startX, 9);
      achTabBg.setGraphicSize(TAB_WIDTH, TAB_HEIGHT);
      achTabBg.updateHitbox();
    }
    if (achTabText != null)
    {
      achTabText.setPosition(startX, 15);
      achTabText.fieldWidth = TAB_WIDTH;
    }

    final statsX:Float = startX + TAB_WIDTH + TAB_GAP;
    #else
    final statsX:Float = Math.round((FlxG.width - TAB_WIDTH) * 0.5);
    #end

    if (statsTabBg != null)
    {
      statsTabBg.setPosition(statsX, 9);
      statsTabBg.setGraphicSize(TAB_WIDTH, TAB_HEIGHT);
      statsTabBg.updateHitbox();
    }
    if (statsTabAccent != null)
    {
      statsTabAccent.setPosition(statsX, 9 + TAB_HEIGHT - 3);
      statsTabAccent.setGraphicSize(TAB_WIDTH, 3);
      statsTabAccent.updateHitbox();
    }
    if (statsTabText != null)
    {
      statsTabText.setPosition(statsX, 15);
      statsTabText.fieldWidth = TAB_WIDTH;
    }

    if (hintText != null)
    {
      hintText.fieldWidth = Math.max(200, FlxG.width - 24);
      final barHeight:Int = Std.int(Math.max(FOOTER_HEIGHT, Math.ceil(hintText.height) + 18));
      final barY:Float = FlxG.height - barHeight;
      if (footerBg != null)
      {
        footerBg.setPosition(0, barY);
        footerBg.setGraphicSize(FlxG.width, barHeight);
        footerBg.updateHitbox();
      }
      hintText.setPosition(12, barY + Math.round((barHeight - hintText.height) * 0.5));
    }
  }

  // -- Dashboard content -----------------------------------------------------

  function rebuildContent():Void
  {
    if (contentGroup == null || contentCamera == null) return;

    for (member in contentGroup.members)
      if (member != null) member.destroy();
    contentGroup.clear();
    playtimeValueText = null;
    lastDisplayedSecond = -1;

    final footerTop:Float = footerBg != null ? footerBg.y : (FlxG.height - FOOTER_HEIGHT);
    final viewTop:Int = HEADER_HEIGHT + 8;
    final viewHeight:Int = Std.int(Math.max(160, footerTop - viewTop - 8));
    final contentWidth:Int = Std.int(Math.max(560, Math.min(1160, FlxG.width - 80)));
    final viewLeft:Int = Std.int(Math.max(16, Math.round((FlxG.width - contentWidth) * 0.5)));

    contentCamera.setPosition(viewLeft, viewTop);
    contentCamera.setSize(contentWidth, viewHeight);

    final snap:PlayerStatsSnapshot = PlayerStats.snapshot(MAX_TOP_ENTRIES);
    var cursorY:Int = 4;

    cursorY = buildOverviewRow(snap, contentWidth, cursorY);
    cursorY += CARD_GAP;
    cursorY = buildJudgementsCard(snap, contentWidth, cursorY);
    cursorY += CARD_GAP;
    cursorY = buildLeaderboardsRow(snap, contentWidth, cursorY);
    cursorY += 8;

    maxScroll = Math.max(0, cursorY - viewHeight);
    scrollOffset = FlxMath.bound(scrollOffset, 0, maxScroll);
    contentCamera.scroll.y = scrollOffset;
  }

  function buildOverviewRow(snap:PlayerStatsSnapshot, contentWidth:Int, topY:Int):Int
  {
    final cardHeight:Int = 100;
    final cardWidth:Int = Std.int((contentWidth - CARD_GAP * 3) / 4);

    final uniqueSongsSub:String = snap.uniqueSongs == 0
      ? 'No clears yet'
      : (PlayerStats.formatCount(snap.uniqueSongs) + (snap.uniqueSongs == 1 ? ' unique song' : ' unique songs'));

    final fcSub:String = snap.songsFinished > 0
      ? (PlayerStats.formatPercent(PlayerStats.fullComboRatePercent(), 1) + ' of clears')
      : '0 misses, 1+ hit';

    lastDisplayedSecond = Math.floor(Math.max(0, snap.playtimeSeconds));
    playtimeValueText = addStatCard(0, topY, cardWidth, cardHeight, COLOR_ACCENT_CYAN,
      'PLAYTIME', PlayerStats.formatPlaytime(snap.playtimeSeconds), 'Lifetime runtime');

    addStatCard(cardWidth + CARD_GAP, topY, cardWidth, cardHeight, COLOR_ACCENT_GOLD,
      'SONGS FINISHED', PlayerStats.formatCount(snap.songsFinished), uniqueSongsSub);

    addStatCard((cardWidth + CARD_GAP) * 2, topY, cardWidth, cardHeight, COLOR_ACCENT_LIME,
      'FULL COMBOS', PlayerStats.formatCount(snap.fullCombos), fcSub);

    final lastX:Int = (cardWidth + CARD_GAP) * 3;
    final lastW:Int = contentWidth - lastX;
    addStatCard(lastX, topY, lastW, cardHeight, COLOR_ACCENT_CORAL,
      'DEATHS', PlayerStats.formatCount(snap.deaths), 'Total game overs');

    return topY + cardHeight;
  }

  function addStatCard(x:Int, y:Int, width:Int, height:Int, accent:Int,
      label:String, value:String, detail:String):FlxText
  {
    addRect(x, y, width, height, COLOR_CARD_BG);
    addRect(x, y, width, 4, accent);

    addText(x + 8, y + 12, width - 16, label, 14, COLOR_MUTED, CENTER);
    final valueText:FlxText = addText(x + 8, y + 34, width - 16, value, 24, FlxColor.WHITE, CENTER);
    addText(x + 8, y + 70, width - 16, detail, 14, COLOR_DIM, CENTER);
    return valueText;
  }

  function buildJudgementsCard(snap:PlayerStatsSnapshot, contentWidth:Int, topY:Int):Int
  {
    final cardHeight:Int = 212;
    addRect(0, topY, contentWidth, cardHeight, COLOR_CARD_BG);
    addRect(0, topY, contentWidth, 3, COLOR_ACCENT_CYAN);

    final totalNotes:Int = PlayerStats.totalJudgedNotes();
    addText(16, topY + 12, 340, 'NOTES PER JUDGEMENT', 18, FlxColor.WHITE, LEFT);

    final summaryRight:String = totalNotes > 0
      ? ('Total: ' + PlayerStats.formatCount(totalNotes) + '   |   Accuracy: '
        + PlayerStats.formatPercent(PlayerStats.weightedAccuracyPercent(), 2))
      : 'No notes judged yet';
    addText(320, topY + 14, contentWidth - 336, summaryRight, 15, COLOR_MUTED, RIGHT);

    final rows:Array<{label:String, count:Int, color:Int}> = [
      {label: 'Perfect', count: snap.judgements.perfects, color: COLOR_PERFECT},
      {label: 'Sick', count: snap.judgements.sicks, color: COLOR_SICK},
      {label: 'Good', count: snap.judgements.goods, color: COLOR_GOOD},
      {label: 'Bad', count: snap.judgements.bads, color: COLOR_BAD},
      {label: 'Poor', count: snap.judgements.poors, color: COLOR_POOR},
      {label: 'Miss', count: snap.judgements.misses, color: COLOR_MISS}
    ];

    final labelWidth:Int = 96;
    final valueWidth:Int = 210;
    final barX:Int = 16 + labelWidth + 8;
    final barWidth:Int = Std.int(Math.max(80, contentWidth - barX - valueWidth - 24));

    for (i in 0...rows.length)
    {
      final row = rows[i];
      final rowY:Int = topY + 46 + i * 26;

      addText(16, rowY, labelWidth, row.label, 16, row.color, LEFT);
      addRect(barX, rowY + 4, barWidth, 14, 0x88142233);

      if (totalNotes > 0 && row.count > 0)
      {
        final fillWidth:Int = Std.int(Math.max(4, Math.min(barWidth, Math.round((row.count / totalNotes) * barWidth))));
        addRect(barX, rowY + 4, fillWidth, 14, row.color);
      }

      final pct:Float = totalNotes > 0 ? (row.count / totalNotes) * 100.0 : 0.0;
      final valueLabel:String = PlayerStats.formatCount(row.count) + ' (' + PlayerStats.formatPercent(pct, 1) + ')';
      addText(contentWidth - valueWidth - 16, rowY, valueWidth, valueLabel, 15, FlxColor.WHITE, RIGHT);
    }

    return topY + cardHeight;
  }

  function buildLeaderboardsRow(snap:PlayerStatsSnapshot, contentWidth:Int, topY:Int):Int
  {
    final colWidth:Int = Std.int((contentWidth - CARD_GAP) / 2);
    final rightX:Int = colWidth + CARD_GAP;
    final rightWidth:Int = contentWidth - rightX;

    final maxEntries:Int = Std.int(Math.max(snap.topSongs.length, snap.topMods.length));
    final visibleRows:Int = Std.int(Math.max(MIN_LIST_ROWS, maxEntries));
    final cardHeight:Int = 46 + visibleRows * 38 + 12;

    buildSongsCard(snap.topSongs, snap.uniqueSongs, 0, topY, colWidth, cardHeight);
    buildModsCard(snap.topMods, snap.uniqueMods, rightX, topY, rightWidth, cardHeight);

    return topY + cardHeight;
  }

  function buildSongsCard(entries:Array<SongPlayEntry>, uniqueCount:Int,
      x:Int, y:Int, width:Int, height:Int):Void
  {
    addRect(x, y, width, height, COLOR_CARD_BG);
    addRect(x, y, width, 3, COLOR_ACCENT_GOLD);

    addText(x + 16, y + 12, width - 150, 'MOST-PLAYED SONGS', 18, FlxColor.WHITE, LEFT);
    addText(x + width - 140, y + 14, 124, PlayerStats.formatCount(uniqueCount) + ' unique', 15, COLOR_MUTED, RIGHT);

    if (entries.length == 0)
    {
      addText(x + 24, y + Std.int(height * 0.5) - 10, width - 48,
        'Finish a song to track your most-played songs.', 16, COLOR_DIM, CENTER);
      return;
    }

    final maxPlays:Int = entries[0].plays > 0 ? entries[0].plays : 1;
    final maxChars:Int = Std.int(Math.max(16, Math.floor((width - 196) / 10)));
    for (i in 0...entries.length)
    {
      final entry:SongPlayEntry = entries[i];
      final rowY:Int = y + 46 + i * 38;
      final trackWidth:Int = width - 24;
      final fillWidth:Int = Std.int(Math.max(8, Math.min(trackWidth, Math.round((entry.plays / maxPlays) * trackWidth))));

      addRect(x + 12, rowY, trackWidth, 30, 0x44142233);
      addRect(x + 12, rowY, fillWidth, 30, 0x553B82C4);

      addText(x + 18, rowY + 6, 42, '#' + (i + 1), 16, rankColor(i), LEFT);

      final modTag:String = (entry.modName != null && entry.modName.length > 0) ? (' [' + entry.modName + ']') : '';
      final displayLabel:String = PlayerStats.sanitizeLabel(entry.name + modTag, maxChars);
      addText(x + 62, rowY + 6, width - 188, displayLabel, 16, FlxColor.WHITE, LEFT);

      final countText:String = PlayerStats.formatCount(entry.plays) + (entry.plays == 1 ? ' play' : ' plays');
      addText(x + width - 122, rowY + 6, 106, countText, 15, COLOR_MUTED, RIGHT);
    }
  }

  function buildModsCard(entries:Array<ModPlayEntry>, uniqueCount:Int,
      x:Int, y:Int, width:Int, height:Int):Void
  {
    addRect(x, y, width, height, COLOR_CARD_BG);
    addRect(x, y, width, 3, COLOR_ACCENT_LIME);

    addText(x + 16, y + 12, width - 150, 'MOST-PLAYED MODS', 18, FlxColor.WHITE, LEFT);
    addText(x + width - 140, y + 14, 124, PlayerStats.formatCount(uniqueCount) + ' unique', 15, COLOR_MUTED, RIGHT);

    if (entries.length == 0)
    {
      addText(x + 24, y + Std.int(height * 0.5) - 10, width - 48,
        'Finish a song from a mod to track your top mods.', 16, COLOR_DIM, CENTER);
      return;
    }

    final maxPlays:Int = entries[0].plays > 0 ? entries[0].plays : 1;
    final maxChars:Int = Std.int(Math.max(16, Math.floor((width - 196) / 10)));
    for (i in 0...entries.length)
    {
      final entry:ModPlayEntry = entries[i];
      final rowY:Int = y + 46 + i * 38;
      final trackWidth:Int = width - 24;
      final fillWidth:Int = Std.int(Math.max(8, Math.min(trackWidth, Math.round((entry.plays / maxPlays) * trackWidth))));

      addRect(x + 12, rowY, trackWidth, 30, 0x44142233);
      addRect(x + 12, rowY, fillWidth, 30, 0x554E9F6E);

      addText(x + 18, rowY + 6, 42, '#' + (i + 1), 16, rankColor(i), LEFT);

      final displayLabel:String = PlayerStats.sanitizeLabel(entry.name, maxChars);
      addText(x + 62, rowY + 6, width - 188, displayLabel, 16, FlxColor.WHITE, LEFT);

      final countText:String = PlayerStats.formatCount(entry.plays) + (entry.plays == 1 ? ' play' : ' plays');
      addText(x + width - 122, rowY + 6, 106, countText, 15, COLOR_MUTED, RIGHT);
    }
  }

  function addRect(x:Int, y:Int, width:Int, height:Int, color:Int):FlxSprite
  {
    final spr:FlxSprite = new FlxSprite(x, y).makeGraphic(1, 1, color);
    spr.setGraphicSize(width, height);
    spr.updateHitbox();
    spr.cameras = [contentCamera];
    contentGroup.add(spr);
    return spr;
  }

  function addText(x:Int, y:Int, width:Int, text:String, size:Int, color:Int, align:FlxTextAlign):FlxText
  {
    final field:FlxText = new FlxText(x, y, width, text, size);
    field.setFormat(Paths.font('vcr.ttf'), size, color, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    field.borderSize = 1;
    field.cameras = [contentCamera];
    contentGroup.add(field);
    return field;
  }

  static inline function rankColor(index:Int):Int
  {
    return switch (index)
    {
      case 0: COLOR_RANK_1;
      case 1: COLOR_RANK_2;
      case 2: COLOR_RANK_3;
      default: COLOR_DIM;
    };
  }

  // -- Actions ---------------------------------------------------------------

  function copySummary():Void
  {
    final summary:String = PlayerStats.buildSummaryText(MAX_TOP_ENTRIES);
    var copied:Bool = true;
    try
    {
      Clipboard.text = summary;
    }
    catch (e:Dynamic)
    {
      copied = false;
    }
    if (copied) FlxG.sound.play(Paths.sound('confirmMenu'), 0.45);
    setHint(copied ? 'Stats summary copied to clipboard!' : 'Clipboard is unavailable on this target.');
  }

  function openResetPrompt():Void
  {
    if (virtualPad != null) virtualPad.visible = false;
    openSubState(new ResetStatsSubState(function():Void
    {
      PlayerStats.reset(true);
      scrollOffset = 0;
      rebuildContent();
      setHint('Lifetime player stats reset.');
    }));
  }

  #if ACHIEVEMENTS_ALLOWED
  function openAchievements():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.sound.play(Paths.sound('scrollMenu'));
    FlxG.switchState(() -> new AchievementsMenuState());
  }
  #end

  function leave():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.sound.play(Paths.sound('cancelMenu'));
    #if ACHIEVEMENTS_ALLOWED
    if (returnToAwards)
    {
      FlxG.switchState(() -> new AchievementsMenuState());
      return;
    }
    #end
    FlxG.switchState(MainMenuState.new);
  }

  function setHint(text:String):Void
  {
    if (hintText == null) return;
    hintText.text = text;
    hintTimer = (text == baseHint) ? 0 : HINT_SECONDS;
    layoutChrome();
  }
}

/**
 * Guarded confirmation dialog for clearing lifetime player statistics.
 * Uses `HoldToConfirm` on Yes so stats cannot be wiped by a stray press.
 */
class ResetStatsSubState extends MusicBeatSubstate
{
  var onConfirmCallback:Void->Void;
  var onYes:Bool = false;
  var overlayCamera:FlxCamera;
  var background:FlxSprite;
  var heading:Alphabet;
  var detailText:FlxText;
  var yesText:Alphabet;
  var noText:Alphabet;
  var yesConfirm:HoldToConfirm;
  var noTarget:TouchTarget;

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    if (overlayCamera != null) overlayCamera.setSize(FlxG.width, FlxG.height);
    ViewportVisuals.fill(background);
    if (heading != null) heading.screenCenter(X);
    if (detailText != null) detailText.fieldWidth = FlxG.width - 100;
    if (yesText != null)
    {
      yesText.screenCenter(X);
      yesText.x -= 200;
    }
    if (noText != null)
    {
      noText.screenCenter(X);
      noText.x += 200;
    }
  }

  public function new(onConfirm:Void->Void)
  {
    super();
    onConfirmCallback = onConfirm;

    // Render above StatsState's scrollable contentCamera so cards dim cleanly behind the prompt.
    overlayCamera = new FlxCamera();
    overlayCamera.bgColor = 0x00000000;
    FlxG.cameras.add(overlayCamera, false);
    cameras = [overlayCamera];

    background = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    ViewportVisuals.fill(background);
    background.alpha = 0;
    background.scrollFactor.set(0, 0);
    background.cameras = [overlayCamera];
    add(background);

    heading = new Alphabet(0, 160, 'Reset Lifetime Stats?', true);
    heading.screenCenter(X);
    heading.scrollFactor.set(0, 0);
    heading.cameras = [overlayCamera];
    add(heading);

    detailText = new FlxText(50, heading.y + 92, FlxG.width - 100,
      'Clears playtime, clears, judgements, deaths and top lists.\nAchievements and highscores are not affected.', 24);
    detailText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    detailText.borderSize = 2;
    detailText.scrollFactor.set(0, 0);
    detailText.cameras = [overlayCamera];
    add(detailText);

    yesText = new Alphabet(0, detailText.y + 120, 'Yes', true);
    yesText.screenCenter(X);
    yesText.x -= 200;
    yesText.scrollFactor.set(0, 0);
    yesText.cameras = [overlayCamera];
    for (letter in yesText.letters) letter.color = FlxColor.RED;
    add(yesText);

    noText = new Alphabet(0, detailText.y + 120, 'No', true);
    noText.screenCenter(X);
    noText.x += 200;
    noText.scrollFactor.set(0, 0);
    noText.cameras = [overlayCamera];
    add(noText);

    updateOptions(false);

    yesConfirm = new HoldToConfirm(yesText, confirmReset,
      () -> onYes && PlayerSettings.player1.controls.ACCEPT_P, 'HOLD TO RESET STATS');
    yesConfirm.cameras = [overlayCamera];
    add(yesConfirm);

    noTarget = new TouchTarget(noText, cancelReset);
    noTarget.cameras = [overlayCamera];
    add(noTarget);

    addVirtualPad(LEFT_RIGHT, A_B);
    addVirtualPadCamera();
  }

  override function destroy():Void
  {
    if (overlayCamera != null)
    {
      FlxG.cameras.remove(overlayCamera);
      overlayCamera = null;
    }
    super.destroy();
  }

  override function update(elapsed:Float):Void
  {
    if (background.alpha < 0.7)
      background.alpha = Math.min(0.7, background.alpha + elapsed * 2.5);

    if (controls.BACK)
    {
      cancelReset();
      return;
    }

    if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
    {
      onYes = !onYes;
      if (yesConfirm != null) yesConfirm.cancel();
      updateOptions(true);
    }
    else if (controls.ACCEPT && !onYes)
    {
      cancelReset();
      return;
    }

    super.update(elapsed);
  }

  function confirmReset():Void
  {
    if (onConfirmCallback != null) onConfirmCallback();
    FlxG.sound.play(Paths.sound('cancelMenu'));
    close();
  }

  function cancelReset():Void
  {
    if (yesConfirm != null) yesConfirm.cancel();
    FlxG.sound.play(Paths.sound('cancelMenu'));
    close();
  }

  function updateOptions(playSound:Bool):Void
  {
    final scales:Array<Float> = [0.75, 1.0];
    final alphas:Array<Float> = [0.6, 1.0];
    final confirmInt:Int = onYes ? 1 : 0;

    yesText.alpha = alphas[confirmInt];
    yesText.scale.set(scales[confirmInt], scales[confirmInt]);
    noText.alpha = alphas[1 - confirmInt];
    noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
    if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'));
  }
}
