# Window Transparency Test

An enabled-by-default Phoenix Engine mod with a Freeplay song named **Transparency Test**. It keeps BF, Dad, and GF on a stage with no scenery, paints the game camera a single solid color, and uses that exact color as the native window's transparency key.

- **Key color:** `#010101` (the engine's default RGB(1, 1, 1) color key).
- **Windows:** the matching background pixels should reveal the desktop. The rest of the game window remains fully opaque. The camera background must be a numeric color: use `getColorFromHex('010101')` with `setProperty`, not the string itself.
- If enabling the effect fails, the song prints a message in the script debug overlay. Run windowed and check the engine log for platform or native-window errors.
- **Linux/macOS:** whole-window alpha is available, but color-key transparency is not; the Lua API logs that the requested color-key effect is unsupported.
- The Lua script disables color-key transparency and restores the previous window alpha when the song exits. It deliberately does not enable click-through, so the game remains interactive.

The song reuses the engine's bundled Test instrumental and matching chart as a self-contained mod track; the chart assigns only BF, Dad, and GF.

## Platform availability

The mod's `pack.json` declares `"platforms": ["desktop"]`. It is only shipped
and enabled on native Windows, macOS and Linux builds: mobile, web, Flash and
AIR builds neither package the folder nor list it in Freeplay. Override the
manifest (or copy the folder) if you want to experiment on another target; the
Lua API stays a safe no-op where color-key transparency is unsupported.
