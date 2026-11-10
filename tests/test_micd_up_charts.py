"""Regression checks for the imported Mic'd Up chart set and menu integration."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'assets/preload/data'
WEEKS = ROOT / 'assets/preload/weeks'
DIFFICULTIES = ('noob', 'expert', 'insane')


def song_path(name):
    return name.lower().replace(' ', '-')


class MicdUpChartsTest(unittest.TestCase):
    def test_complete_weeks_and_valid_charts(self):
        for week in ('tutorial', *(f'week{i}' for i in range(1, 7))):
            songs = json.loads((WEEKS / f'{week}.json').read_text())['songs']
            for name, *_ in songs:
                path = song_path(name)
                for difficulty in DIFFICULTIES:
                    with self.subTest(song=name, difficulty=difficulty):
                        chart = json.loads((DATA / path / f'{path}-{difficulty}.json').read_text())['song']
                        self.assertEqual(song_path(chart['song']), path)
                        self.assertTrue(chart['notes'])
                        self.assertGreater(chart['bpm'], 0)
                        self.assertGreater(chart['speed'], 0)
                        self.assertEqual(chart['specialAudioName'], '')
                        self.assertEqual(chart['specialEventsName'], '')
                        for section in chart['notes']:
                            self.assertIn('mustHitSection', section)
                            for note in section['sectionNotes']:
                                self.assertGreaterEqual(len(note), 3)

    def test_no_unavailable_week7_charts_and_labels_exist(self):
        for name, *_ in json.loads((WEEKS / 'week7.json').read_text())['songs']:
            for difficulty in DIFFICULTIES:
                path = song_path(name)
                self.assertFalse((DATA / path / f'{path}-{difficulty}.json').exists())
        for difficulty in DIFFICULTIES:
            self.assertTrue((ROOT / f'assets/preload/images/menudifficulties/{difficulty}.png').is_file())


if __name__ == '__main__':
    unittest.main()
