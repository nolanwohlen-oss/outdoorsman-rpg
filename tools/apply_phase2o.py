from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1))


def write(path: str, text: str) -> None:
    file = ROOT / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text)

# --- Physical tackle condition lives on the existing item condition field. ---
replace_once(
    "simulation/inventory.gd",
    'const TEST_EQUIPMENT := ["test_rod", "test_spoon", "test_hook", "test_reel", "test_line"]\nconst PRODUCTS := ["cleaned_fish", "cooked_fish", "cut_bait"]',
    'const TEST_EQUIPMENT := ["test_rod", "test_spoon", "test_hook", "test_reel", "test_line"]\nconst TRACKED_TACKLE := ["test_reel", "test_line"]\nconst PRODUCTS := ["cleaned_fish", "cooked_fish", "cut_bait"]',
)
replace_once(
    "simulation/inventory.gd",
    '\t\t\t_insert(record, kind, 1, container, "", 0, "", -1)',
    '\t\t\t_insert(record, kind, 1, container, "", 0, "", 1000 if kind in TRACKED_TACKLE else -1)',
)
replace_once(
    "simulation/inventory.gd",
    '''static func carried_id(record: Dictionary, kind: String) -> String:\n\tvar ids: Array = record.entries.keys()\n\tids.sort()\n\tfor id in ids:\n\t\tif record.entries[id].container == "pack" and record.entries[id].kind == kind:\n\t\t\treturn id\n\treturn ""\n\nstatic func _mass''',
    '''static func carried_id(record: Dictionary, kind: String) -> String:\n\tvar ids: Array = record.entries.keys()\n\tids.sort()\n\tfor id in ids:\n\t\tif record.entries[id].container == "pack" and record.entries[id].kind == kind:\n\t\t\treturn id\n\treturn ""\n\nstatic func tackle_condition(record: Dictionary, id: String) -> int:\n\tvar entry: Variant = record.entries.get(id)\n\tif not entry is Dictionary or entry.kind not in TRACKED_TACKLE:\n\t\treturn -1\n\t# -1 is the legacy Phase 2N sentinel. The first 2O tackle action materializes it as pristine.\n\treturn 1000 if int(entry.condition) < 0 else int(entry.condition)\n\nstatic func initialize_tackle(record: Dictionary, id: String) -> Dictionary:\n\tvar entry: Variant = record.entries.get(id)\n\tif not entry is Dictionary or entry.kind not in TRACKED_TACKLE:\n\t\treturn {"ok": false, "message": "Select a tracked line or reel."}\n\tif int(entry.condition) < 0:\n\t\tentry.condition = 1000\n\treturn {"ok": true, "condition": int(entry.condition)}\n\nstatic func apply_tackle_wear(record: Dictionary, line_id: String, reel_id: String, line_wear: int, reel_wear: int, break_line: bool = false) -> Dictionary:\n\tvar line_init := initialize_tackle(record, line_id)\n\tvar reel_init := initialize_tackle(record, reel_id)\n\tif not line_init.ok or not reel_init.ok or line_wear < 0 or reel_wear < 0:\n\t\treturn {"ok": false, "message": "Linked tackle condition cannot be updated."}\n\tvar line: Dictionary = record.entries[line_id]\n\tvar reel: Dictionary = record.entries[reel_id]\n\tline.condition = 0 if break_line else maxi(0, int(line.condition) - line_wear)\n\treel.condition = maxi(0, int(reel.condition) - reel_wear)\n\tvar broken := ""\n\tif int(line.condition) == 0:\n\t\tbroken = "line"\n\telif int(reel.condition) == 0:\n\t\tbroken = "reel"\n\treturn {"ok": true, "line": int(line.condition), "reel": int(reel.condition), "broken": broken}\n\nstatic func service_tackle(record: Dictionary, id: String) -> Dictionary:\n\tvar init := initialize_tackle(record, id)\n\tif not init.ok:\n\t\treturn init\n\tvar entry: Dictionary = record.entries[id]\n\tvar before := int(entry.condition)\n\tif before >= 1000:\n\t\treturn {"ok": false, "message": "Selected tackle is already at full condition."}\n\tvar restored := 300 if entry.kind == "test_line" else 250\n\tvar minutes := 15 if entry.kind == "test_line" else 20\n\tentry.condition = mini(1000, before + restored)\n\treturn {"ok": true, "minutes": minutes, "before": before, "after": int(entry.condition), "message": "Serviced %s from %d to %d / 1000." % [id, before, int(entry.condition)]}\n\nstatic func replace_tackle(record: Dictionary, id: String) -> Dictionary:\n\tvar entry: Variant = record.entries.get(id)\n\tif not entry is Dictionary or entry.kind not in TRACKED_TACKLE:\n\t\treturn {"ok": false, "message": "Select a tracked line or reel."}\n\tvar kind: String = entry.kind\n\tvar container: String = entry.container\n\trecord.entries.erase(id)\n\tvar new_id := _insert(record, kind, 1, container, "", 0, "", 1000)\n\treturn {"ok": true, "minutes": 10, "old_id": id, "new_id": new_id, "message": "Replaced %s with %s at full condition." % [id, new_id]}\n\nstatic func _mass''',
)
replace_once(
    "simulation/inventory.gd",
    '''\t\telif e.kind == "whole_fish":\n\t\t\tif e.quantity != 1 or e.species not in Ecology.SPECIES or e.origin not in Map.ZONE_IDS or e.condition < 0:\n\t\t\t\treturn PackedStringArray(["Invalid individual fish provenance."])\n\t\telif e.mass_g != _mass(e.kind, int(e.quantity)) or e.species != "" or e.origin != "" or e.caught_ms != 0 or e.condition != -1:\n\t\t\treturn PackedStringArray(["Invalid supply mass or fabricated provenance."])''',
    '''\t\telif e.kind == "whole_fish":\n\t\t\tif e.quantity != 1 or e.species not in Ecology.SPECIES or e.origin not in Map.ZONE_IDS or e.condition < 0:\n\t\t\t\treturn PackedStringArray(["Invalid individual fish provenance."])\n\t\telif e.kind in TRACKED_TACKLE:\n\t\t\t# -1 remains accepted only as the pristine legacy sentinel from Phase 2N saves.\n\t\t\tif e.mass_g != _mass(e.kind, int(e.quantity)) or e.species != "" or e.origin != "" or e.caught_ms != 0:\n\t\t\t\treturn PackedStringArray(["Invalid tracked tackle record."])\n\t\telif e.mass_g != _mass(e.kind, int(e.quantity)) or e.species != "" or e.origin != "" or e.caught_ms != 0 or e.condition != -1:\n\t\t\treturn PackedStringArray(["Invalid supply mass or fabricated provenance."])''',
)

