#!/usr/bin/env python3
"""Galaxy -> Phoenix chart port.

Reads GalaxyMod charts from /tmp/galaxy/assets/preload/data/<song>/ and writes
Phoenix-format charts to assets/preload/data/<song>/, plus copies the song
audio (Inst.ogg / Voices.ogg) to assets/songs/<song>/.

Galaxy encodes its custom note kinds in the *fractional* part of the lane:

    lane = K*10 + L + spec/100

    L   (lane % 10, 0..3)  base lane within the side
    K   (lane // 10)       0 = plain, 1 = Galaxy Random, 2 = Galaxy Sync,
                            3 = Galaxy Random Solo, 4 = Galaxy End Sustain
    spec                extra integer (0..99) the M_ charts read back

Opponent notes use base lanes 4..7 (K == 0) or the same K with L in 4..7
(K >= 1), i.e. floor(lane) in [4..7] or (floor(lane) >= 10 and floor(lane)%10 > 3).

Phoenix output note: [time, lane, sustain] for plain notes with no spec, or
[time, lane, sustain, kindStr, spec] when kindStr != '' or spec != 0, where
lane is 0..7 (base + 4 for opponent) and kindStr is one of
'' / 'Galaxy Random' / 'Galaxy Sync' / 'Galaxy Random Solo' / 'Galaxy End Sustain'.
The engine-side runtime resolution (random lane queues, synced flags, end
sustains) lives in play/helpers/PlayStateChartLoader.hx.
"""
import json
import math
import os
import shutil
import sys

GALAXY = '/tmp/galaxy'
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

KINDS = {
    1: 'Galaxy Random',
    2: 'Galaxy Sync',
    3: 'Galaxy Random Solo',
    4: 'Galaxy End Sustain',
}

# tutorial charts are the stock FNF tutorial; Phoenix keeps its own.
SKIP_SONGS = {'tutorial'}


def convert_note(note):
    t, lane, sus = float(note[0]), float(note[1]), float(note[2])
    fl = int(math.floor(lane + 1e-9))
    spec = int(round((lane - fl) * 100))
    kind = fl // 10
    base = fl % 4
    opp = (4 <= fl <= 7) or (fl >= 10 and fl % 10 > 3)
    out_lane = base + (4 if opp else 0)
    kind_str = KINDS.get(kind, '')
    if kind == 0 and spec == 0:
        out = [t, out_lane, sus]
    else:
        out = [t, out_lane, sus, kind_str, spec]
    return out, base, opp, kind, spec


def convert_chart(path, dest):
    with open(path) as f:
        g = json.load(f)
    meta = g['song']
    sections = g['notes']
    n_notes = n_special = 0
    new_sections = []
    for s in sections:
        sec = {
            'lengthInSteps': s.get('lengthInSteps', 16),
            'bpm': s.get('bpm', meta.get('bpm')),
            'changeBPM': s.get('changeBPM', False),
            'mustHitSection': s.get('mustHitSection', False),
            'sectionNotes': [],
            'typeOfSection': s.get('typeOfSection', 0),
            'altAnim': s.get('altAnim', False),
        }
        for n in s['sectionNotes']:
            out, base, opp, kind, spec = convert_note(n)
            sec['sectionNotes'].append(out)
            n_notes += 1
            if kind != 0 or spec != 0:
                n_special += 1
        new_sections.append(sec)

    out_meta = {
        'player1': 'bf-space' if meta.get('player1') == 'bf' else meta.get('player1'),
        'player2': meta.get('player2'),
        'song': meta.get('song'),
        'needsVoices': meta.get('needsVoices', True),
        'validScore': meta.get('validScore', True),
        'speed': meta.get('speed', 1),
        'bpm': meta.get('bpm'),
        'notes': new_sections,
    }
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, 'w') as f:
        json.dump({'song': out_meta}, f)
    return n_notes, n_special


def verify_chart(dest, src):
    """Re-derive every output note and check it matches the source encoding."""
    g = json.load(open(src))
    p = json.load(open(dest))['song']
    assert len(p['notes']) == len(g['notes']), 'section count'
    errors = 0
    for si, (gs, ps) in enumerate(zip(g['notes'], p['notes'])):
        if len(gs['sectionNotes']) != len(ps['sectionNotes']):
            print(f'  MISMATCH sec{si}: {len(gs["sectionNotes"])} vs {len(ps["sectionNotes"])}')
            errors += 1
            continue
        for gi, (gn, pn) in enumerate(zip(gs['sectionNotes'], ps['sectionNotes'])):
            _, base, opp, kind, spec = convert_note(gn)
            want_lane = base + (4 if opp else 0)
            if abs(pn[0] - float(gn[0])) > 1e-6 or pn[1] != want_lane or abs(pn[2] - float(gn[2])) > 1e-6:
                print(f'  MISMATCH sec{si} note{gi}: {gn} -> {pn} (want lane {want_lane})')
                errors += 1
            if kind != 0 or spec != 0:
                if len(pn) < 5 or pn[3] != KINDS.get(kind, '') or pn[4] != spec:
                    print(f'  MISMATCH kind sec{si} note{gi}: {gn} -> {pn} (want {KINDS.get(kind, "")} {spec})')
                    errors += 1
            else:
                if len(pn) != 3:
                    print(f'  MISMATCH plain sec{si} note{gi}: {gn} -> {pn}')
                    errors += 1
    return errors


def main():
    songs_dir = os.path.join(GALAXY, 'assets', 'songs')
    songs = sorted(
        d for d in os.listdir(os.path.join(GALAXY, 'assets', 'preload', 'data'))
        if d not in SKIP_SONGS and os.path.isdir(os.path.join(songs_dir, d))
    )
    total_charts = total_notes = total_special = 0
    for song in songs:
        src_dir = os.path.join(GALAXY, 'assets', 'preload', 'data', song)
        out_dir = os.path.join(REPO, 'assets', 'preload', 'data', song)
        for fname in sorted(os.listdir(src_dir)):
            if not fname.endswith('.json'):
                continue
            src = os.path.join(src_dir, fname)
            dest = os.path.join(out_dir, fname)
            n, k = convert_chart(src, dest)
            errs = verify_chart(dest, src)
            status = 'OK' if errs == 0 else f'{errs} ERRORS'
            print(f'{song}/{fname}: {n} notes ({k} special) -> {status}')
            total_charts += 1
            total_notes += n
            total_special += k
            if errs:
                sys.exit(1)

    # song audio
    oggs = 0
    for song in songs:
        src_song = os.path.join(songs_dir, song)
        out_song = os.path.join(REPO, 'assets', 'songs', song)
        os.makedirs(out_song, exist_ok=True)
        for name in ('Inst.ogg', 'Voices.ogg'):
            s = os.path.join(src_song, name)
            if os.path.exists(s):
                shutil.copy2(s, os.path.join(out_song, name))
                oggs += 1
    print(f'copied {oggs} ogg files')
    print(f'TOTAL: {total_charts} charts, {total_notes} notes, {total_special} special')
    print('ALL CHECKS PASSED')


if __name__ == '__main__':
    main()
