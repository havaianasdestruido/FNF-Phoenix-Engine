<h1 align="center">
  <a href="https://github.com/havaianasdestruido/FNF-Phoenix-Engine"><img src="/art/iconOG.png" alt="Phoenix Engine" width="150"></a>
  <br>
  FNF Phoenix Engine
</h1>

<p align="center">
  An enhanced fork of JS Engine (Jordan Santiago Engine), built on Psych Engine.
  Focused on performance, modding, and platform support.
</p>

<p align="center">
  <a href="https://github.com/havaianasdestruido/FNF-Phoenix-Engine/actions/workflows/main.yml"><img src="https://github.com/havaianasdestruido/FNF-Phoenix-Engine/actions/workflows/main.yml/badge.svg" alt="Build status"></a>
</p>

## Getting started

- [Download releases](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/releases)
- [Documentation](https://havaianasdestruido.github.io/FNF-Phoenix-Engine/) — setup, architecture, modding, and API reference
- [Build instructions](BUILDING.md) — dependencies, compilation, and troubleshooting
- [Why is the game so big?](SIZE.md) — Windows & Android build size breakdown with charts

## Key additions over JS Engine

- **Performance improvements:** script caching, optimized note processing, and reduced editor/UI overhead.
- **Python scripting:** Hython integration alongside Lua/Luau and HScript, for folder-based mods as well as Haxe source mods.
- **Gameplay and editor improvements:** V-Slice-style camera zoom, zoom tweening, crossfades, decimal hit windows, and chart editor optimizations.
- **Platform support:** Android integrations, native platform utilities, Linux GameMode support, and build fixes.
- **Window effects:** transparent windows, window opacity, and click-through controls for overlay mods. See [Transparent Window](docs/TRANSPARENT_WINDOW.md).
- **Maintenance and fixes:** reorganized source code, haxelib overrides, smaller assets, and gameplay/crash fixes.
- - **All platforms under the same branch:** The biggest addition i've ever added was mobile support DIRECTLY to the same branch as the Desktop one, so hotfixes and other patches can be applied to all platforms at once.

## Known Android issues

- Image and audio permission prompts may still appear after granting “manage all files” access.

## Contributing

Bug fixes, features, example mods, platform ports, and upstream backports are welcome.
Check [BUILDING.md](BUILDING.md) and [CODESTYLE.md](CODESTYLE.md) before submitting a pull request.
Use [issues](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/issues) to report bugs or discuss larger changes.

Thanks to the [Phoenix Engine contributors](https://github.com/havaianasdestruido/FNF-Phoenix-Engine/graphs/contributors),
JS Engine, and Psych Engine. Their original README and credits are preserved below.

---

<details>
  <summary><h2>OG FNF JS Engine README and Stuff</h2></summary>
<!-- this is an secret -->
<h1 align="center">
  <br>
  <a href="https://github.com/JordanSantiagoYT/FNF-JS-Engine"><img src="/art/iconOG.png" alt="JSengine" width="150"></a>
  <br>
  <b>JS Engine</b>
  <br>
  <i>(Jordan Santiago Engine)</i>
  <br>
</h1>
<h3 align="center">
  <b>JS Engine is a heavily modified Psych Engine fork, with lower-end devices and more customization in mind.</b>
</h3>

README.md revamped by [Nael2xd](https://youtube.com/@nael2xd?si=axwJrY_8jdlXUwSm)

<!-- _If you're looking for the Mobile port, [go here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/tree/mobile)._ -->

## Welcome

Welcome to JS Engine's github repo, where you can download the engine and make spammy charts or have fun with the engine.

This contains lots and lots of customizable and features built in to JS Engine, if you wanna see most of them listed, you can see it below this text

# Features/Performances in JS ENGINE

**This fork has tons of features and performances features, most will be listed:**

- No BotPlay lag!
- Faster Song Loading!
- Loading songs longer than 20 minutes!
- Note Performance!
- Loading 100k+ notes without closing the window!
- Basic Shader Support! (for a full list, it can be seen in [here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/wiki#q-what-are-all-the-basic-shaders-that-come-with-this-engine))
- Rendering mode! (Originally used for lua and gamerenderer-engine)
- Built in Song Credits! (on chart editor)
- Spam modules! (for the DnB fans)
- Cool customizable UI!
- Multiple Chart Backups!
- Custom Crash UI (Instead of Regular Psych Engine Crash)!
- A nifty button in your Discord Profile!

There is like lots and lots of stuff i've missed, but at least you would like those features built in **JS ENGINE**

# Screenshots and Gameplays

![Screenshot 2024-07-07 14-00-00](https://github.com/JordanSantiagoYT/FNF-JS-Engine/assets/108278470/d4e89995-fa14-40bf-a5d6-d1647548fd93)

![Screenshot 2024-07-07 14-01-15](https://github.com/JordanSantiagoYT/FNF-JS-Engine/assets/108278470/b6d7d5ef-196d-4c39-9055-97815d63cdf0)

![Screenshot 2024-07-07 13-58-45](https://github.com/JordanSantiagoYT/FNF-JS-Engine/assets/108278470/a65ea8b5-8b0d-4643-b7e0-cddd3972422b)

![image](https://github.com/user-attachments/assets/aea20297-1695-4b83-b17e-342685490414)
- Gameplay from @TheStinkern

![0203(1)](https://github.com/user-attachments/assets/15620fa6-52a9-4090-996f-80a80bda32ef)
- Gameplay from @TheStinkern
  - See the full gameplay [here](https://www.youtube.com/watch?v=Z2iXD1FbX1I)

# FAQs

Frequently Asked Questions (FAQs) are found in [here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/wiki) or you can simply see it below.

**Q: Can I use this engine for my mod(s)?**

A: Yes, you can! just be sure to credit me ([@JordanSantiago on YouTube](https://www.youtube.com/@JordanSantiago)) and give a link to the Engine's github/gamebanana, or [the link to download the latest release.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/releases/latest)

**Q: How do I change and add things?**

A: You do it here the [same way you'd do it in Psych Engine.](https://github.com/ShadowMario/FNF-PsychEngine/wiki)

**Q: I found a bug!**

A: Report [here.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/issues) Also, **please check if there are already posts about the same issue.**

**Q: I found a *WAY* to fix a bug!**

A: Send [here.](https://github.com/JordanSantiagoYT/FNF-JS-Engine/pulls)

# Compiling JS Engine

Refer to [the Build Instructions](./BUILDING.md)

If you get an error while Compiling, go [here](https://github.com/JordanSantiagoYT/FNF-JS-Engine/issues/359) to see if the issue is on there, if not, make an issue

## Customization:

if you wish to disable things like *Lua Scripts* or *Video Cutscenes*, you can read over to `Project.hxp`

inside `Project.hxp`, you will find several variables to customize JS Engine to your liking

to start you off, disabling Videos should be simple, simply Delete the line `VIDEOS_ALLOWED.apply(this, true);` or comment it out by adding `//` behind the code block, like this: `// VIDEOS_ALLOWED.apply(this, true);`

same goes for *Lua Scripts*, comment out or delete the line with `LUA_ALLOWED.apply(this, true);`, this and other customization options are all available within the `Project.hxp` file.

# Contributors

@JordanSantiagoYT (of course)
- He's the owner... What do you think?

@TheStinkern
- Small coder

@moxie-coder
- Codes part of the engine

@NAEL2XD
- Does pull requests

@PatoFlamejanteTV
- Small coding, also made a PDF guide for JS Engine.

### The rest of the lovely contributors on GitHub! (Psych and JS Engine)
<a href="https://github.com/JordanSantiagoYT/FNF-JS-Engine/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=JordanSantiagoYT/FNF-JS-Engine" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

### 4th-wall-breaking (META_HORROR) feature credits

Ported with adaptation (see `docs/META_HORROR.md`); both projects are Apache-2.0 licensed.

* [notmagniill/psych-engine-modified-build](https://github.com/notmagniill/psych-engine-modified-build) — original `CoolUtil.hx` `META_HORROR` section (recorder detection, wallpaper swap, system volume/mouse/keyboard effects)
* [Dewott2501/Mario-Madness](https://github.com/Dewott2501/Mario-Madness) — `CppAPI.hx`, `WindowsData.hx`, `Wallpaper.hx` and `Transparency.hx` (taskbar/window hiding, wallpaper capture/restore, color-key transparency, RAM query)

<details>
  <summary><h2>OG Psych Engine Credits and Stuff</h2></summary>

* Shadow Mario - Programmer
* RiverOaken - Artist

### Special Thanks
* bbpanzu - Ex-Programmer
* SqirraRNG - Crash Handler and Base code for Chart Editor's Waveform
* KadeDev - Fixed some cool stuff on Chart Editor and other PRs
* iFlicky - Composer of Psync and Tea Time, also made the Dialogue Sounds
* PolybiusProxy - Former .MP4 Video Loader Library (hxCodec)
* MAJigsaw77 - .MP4 Video Loader Library (hxVLC)
* Keoiki - Note Splash Animations
* Smokey - Sprite Atlas Support
* Nebula the Zorua - LUA JIT Fork and some Lua reworks
_____________________________________

# Features

## Attractive animated dialogue boxes:

![](https://user-images.githubusercontent.com/44785097/127706669-71cd5cdb-5c2a-4ecc-871b-98a276ae8070.gif)


## Mod Support
* Probably one of the main points of this engine, you can code in .lua files outside of the source code, making your own weeks without even messing with the source!
* Comes with a Mod Organizing/Disabling Menu.


## Atleast one change to every week:
### Week 1:
  * New Dad Left sing sprite
  * Unused stage lights are now used
### Week 2:
  * Both BF and Skid & Pump does "Hey!" animations
  * Thunders does a quick light flash and zooms the camera in slightly
  * Added a quick transition/cutscene to Monster
### Week 3:
  * BF does "Hey!" during Philly Nice
  * Blammed has a cool new colors flash during that sick part of the song
### Week 4:
  * Better hair physics for Mom/Boyfriend (Maybe even slightly better than Week 7's :eyes:)
  * Henchmen die during all songs. Yeah :(
### Week 5:
  * Bottom Boppers and GF does "Hey!" animations during Cocoa and Eggnog
  * On Winter Horrorland, GF bops her head slower in some parts of the song.
### Week 6:
  * On Thorns, the HUD is hidden during the cutscene
  * Also there's the Background girls being spooky during the "Hey!" parts of the Instrumental

## Cool new Chart Editor changes and countless bug fixes
![](https://github.com/ShadowMario/FNF-PsychEngine/blob/main/docs/img/chart.png?raw=true)
* You can now chart "Event" notes, which are bookmarks that trigger specific actions that usually were hardcoded on the vanilla version of the game.
* Your song's BPM can now have decimal values
* You can manually adjust a Note's strum time if you're really going for milisecond precision
* You can change a note's type on the Editor, it comes with two example types:
  * Alt Animation: Forces an alt animation to play, useful for songs like Ugh/Stress
  * Hey: Forces a "Hey" animation instead of the base Sing animation, if Boyfriend hits this note, Girlfriend will do a "Hey!" too.

## Multiple editors to assist you in making your own Mod
![Screenshot_3](https://user-images.githubusercontent.com/44785097/144629914-1fe55999-2f18-4cc1-bc70-afe616d74ae5.png)
* Working both for Source code modding and Downloaded builds!

## Story mode menu rework:
![](https://i.imgur.com/UB2EKpV.png)
* Added a different BG to every song (less Tutorial)
* All menu characters are now in individual spritesheets, makes modding it easier.

## Credits menu
![Screenshot_1](https://user-images.githubusercontent.com/44785097/144632635-f263fb22-b879-4d6b-96d6-865e9562b907.png)
* You can add a head icon, name, description and a Redirect link for when the player presses Enter while the item is currently selected.

## Awards/Achievements
* The engine comes with 21 example achievements that you can mess with and learn how it works (Check Achievements.hx and search for "checkForAchievement" on play/helpers/PlayStatePlayback.hx)

## Options menu:
* You can change Note colors, Delay and Combo Offset, Controls and Preferences there.
 * On Preferences you can toggle Downscroll, Middlescroll, Anti-Aliasing, Framerate, Low Quality, Note Splashes, Flashing Lights, etc.

## Other gameplay features:
* When the enemy hits a note, their strum note also glows.
* Lag doesn't impact the camera movement and player icon scaling anymore.
* Some stuff based on Week 7's changes has been put in (Background colors on Freeplay, Note splashes)
* You can reset your Score on Freeplay/Story Mode by pressing Reset button.
* You can listen to a song or adjust Scroll Speed/Damage taken/etc. on Freeplay by pressing Space.
