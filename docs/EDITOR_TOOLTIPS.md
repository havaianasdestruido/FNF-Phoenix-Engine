# Editor tooltips

Hover over a supported editor control for 0.6 seconds to see contextual help.
Help uses flixel-ui's `FlxUITooltipManager`, with a dark background, white text,
and automatic edge-aware placement. Clicking does not force a tooltip open.

Covered areas include song/section/note settings in the Chart Editor; character
assets, positioning, health colors and animations; dialogue lines and portraits;
Story Menu characters; and week metadata, Freeplay colors and unlock settings.

## Adding help

After adding a control to its UI group, register its explanation:

```haxe
EditorTooltips.add(this, scaleStepper, "Sprite scale multiplier. One uses the original asset size.");
```

Import `objects.ui.EditorTooltips`. In a helper class, pass the editor state
instead of `this`. Registration may happen before `super.create()`: it is deferred
until the state's tooltip manager exists. The invisible hover target follows the
control's bounds, visibility, activity, scroll factor and camera each frame. The
state owns the hover targets and its existing tooltip manager owns the tooltips;
no global registry or extra assets are needed.

## Manual regression checklist

With a full engine build and assets available:

- In each covered editor, hover a text input, checkbox, stepper, dropdown and
  button. Verify the explanation appears after the delay and is readable.
- Move off a control: its hint should disappear. Switch tabs: hidden controls
  must not produce hints over the newly selected tab.
- Move/resize a panel and test hints near each screen edge.
- In Character Editor, pan/zoom the character preview and verify help still
  aligns with the separate menu camera rather than the preview camera.
- Type into fields, scroll steppers/dropdowns, drag sliders and click buttons.
  Hover targets must not change focus, values, or invoke actions themselves.
- Open a confirmation substate and return. Exit and reopen an editor several
  times; check for stale hints and duplicate registrations.