# --- Rigging materializes legacy condition. Each fight round applies deterministic wear. ---
replace_once(
    "simulation/kernel.gd",
    '''\tif rod_id.is_empty() or reel_id.is_empty() or line_id.is_empty() or terminal_id.is_empty():\n\t\treturn _failure("Carry the test rod, reel, line, and compatible terminal tackle.")\n\tif mode == "bait":''',
    '''\tif rod_id.is_empty() or reel_id.is_empty() or line_id.is_empty() or terminal_id.is_empty():\n\t\treturn _failure("Carry the test rod, reel, line, and compatible terminal tackle.")\n\tInventory.initialize_tackle(world.inventory, line_id)\n\tInventory.initialize_tackle(world.inventory, reel_id)\n\tif Inventory.tackle_condition(world.inventory, line_id) <= 0 or Inventory.tackle_condition(world.inventory, reel_id) <= 0:\n\t\treturn _failure("Service or replace broken line/reel at camp before rigging.")\n\tif mode == "bait":''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tvar result := Fishing.resolve_round(candidate.world.fishing, action, candidate.world.environment.water_by_zone[candidate.world.player_zone])\n\tif not result.ok:\n\t\treturn result\n\tvar species: String = candidate.world.fishing.target_species\n\tif result.status != "continue":''',
    '''\tvar water: Dictionary = candidate.world.environment.water_by_zone[candidate.world.player_zone]\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water)\n\tif not result.ok:\n\t\treturn result\n\tvar line_id: String = candidate.world.fishing.line_item_id\n\tvar reel_id: String = candidate.world.fishing.reel_item_id\n\tvar power_load := clampi(int(Fishing.fight_power(candidate.world.fishing, water) / 250), 0, 8)\n\tvar line_wear := 6 + clampi(int(abs(int(candidate.world.fishing.line_tension) - 500) / 50), 0, 12) + power_load\n\tvar reel_wear := 3 + power_load + (8 if action == "reel" else (4 if action == "pressure" else 2))\n\tvar wear := Inventory.apply_tackle_wear(candidate.world.inventory, line_id, reel_id, line_wear, reel_wear, result.status == "overload")\n\tif not wear.ok:\n\t\treturn _failure(wear.message)\n\tif result.status == "continue" and not String(wear.broken).is_empty():\n\t\tresult.status = "tackle_failure"\n\t\tresult.message = "The %s failed under load; the fish escaped." % wear.broken\n\telif result.status == "overload":\n\t\tresult.message += " Line condition is now 0/1000."\n\tvar species: String = candidate.world.fishing.target_species\n\tif result.status != "continue":''',
)
replace_once(
    "simulation/kernel.gd",
    '''\t\tvar ready := Fishing.landing_ready(candidate.world.fishing)\n\t\tvar detail := "%s against %s; stamina %d, tension %d, distance %d cm%s." % [action.replace("_", " ").capitalize(), species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]\n\t\tcandidate._log("fish_fight", detail)''',
    '''\t\tvar ready := Fishing.landing_ready(candidate.world.fishing)\n\t\tvar detail := "%s against %s; stamina %d, tension %d, distance %d cm; line %d/1000, reel %d/1000%s." % [action.replace("_", " ").capitalize(), species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.line, wear.reel, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]\n\t\tcandidate._log("fish_fight", detail)''',
)
replace_once(
    "simulation/kernel.gd",
    '''func cancel_fishing() -> Dictionary:\n''',
    '''func service_tackle(id: String) -> Dictionary:\n\tif world.fishing.state != "idle":\n\t\treturn _failure("Finish or cancel fishing before servicing tackle.")\n\tif world.player_zone != "elevated_camp":\n\t\treturn _failure("Tackle service requires the elevated camp work area.")\n\tvar candidate = get_script().new(world.seed)\n\tvar restored: Dictionary = candidate.restore(world.to_record())\n\tif not restored.ok:\n\t\treturn _failure("Cannot start service from invalid world state.")\n\tvar result := Inventory.service_tackle(candidate.world.inventory, id)\n\tif not result.ok:\n\t\treturn result\n\tvar duration := int(result.minutes) * MINUTE_MS\n\tif world.game_time_ms > World.MAX_TIME_MS - duration:\n\t\treturn _failure("Service exceeds the supported clock range.")\n\tvar elapsed: Dictionary = candidate._advance(duration, true)\n\tif not elapsed.ok or elapsed.interrupted:\n\t\treturn _failure("A scheduled interruption blocks service; world unchanged.")\n\tcandidate._log("observe", result.message)\n\tvar errors := World.validate(candidate.world.to_record())\n\tif not errors.is_empty():\n\t\treturn _failure("Service validation failed; world unchanged.")\n\tworld = candidate.world\n\treturn {"ok": true, "message": result.message}\n\nfunc replace_tackle(id: String) -> Dictionary:\n\tif world.fishing.state != "idle":\n\t\treturn _failure("Finish or cancel fishing before replacing tackle.")\n\tif world.player_zone != "elevated_camp":\n\t\treturn _failure("Tackle replacement requires the elevated camp work area.")\n\tvar candidate = get_script().new(world.seed)\n\tvar restored: Dictionary = candidate.restore(world.to_record())\n\tif not restored.ok:\n\t\treturn _failure("Cannot start replacement from invalid world state.")\n\tvar result := Inventory.replace_tackle(candidate.world.inventory, id)\n\tif not result.ok:\n\t\treturn result\n\tvar duration := int(result.minutes) * MINUTE_MS\n\tif world.game_time_ms > World.MAX_TIME_MS - duration:\n\t\treturn _failure("Replacement exceeds the supported clock range.")\n\tvar elapsed: Dictionary = candidate._advance(duration, true)\n\tif not elapsed.ok or elapsed.interrupted:\n\t\treturn _failure("A scheduled interruption blocks replacement; world unchanged.")\n\tcandidate._log("observe", result.message + " Test-bench replacement has no economy cost yet.")\n\tvar errors := World.validate(candidate.world.to_record())\n\tif not errors.is_empty():\n\t\treturn _failure("Replacement validation failed; world unchanged.")\n\tworld = candidate.world\n\treturn {"ok": true, "message": result.message + " (test-bench spare; economy deferred)"}\n\nfunc cancel_fishing() -> Dictionary:\n''',
)

