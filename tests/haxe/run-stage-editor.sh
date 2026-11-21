#!/usr/bin/env bash
# Exercise the Stage Editor core (JSON graph, filters, undo, Week 1 template)
# without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/data"
cp source/data/StageEditorCore.hx "$test_source/data/"
cp source/data/StageUndoStack.hx "$test_source/data/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main StageEditorSpec --interp

# --- Static guard: the menu actually opens the editor, and PlayState spawns JSON objects
grep -q "'Stage Editor'" source/editors/MasterEditorMenu.hx \
  || { echo "FAIL: MasterEditorMenu is missing the Stage Editor row" >&2; exit 1; }
grep -q "StageEditorState" source/editors/MasterEditorMenu.hx \
  || { echo "FAIL: MasterEditorMenu does not switch to StageEditorState" >&2; exit 1; }
grep -q "PlayStateStageObjects.spawn" source/play/PlayState.hx \
  || { echo "FAIL: PlayState does not spawn JSON stage objects" >&2; exit 1; }
grep -q "PlayStateStageObjects" source/play/PlayState.hx \
  || { echo "FAIL: PlayState does not import PlayStateStageObjects" >&2; exit 1; }
grep -q "saveToMod" source/editors/StageEditorState.hx \
  || { echo "FAIL: StageEditorState is missing Save to Mod" >&2; exit 1; }
grep -q "modStagePath" source/data/StageEditorCore.hx \
  || { echo "FAIL: StageEditorCore is missing modStagePath" >&2; exit 1; }
grep -q "packFilters" source/data/StageEditorCore.hx \
  || { echo "FAIL: StageEditorCore is missing packFilters" >&2; exit 1; }

echo "Stage editor menu/runtime wiring: PASS"
