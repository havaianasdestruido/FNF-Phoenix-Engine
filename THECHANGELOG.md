0.0.1;

Phoenix Engine 0.0.1 — first release under Phoenix's own version line,
independent from the upstream JS Engine / Psych Engine version numbers.
The version is defined by VERSION in project.hxp and published with the
matching v0.0.1 tag in havaianasdestruido/FNF-Phoenix-Engine.

Highlights from the 0.0.1 release line:
- Python/Hython softmodding alongside Lua and standalone HScript mods.
- Android platform work: MediaSession bridge, DocumentsProvider, safer mod
  storage, mobile input fixes and native runtime packaging fixes.
- Native Windows window-management bridge, transparent window support and
  platform crash dialogs.
- GPU/CPU/OS detection for crash logs and mods, verbose VLog and frame profiler.
- Widescreen layout, gameplay sprite pooling, chart-editor timing fixes and
  sandboxed Lua/Python/HScript softmod scripts.
- Mic'd Up!-inspired moving checkerboards across the menu flow, enabled by
  default with a live Visuals and UI toggle and reduced-motion support.
- .zip mod import from the Mods menu and the bf-clicker example mod.
- Shader warm-up: the shaders a stage declares (`StageFile.shaders`,
  `BaseStage.declareShaders()`), the song-level Pulse shader and every runtime
  shader a script creates while loading are compiled on the loading screen
  instead of on the first bop (`shaders.ShaderWarmup`).

Earlier Phoenix prereleases: v0.0.1-alpha, v0.0.1-beta and v0.0.1-pre1.
This file is historical. Release notes are maintained on GitHub Releases;
the in-game update checker reads the selected release's Markdown body directly.