# --- Phone UI: expose recovery and bump development build identity. ---
replace_once("scripts/main.gd", 'SYSTEMS LAB  /  PHASE 2N', 'SYSTEMS LAB  /  PHASE 2O')
replace_once("scripts/main.gd", 'var build := "v0.15.0 · local build"', 'var build := "v0.16.0 · local build"')
replace_once("scripts/main.gd", 'str(info.get("version", "0.15.0"))', 'str(info.get("version", "0.16.0"))')
replace_once(
    "scripts/main.gd",
    '''\t_button(column, "Store selected item at camp", _transfer_item.bind("camp"))\n\t_button(column, "Take selected item into pack", _transfer_item.bind("pack"))\n\t_button(column, "Clean selected fish · 10 min", _use_item.bind("clean"))''',
    '''\t_button(column, "Store selected item at camp", _transfer_item.bind("camp"))\n\t_button(column, "Take selected item into pack", _transfer_item.bind("pack"))\n\t_button(column, "Service selected line/reel", _service_tackle)\n\t_button(column, "Replace selected line/reel · 10 min", _replace_tackle)\n\t_button(column, "Clean selected fish · 10 min", _use_item.bind("clean"))''',
)
replace_once(
    "scripts/main.gd",
    '''\tcolumn.add_child(_label("Transfers require camp. Select any item to inspect it. Fish remain resources, not ration calories. Condition is recorded but spoilage is not simulated yet.", 20, MUTED))''',
    '''\tcolumn.add_child(_label("Transfers require camp. Select any item to inspect it. Fish remain resources, not ration calories. Line and reel condition now wear during fights; service preserves identity, replacement creates a new item ID. Replacement cost is a test placeholder until economy exists.", 20, MUTED))''',
)
replace_once(
    "scripts/main.gd",
    '''func _use_item(action: String) -> void:\n\tif not _can_act() or item_picker.selected < 0:\n\t\treturn\n\t_after_action(kernel.use_inventory(str(item_picker.get_item_metadata(item_picker.selected)), action))\n\nfunc _zone_name''',
    '''func _use_item(action: String) -> void:\n\tif not _can_act() or item_picker.selected < 0:\n\t\treturn\n\t_after_action(kernel.use_inventory(str(item_picker.get_item_metadata(item_picker.selected)), action))\n\nfunc _service_tackle() -> void:\n\tif not _can_act() or item_picker.selected < 0:\n\t\treturn\n\t_after_action(kernel.service_tackle(str(item_picker.get_item_metadata(item_picker.selected))))\n\nfunc _replace_tackle() -> void:\n\tif not _can_act() or item_picker.selected < 0:\n\t\treturn\n\t_after_action(kernel.replace_tackle(str(item_picker.get_item_metadata(item_picker.selected))))\n\nfunc _zone_name''',
)

