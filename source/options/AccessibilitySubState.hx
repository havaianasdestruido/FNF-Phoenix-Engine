package options;

import backend.Accessibility;
import backend.ClientPrefs;
import flixel.FlxG;
import objects.MovingCheckerboard;
import options.helpers.OptionsMenuHelpers;
import play.helpers.StageDimMath;

/**
 * Dedicated `Options -> Accessibility` category (§16), gathering photosensitivity,
 * motion, high-contrast, colorblind / luminance-contrast note readability,
 * visual beat cues, dialogue comfort, and UI confirmation settings in one place.
 */
class AccessibilitySubState extends BaseOptionsMenu
{
  public function new()
  {
    title = 'Accessibility';
    rpcTitle = 'Accessibility Settings Menu';

    var option:Option = new Option('Flashing Lights',
      "Uncheck this if you're sensitive to flashing lights!",
      'flashing',
      'bool',
      true);
    addOption(option);

    var option:Option = new Option('Flash Intensity',
      'Scales camera flash brightness and duration. Flashing Lights must be enabled.',
      'flashIntensity',
      'percent',
      1);
    addOption(option);

    var option:Option = new Option('Show Photosensitivity Warning',
      'Shows the flashing-lights warning screen on startup.\nRe-checking this displays the warning again the next time Title loads.',
      'showPhotosensitivityWarning',
      'bool',
      true);
    option.onChange = OptionsMenuHelpers.syncPhotosensitivityWarningState;
    addOption(option);

    var option:Option = new Option('Reduced Motion',
      'Disables camera beat bops, event zooms, screen shakes, menu checkerboard motion,\nand dialogue shake effects.',
      'reducedMotion',
      'bool',
      false);
    option.onChange = () -> MovingCheckerboard.refreshAll();
    addOption(option);

    var option:Option = new Option('Camera Effects Intensity',
      'Strength of camera beat bops, event zooms and shakes.\nReduced Motion overrides this setting and disables these effects.',
      'cameraFxIntensity',
      'percent',
      1);
    option.minValue = 0;
    option.maxValue = 1;
    option.changeValue = 0.01;
    option.scrollSpeed = 1;
    option.decimals = 2;
    addOption(option);

    var option:Option = new Option('High Contrast',
      'Darkens menu and HUD backdrops, boosts text outlines, and enforces a minimum\nstage dim floor during songs for clearer readability.',
      'highContrast',
      'bool',
      false);
    option.onChange = () -> applyHighContrast();
    addOption(option);

    var option:Option = new Option('Stage Dim:',
      'Darkens the stage behind the notes so dense charts are easier to read.\nThe notes, HUD and ratings stay at full brightness.',
      'stageDim',
      'percent',
      0);
    option.scrollSpeed = 1.6;
    option.minValue = StageDimMath.MIN_ALPHA;
    option.maxValue = StageDimMath.MAX_ALPHA;
    option.changeValue = StageDimMath.STEP;
    option.decimals = 2;
    addOption(option);

    var option:Option = new Option('Colorblind Note Palette:',
      'Remaps note, receptor, splash, and sustain colors to a colorblind-safe palette\nwithout overwriting your custom Note Colors.',
      'noteColorblindPreset',
      'string',
      Accessibility.PRESET_NONE,
      Accessibility.COLORBLIND_PRESETS);
    option.onChange = OptionsMenuHelpers.refreshNoteAccessibilityColors;
    addOption(option);

    var option:Option = new Option('Force Note Luminance Contrast',
      'Guarantees distinct brightness steps and crisp dark borders across all four lanes,\nso lanes stay distinguishable even in greyscale.',
      'forceLuminanceContrast',
      'bool',
      false);
    option.onChange = OptionsMenuHelpers.refreshNoteAccessibilityColors;
    addOption(option);

    var option:Option = new Option('Lane Glyphs',
      'Draws direction symbols (<, v, ^, >) over each note receptor during gameplay.',
      'laneGlyphs',
      'bool',
      false);
    addOption(option);

    var option:Option = new Option('Visual Beat Indicator',
      'Pulses a subtle frame along the screen edges on countdown ticks and song beats.\nRespects Reduced Motion.',
      'visualBeatIndicator',
      'bool',
      false);
    addOption(option);

    var option:Option = new Option('Dialogue Speed',
      'Scales how fast dialogue boxes type out characters (1x = normal speed).',
      'dialogueSpeedMult',
      'float',
      1.0);
    option.minValue = 0.25;
    option.maxValue = 5.0;
    option.changeValue = 0.25;
    option.scrollSpeed = 1.5;
    option.decimals = 2;
    option.displayFormat = '%vx';
    addOption(option);

    var option:Option = new Option('Instant Dialogue Text',
      'If checked, reveals each line of dialogue immediately instead of typing letter by letter.',
      'instantDialogueAdvance',
      'bool',
      false);
    addOption(option);

    var option:Option = new Option('Dim Dialogue Background',
      'Darkens the gameplay background behind Psych dialogue boxes so text is easier to read.',
      'dimDialogueBackground',
      'bool',
      false);
    addOption(option);

    var option:Option = new Option('Hide Dialogue Box',
      'Hides the decorative dialogue bubble sprite while keeping portraits and text visible.',
      'hideDialogueBox',
      'bool',
      false);
    addOption(option);

    var option:Option = new Option('UI Scale',
      'Scales menu text, row spacing, checkboxes and value labels together,\nso the whole menu grows or shrinks instead of just the fonts.\n100% is the original size. Applies live while you change it.',
      'uiScalePercent',
      'int',
      100);
    option.minValue = 50;
    option.maxValue = 200;
    option.changeValue = 5;
    option.displayFormat = '%v%';
    option.onChange = function() {
      applyUIScale();
      ClientPrefs.saveSettings();
    };
    addOption(option);

    var option:Option = new Option('Hold to Confirm',
      'Requires holding down confirm on destructive actions such as Reset All Settings.',
      'holdToConfirm',
      'bool',
      true);
    addOption(option);

    var option:Option = new Option('Hold Duration: ',
      'How long a destructive press must be held, in seconds.\nLarger values help on shaky touchscreens. Only used by Hold to Confirm.',
      'holdToConfirmTime',
      'float',
      0.65);
    option.minValue = 0.3;
    option.maxValue = 2;
    option.changeValue = 0.05;
    option.scrollSpeed = 0.5;
    option.decimals = 2;
    option.displayFormat = '%vs';
    addOption(option);

    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

    addBackupOptions();

    super();
  }
}
