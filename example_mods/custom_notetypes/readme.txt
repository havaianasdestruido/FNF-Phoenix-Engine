Custom note types — Mario Madness ports (Lua)
==============================================

This folder holds ready-made custom note type scripts for the `custom_notetypes/`
folder of a Phoenix mod. They are ports of the note types that Mario Madness
(https://github.com/Dewott2501/Mario-Madness) hardcodes in its source, rewritten
as `custom_notetypes` scripts so the engine itself needs no changes.

Ported from Mario Madness by Dewott2501, Apache-2.0 license.
https://github.com/Dewott2501/Mario-Madness/blob/main/LICENSE
No assets from Mario Madness (or any game it imitates) ship in this folder —
only the note-type logic. See "Note skins" below.

How to use
----------

1. Copy the .lua files you want into `mods/<your-mod>/custom_notetypes/`.
2. The file name must match the note type exactly as it appears in the chart
   (the chart editor lists every .lua file found in `custom_notetypes/`).
   Example: `Poison Note.lua` provides the `Poison Note` note type.
3. Chart your song with those note types in `data/<song>/chart.json` (or the
   chart editor) and play. The scripts are loaded automatically when the chart
   contains at least one note of that type.

Every file has a config block at the top: sound names, damage values, texture
atlases and toggles. Edit those instead of the logic below them when you can.

The files
---------

File                    Mario Madness original   What it does
----------------------  -----------------------  -----------------------------------
Poison Note.lua         'Nota veneno'            Hurt note; hitting it counts as a
                                                 miss and also poisons you (health
                                                 drains for 2 s after the hit)
Bad Poison.lua          'Bad Poison'             Hurt note that never animates,
                                                 optional sound on hit
Bomb Note.lua           'Nota bomba'             Hurt note; hitting it takes a full
                                                 heart of damage
Coin Note.lua           'Coin Note'              Ignored by scoring; hitting it plays
                                                 a coin sound and counts coins
Ring Note.lua           'Ring Note'              Normal note; hitting it plays a ring
                                                 sound and counts rings
Water Note.lua          'Water Note'             No sing animation; plays a sound on hit
Boo Note.lua            'Nota boo'               Custom texture only
Bullet.lua              'Bullet'                 No sing animation; firing on hit
                                                 triggers a configurable event
                                                 ('Pico Shoot' by default)
Bullet Bill.lua         'Bullet Bill'            No sing animation, custom texture and
                                                 splash, every 2nd hit plays a gunshot
                                                 sound
Jumpscare Note.lua      'jumpscareM'             Hurt note; plays a scream and shakes
                                                 the cameras (flashing option only)
Invisible Note.lua      'Yoshi Note'             Note with alpha 0 — visible only in
                                                 the chart, still hittable

Engine built-ins you do NOT need here
-------------------------------------

'Hurt Note', 'No Animation', 'Alt Animation', 'GF Sing', 'GF Duet'-style effects
handled by the engine, 'Hey!', 'Cross Fade' and 'GF Cross Fade' are built into
Phoenix and work in charts without any script. Mario Madness ships them the
same way.

Not ported on purpose (song- and stage-specific)
-------------------------------------------------

* 'Bullet2' — identical to Bullet Bill with a wider horizontal offset. Copy
  `Bullet Bill.lua` to `Bullet2.lua`, set `NOTE_TYPE = 'Bullet2'` and
  `OFFSET_X = -163`.
* The Luigi-life counter and dad do a little hop per coin note, the gun ammo /
  'Failgun' reload cycle and the "run out of ammo = death" check, the rising
  water flood, the Bad Poison full-screen overlay, the Somari/Sonic ring
  lose-half-your-rings rule, the jumpscare overlay images and the specific
  stage-conditional invisibility in 'Yoshi Note' (exesequel/betamansion/nesbeat
  only). All of those touch Mario Madness stage objects and images, not the
  note system. The generic parts are kept (see the per-file comments) and each
  spot is marked "Mario Madness re-adds ... here" so you can bolt your own
  stage mechanic back on.
* The note splashes of the originals: Phoenix's default splashes are kept
  except where the file says otherwise.

Note skins
----------

The Mario Madness note skins (`poisonMario_NOTE_assets` and friends) are NOT
included — those are game-derived artwork the Apache-2.0 license on the code
does not cover. Each script expects its own sparrow-atlas sheet in your mod:

    mods/<your-mod>/images/poison_NOTE_assets.png
    mods/<your-mod>/images/poison_NOTE_assets.xml

with the standard note frames (`purple0`/`blue0`/`green0`/`red0` plus the
`purple hold piece`/`green hold piece`/... sustain frames), like the engine's
default `NOTE_assets`. If the sheet is missing, Phoenix keeps the note's
current (regular) skin, so the script never blanks a note or breaks a song
that has no custom art. Missing sounds are skipped as well. Set SKIN = '' in
a file to skip the texture swap entirely.

The scripts deliberately call no file-read callbacks (there is no
checkFileExists), so they run unmodified under the default mod sandbox
(ModSecurity) that softmods are subject to.

Pixel-stage sheets are not supported by these scripts; pixel stages use a
different loader.

Cross-script helpers
--------------------

`Coin Note.lua` and `Ring Note.lua` keep counters you can read from another
script, e.g. in a song's global script:

    local coins = callScript('custom_notetypes/Coin Note.lua', 'getCoins', {})

Both also expose `resetCoins()` / `resetRings()` so a dialogue or cutscene
script can zero the counter.

Mario Madness chart compatibility
---------------------------------

Charts written for Mario Madness use its Spanish note type names. For drop-in
compatibility, rename the files: 'nota veneno' style charts are outside this
engine's naming style, so the scripts here ship English names — to reuse an
MM-style chart, rename `Poison Note.lua` to `Nota veneno.lua` (and so on) and
the chart works unchanged. The sound effect names ('smw_coin', 'ringhit',
'waterswitch', 'smw_scroll', 'CAUSA', 'SHbullethit') are configurable at the
top of each file; put your own sounds in `sounds/` or set the constant to ''.

License
-------

The note-type logic is ported with credit, under the same Apache-2.0 license
as Mario Madness. Phoenix Engine is Apache-2.0 as well. Do not add assets to
this folder; scripts only.