# Build metadata.
replace_once("tools/prepare_build.py", '"version": "0.15.0", "phase": "2N"', '"version": "0.16.0", "phase": "2O"')
replace_once("tools/prepare_build.py", 'version/name="0.15.0-dev.{number}"', 'version/name="0.16.0-dev.{number}"')
replace_once("tools/prepare_build.py", 'Prepared Phase 2N build', 'Prepared Phase 2O build')

# Dedicated invariant test without rewriting the large historical suite.
write(
    "tests/phase_2o.gd",
    '''extends SceneTree\n\nconst Kernel = preload("res://simulation/kernel.gd")\nconst Inventory = preload("res://simulation/inventory.gd")\nconst World = preload("res://simulation/world_state.gd")\n\nfunc fail(message: String) -> void:\n\tpush_error(message)\n\tquit(1)\n\nfunc _init() -> void:\n\tvar k := Kernel.new(24680)\n\tvar line_id := Inventory.carried_id(k.world.inventory, "test_line")\n\tvar reel_id := Inventory.carried_id(k.world.inventory, "test_reel")\n\tif line_id.is_empty() or reel_id.is_empty():\n\t\tfail("2O: test tackle missing")\n\t\treturn\n\tif not k.rig_fishing("lure").ok or Inventory.tackle_condition(k.world.inventory, line_id) != 1000 or Inventory.tackle_condition(k.world.inventory, reel_id) != 1000:\n\t\tfail("2O: rigging did not materialize pristine tackle condition")\n\t\treturn\n\tif not k.cast_fishing().ok:\n\t\tfail("2O: cast failed")\n\t\treturn\n\tk.advance_game_ms(120000)\n\tif not k.hook_fishing().ok:\n\t\tfail("2O: hook failed")\n\t\treturn\n\tvar cue: String = k.world.fishing.fish_cue\n\tvar action := "give_line" if cue == "surge" else ("pressure" if cue == "pull" else "reel")\n\tvar fought := k.fight_fishing(action)\n\tif not fought.ok:\n\t\tfail("2O: fight action failed: " + fought.message)\n\t\treturn\n\tvar line_after := Inventory.tackle_condition(k.world.inventory, line_id)\n\tvar reel_after := Inventory.tackle_condition(k.world.inventory, reel_id)\n\tif line_after >= 1000 or reel_after >= 1000 or line_after < 0 or reel_after < 0:\n\t\tfail("2O: deterministic fight wear was not applied")\n\t\treturn\n\tif k.world.fishing.state != "idle":\n\t\tk.cancel_fishing()\n\tvar moved := k.move_plan("elevated_camp")\n\tif not moved.ok:\n\t\tfail("2O: could not reach camp for recovery: " + moved.message)\n\t\treturn\n\tvar before_service := Inventory.tackle_condition(k.world.inventory, line_id)\n\tvar serviced := k.service_tackle(line_id)\n\tif not serviced.ok or Inventory.tackle_condition(k.world.inventory, line_id) <= before_service or not k.world.inventory.entries.has(line_id):\n\t\tfail("2O: service did not preserve identity and restore condition")\n\t\treturn\n\tvar replaced := k.replace_tackle(reel_id)\n\tvar new_reel_id := Inventory.carried_id(k.world.inventory, "test_reel")\n\tif not replaced.ok or new_reel_id == reel_id or k.world.inventory.entries.has(reel_id) or Inventory.tackle_condition(k.world.inventory, new_reel_id) != 1000:\n\t\tfail("2O: replacement did not create a fresh full-condition identity")\n\t\treturn\n\tvar errors := World.validate(k.world.to_record())\n\tif not errors.is_empty():\n\t\tfail("2O: final world validation failed: " + " ".join(errors))\n\t\treturn\n\tprint("Phase 2O tackle wear/service/replacement invariants: passed.")\n\tquit(0)\n''',
)
replace_once(
    "tools/check.sh",
    'timeout 60 "$godot_bin" --headless --path "$project_root" --script tests/run.gd 2>&1 | tee "$project_root/build/tests.log"\nprobe_dir=',
    'timeout 60 "$godot_bin" --headless --path "$project_root" --script tests/run.gd 2>&1 | tee "$project_root/build/tests.log"\ntimeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2o.gd 2>&1 | tee "$project_root/build/phase-2o.log"\nprobe_dir=',
)
replace_once(
    "tools/check.sh",
    '"$project_root/build/import.log" "$project_root/build/tests.log" "$project_root/build/save-write.log" "$project_root/build/save-read.log"',
    '"$project_root/build/import.log" "$project_root/build/tests.log" "$project_root/build/phase-2o.log" "$project_root/build/save-write.log" "$project_root/build/save-read.log"',
)

