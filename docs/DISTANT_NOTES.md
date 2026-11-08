# Distant Notes

Enable **Options → Visuals and UI → Distant Notes**, then start or restart a
song. It uses Doido Engine's `DistantNoteShader` perspective, with the
projection flipped for downscroll. Shaders must be enabled in the graphics
settings; on builds without shader support the option is unavailable. It is off
by default.

The effect temporarily uses middlescroll without changing the saved preference.
Disabling it or shaders restores the normal layout on the next song. Notes,
receptors, sustains and splashes share a transparent camera so health, score and
other HUD elements are not distorted. Its zoom, position, scroll, angle,
visibility and alpha follow the HUD camera. Because this is a separate layer,
mod scripts that specifically apply camera filters or shakes to `camHUD` do not
apply those effects to the notes. Mods can access `PlayState.camNotes` while the
option is enabled; it is `null` otherwise. Unusual modcharts that explicitly
reassign note cameras may bypass the effect.

For Haxe users the shader is `shaders.DistantNoteShader`; pass the downscroll
boolean to its constructor and apply it to a note-field camera. Its GLSL is
ported from [Doido Engine](https://github.com/DoidoTeam/FNF-Doido-Engine/blob/main/source/backend/shaders/DistantNoteShader.hx).

The FPS overlay defaults to two lines: FPS and current RAM. Enable **Legacy FPS
UI** in Visuals and UI to restore the previous overlay, including the rendering
mode label, optional peak RAM, debug info and frame profiler text. The toggle
applies immediately and is saved; turning it off hides the extra details without
changing their individual settings. F3 toggles the profiler setting; its text is
visible only in Legacy FPS UI, while F6 can still export a report in either view.
The existing FPS and RAM visibility options
apply to both views. RAM reports process RSS on C++ targets and managed memory
on other targets.