write(
    "docs/PHASE_2O.md",
    '''# Phase 2O — tackle condition and recovery\n\nDevelopment v0.16.0. World schema remains 14 because Phase 2O activates the already-versioned item `condition` field rather than changing record shape. Existing Phase 2N line/reel records use `-1` as a legacy pristine sentinel; the first 2O tackle action materializes that value as 1000/1000.\n\n## Delivered\n\n- Linked test line and reel now have persistent 0–1000 condition.\n- Every fish-fight choice applies deterministic line and reel wear from tension, action and fight load.\n- Overload explicitly breaks the linked line to 0/1000. A line or reel that reaches zero loses the fish and cannot be used to prepare another rig.\n- Tackle wear is resolved inside the same candidate-world transaction as the fight action. Validation failure leaves time, fish state and equipment unchanged.\n- Camp service preserves item identity and restores a bounded amount of condition: line +300 in 15 game minutes; reel +250 in 20 game minutes.\n- Camp replacement takes 10 game minutes, removes the selected line/reel identity and creates a new full-condition item ID. Replacement currently uses a free systems-lab spare; price, vendors and consumable replacement stock are deferred to the economy/item-content passes.\n- Service and replacement reject active fishing and scheduled-action interruption without partial mutation.\n- Existing Phase 2N saves remain loadable; the legacy `-1` tackle sentinel is not silently advanced while the game is closed.\n\n## Phone gate\n\n1. Install the newest APK as an update and load the existing world. Footer must show `v0.16.0`.\n2. Select the test line and reel in Layers. A Phase 2N save may initially show condition unknown; prepare either fishing rig and confirm both materialize as 1000/1000.\n3. Hook a fish and make at least one correct fight choice. Re-open Layers and confirm both linked line and reel are below 1000 and retain those exact values after save/reload.\n4. Finish/cancel the encounter, travel to elevated camp, select the line and use **Service selected line/reel**. Confirm 15 game minutes pass, the same line item ID remains, and condition rises by up to 300.\n5. Select the reel and use **Replace selected line/reel**. Confirm 10 game minutes pass, the old reel ID disappears, a new reel ID appears at 1000/1000, and save/reload preserves the new identity.\n6. Wear or force a linked item to zero during testing and confirm a new rig is rejected until that item is serviced or replaced.\n\n## Deliberate limits\n\nWear values are deterministic test coefficients, not final fishing-physics tuning. Rod, hook/spoon, knots, drag settings, line type/strength, repair materials, vendor cost and economy are not modeled here. Replacement is intentionally a no-cost test fixture so identity replacement and recovery can be proven before economy content exists.\n''',
)
replace_once("docs/IMPLEMENTATION_ORDER.md", "Lettered slices 2C–2N now cover", "Lettered slices 2C–2O now cover")
replace_once(
    "docs/IMPLEMENTATION_ORDER.md",
    '''Phase 2N must pass its Android checklist before another system depends on it. The next proposed slice is tackle condition and recovery: deterministic wear on the linked line/reel, explicit service/replacement actions, and save-safe failure recovery. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.''',
    '''Phase 2O adds persistent line/reel condition, deterministic fight wear, broken-tackle rejection, identity-preserving service and explicit item replacement. It must pass its Android checklist before another system depends on it. The next proposed fishing slice is deeper rig causality: terminal-tackle/rod condition, line strength and drag/rig choices feeding the same auditable fight model. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.''',
)

# Remove the one-shot transformer and workflow from the resulting source commit.
(ROOT / "tools/apply_phase2o.py").unlink()
workflow = ROOT / ".github/workflows/phase2o_apply.yml"
if workflow.exists():
    workflow.unlink()

print("Phase 2O source transformation applied.")
