from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"Audit patch anchor count for {path}: {text.count(old)}; expected 1\n{old[:160]!r}")
    p.write_text(text.replace(old, new, 1))


replace_once(
    "simulation/kernel.gd",
    '''\tfor id in [rod_id, reel_id, line_id, terminal_id]:\n\t\tInventory.initialize_tackle(world.inventory, id)\n\t\tif Inventory.tackle_condition(world.inventory, id) <= 0:\n\t\t\treturn _failure("Service or replace broken rig equipment at camp before rigging.")\n\tif mode == "bait":\n\t\tvar bait: Variant = world.inventory.entries.get(bait_item_id)\n\t\tif not bait is Dictionary or bait.kind != "cut_bait" or bait.container != "pack" or int(bait.mass_g) < 50:\n\t\t\treturn _failure("Select a carried cut-bait item with at least 50 g remaining.")\n\tworld.fishing.state = "rigged"\n''',
    '''\tif mode == "bait":\n\t\tvar bait: Variant = world.inventory.entries.get(bait_item_id)\n\t\tif not bait is Dictionary or bait.kind != "cut_bait" or bait.container != "pack" or int(bait.mass_g) < 50:\n\t\t\treturn _failure("Select a carried cut-bait item with at least 50 g remaining.")\n\t# Materialize legacy condition only on a private copy. A rejected rig must not\n\t# mutate the authoritative inventory, even when old saves still use -1.\n\tvar prepared_inventory: Dictionary = world.inventory.duplicate(true)\n\tfor id in [rod_id, reel_id, line_id, terminal_id]:\n\t\tvar initialized := Inventory.initialize_tackle(prepared_inventory, id)\n\t\tif not initialized.ok or Inventory.tackle_condition(prepared_inventory, id) <= 0:\n\t\t\treturn _failure("Service or replace broken rig equipment at camp before rigging.")\n\tworld.inventory = prepared_inventory\n\tworld.fishing.state = "rigged"\n''',
)

replace_once(
    "simulation/kernel.gd",
    '''\tvar rod_condition := Inventory.tackle_condition(candidate.world.inventory, rod_id)\n\tvar line_limit := Inventory.line_load_limit(candidate.world.inventory, line_id) - int((1000 - rod_condition) / 4)\n\tline_limit = clampi(line_limit, 450, Fishing.OVERLOAD_LIMIT)\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, line_limit)\n\tif not result.ok:\n\t\treturn result\n\tvar power_load := clampi(int(Fishing.fight_power(candidate.world.fishing, water) / 250), 0, 8)\n\tvar tension_load := clampi(int(abs(int(candidate.world.fishing.line_tension) - 500) / 50), 0, 12)\n\tvar line_wear := 6 + tension_load + power_load\n\tvar reel_wear := 3 + power_load + (8 if action == "reel" else (4 if action == "pressure" else 2))\n\tvar rod_wear := 2 + power_load + (5 if action == "pressure" else 2)\n\tvar terminal_wear := 2 + power_load + tension_load\n\tvar terminal_limit := Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar terminal_break: bool = result.status == "continue" and int(candidate.world.fishing.line_tension) >= terminal_limit\n\tvar wear := Inventory.apply_rig_wear(candidate.world.inventory, rod_id, reel_id, line_id, terminal_id, rod_wear, reel_wear, line_wear, terminal_wear, result.status == "overload", terminal_break)\n\tif not wear.ok:\n\t\treturn _failure(wear.message)\n\tif result.status == "continue" and not String(wear.broken).is_empty():\n\t\tresult.status = "tackle_failure"\n\t\tresult.message = "The %s failed under load; the fish escaped." % wear.broken\n\telif result.status == "overload":\n\t\tresult.message += " Line condition is now 0/1000."\n\tvar species: String = candidate.world.fishing.target_species\n\tif result.status != "continue":\n\t\tcandidate.world.fishing.lost_count += 1\n\t\tcandidate.world.fishing.last_outcome = "%s lost: %s" % [species, result.message]\n\t\tFishing.clear_active(candidate.world.fishing)\n\t\tcandidate._log("fish_lost", candidate.world.fishing.last_outcome)\n\telse:\n''',
    '''\tvar rod_condition: int = Inventory.tackle_condition(candidate.world.inventory, rod_id)\n\tvar line_limit: int = Inventory.line_load_limit(candidate.world.inventory, line_id) - int((1000 - rod_condition) / 4)\n\tline_limit = clampi(line_limit, 450, Fishing.OVERLOAD_LIMIT)\n\tvar terminal_limit: int = Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar overload_limit: int = mini(line_limit, terminal_limit)\n\tvar overload_component := "terminal tackle" if terminal_limit < line_limit else "line"\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, overload_limit)\n\tif not result.ok:\n\t\treturn result\n\tvar power_load := clampi(int(Fishing.fight_power(candidate.world.fishing, water) / 250), 0, 8)\n\tvar tension_load := clampi(int(abs(int(candidate.world.fishing.line_tension) - 500) / 50), 0, 12)\n\tvar line_wear := 6 + tension_load + power_load\n\tvar reel_wear := 3 + power_load + (8 if action == "reel" else (4 if action == "pressure" else 2))\n\tvar rod_wear := 2 + power_load + (5 if action == "pressure" else 2)\n\tvar terminal_wear := 2 + power_load + tension_load\n\tvar overload_line: bool = result.status == "overload" and overload_component == "line"\n\tvar overload_terminal: bool = result.status == "overload" and overload_component == "terminal tackle"\n\tvar wear := Inventory.apply_rig_wear(candidate.world.inventory, rod_id, reel_id, line_id, terminal_id, rod_wear, reel_wear, line_wear, terminal_wear, overload_line, overload_terminal)\n\tif not wear.ok:\n\t\treturn _failure(wear.message)\n\tif result.status == "continue" and not String(wear.broken).is_empty():\n\t\tresult.status = "tackle_failure"\n\t\tresult.message = "The %s failed under load; the fish escaped." % wear.broken\n\telif result.status == "overload":\n\t\tif overload_terminal:\n\t\t\tresult.status = "tackle_failure"\n\t\tresult.message = "The %s failed under excessive load; the fish escaped." % overload_component\n\tvar species: String = candidate.world.fishing.target_species\n\tif result.status != "continue":\n\t\tvar failure_detail := "%s / %s drag against %s failed (%s); stamina %d, tension %d, distance %d cm; rod %d, reel %d, line %d, terminal %d / 1000." % [action.replace("_", " ").capitalize(), drag, species, result.message, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.rod, wear.reel, wear.line, wear.terminal]\n\t\tcandidate.world.fishing.lost_count += 1\n\t\tcandidate.world.fishing.last_outcome = "%s lost: %s" % [species, result.message]\n\t\tFishing.clear_active(candidate.world.fishing)\n\t\tcandidate._log("fish_lost", failure_detail)\n\telse:\n''',
)

replace_once(
    "simulation/inventory.gd",
    'return {"ok": false, "message": "Select a tracked line or reel."}',
    'return {"ok": false, "message": "Select a tracked rig component."}',
)
replace_once(
    "simulation/inventory.gd",
    'return {"ok": false, "message": "Select a tracked line or reel."}',
    'return {"ok": false, "message": "Select a tracked rig component."}',
)

replace_once(
    "scripts/main.gd",
    '''\t_button(column, "Service selected line/reel", _service_tackle)\n\t_button(column, "Replace selected line/reel · 10 min", _replace_tackle)\n''',
    '''\t_button(column, "Service selected rig component", _service_tackle)\n\t_button(column, "Replace selected rig component · 10 min", _replace_tackle)\n''',
)
replace_once(
    "scripts/main.gd",
    'Fish remain resources, not ration calories. Line and reel condition now wear during fights; service preserves identity, replacement creates a new item ID.',
    'Fish remain resources, not ration calories. Rod, reel, line and terminal-tackle condition now wear during fights; service preserves identity, replacement creates a new item ID.',
)
replace_once(
    "scripts/main.gd",
    '''\t\t\tfishing_status.text = "HOOKED: %s · %d g\\nCue: %s\\nFish stamina: %d · Line tension: %d / 1000\\nDistance: %.1f m · Fight choices: %d\\n%s\\nRetained %d · Released %d · Lost %d\\nLast handling: %s · condition %d/1000" % [String(f.target_species).replace("_", " ").capitalize(), f.last_catch_weight_g, String(f.fish_cue).to_upper(), f.fish_stamina, f.line_tension, float(f.fish_distance_cm) / 100.0, f.fight_round, "READY TO LAND" if ready else "Keep fighting", f.retained_count, f.released_count, f.lost_count, f.last_handling_method if not f.last_handling_method.is_empty() else "none", f.last_handling_condition]\n''',
    '''\t\t\tfishing_status.text = "HOOKED: %s · %d g\\nCue: %s · Selected drag: %s\\nFish stamina: %d · Line tension: %d / 1000\\nDistance: %.1f m · Fight choices: %d\\n%s\\nRetained %d · Released %d · Lost %d\\nLast handling: %s · condition %d/1000" % [String(f.target_species).replace("_", " ").capitalize(), f.last_catch_weight_g, String(f.fish_cue).to_upper(), selected_drag.capitalize(), f.fish_stamina, f.line_tension, float(f.fish_distance_cm) / 100.0, f.fight_round, "READY TO LAND" if ready else "Keep fighting", f.retained_count, f.released_count, f.lost_count, f.last_handling_method if not f.last_handling_method.is_empty() else "none", f.last_handling_condition]\n''',
)
replace_once(
    "scripts/main.gd",
    '''func _set_drag(value: String) -> void:\n\tif value in Fishing.DRAG_SETTINGS:\n\t\tselected_drag = value\n\t\t_status("Drag set to %s for the next fight choice." % value)\n''',
    '''func _set_drag(value: String) -> void:\n\tif value in Fishing.DRAG_SETTINGS:\n\t\tselected_drag = value\n\t\t_status("Drag set to %s for the next fight choice." % value)\n\t\t_refresh()\n''',
)

replace_once(
    "tools/check.sh",
    '''if rg -n --glob '*.gd' --glob '*.cfg' --glob '*.py' '([0-9]+ tokens truncated|content truncated|omitted [0-9]+ lines)' "$project_root"; then\n  echo "Possible truncated tool output found in source; restore the complete source." >&2\n  exit 1\nfi\n''',
    '''if ! PROJECT_ROOT="$project_root" python3 - <<'PY'\nimport os\nfrom pathlib import Path\nimport re\nimport sys\n\nroot = Path(os.environ["PROJECT_ROOT"])\npattern = re.compile(r"([0-9]+ tokens truncated|content truncated|omitted [0-9]+ lines)")\nfound = []\nfor path in root.rglob("*"):\n    if not path.is_file() or path.suffix not in {".gd", ".cfg", ".py"}:\n        continue\n    if any(part in {".git", ".tools", "build"} for part in path.parts):\n        continue\n    for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):\n        if pattern.search(line):\n            found.append(f"{path.relative_to(root)}:{number}:{line}")\nif found:\n    print("\\n".join(found))\n    sys.exit(1)\nPY\nthen\n  echo "Possible truncated tool output found in source; restore the complete source." >&2\n  exit 1\nfi\n''',
)

replace_once(
    "docs/IMPLEMENTATION_ORDER.md",
    '''Lettered slices 2C–2O now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, and explicit landing/post-catch condition. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.\n\nPhase 2O adds persistent line/reel condition, deterministic fight wear, broken-tackle rejection, identity-preserving service and explicit item replacement. It must pass its Android checklist before another system depends on it. The next proposed fishing slice is deeper rig causality: terminal-tackle/rod condition, line strength and drag/rig choices feeding the same auditable fight model. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.\n''',
    '''Lettered slices 2C–2P now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, and deeper full-rig causality. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.\n\nPhase 2P adds persistent rod/reel/line/terminal condition, deterministic full-rig wear, condition-dependent load limits, explicit loose/balanced/tight drag choices, weakest-link failure ownership, auditable failed rounds, broken-tackle rejection, and camp service/replacement. Its full code audit must pass automation and its Android checklist must pass on the physical phone before Phase 2Q depends on it. The next lettered slice is intentionally not declared complete or locked in by this roadmap until that gate closes. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.\n''',
)

phase_doc = ROOT / "docs/PHASE_2P.md"
phase_text = phase_doc.read_text()
anchor = "## Android phone gate\n"
if phase_text.count(anchor) != 1:
    raise SystemExit("Phase 2P audit section anchor missing")
audit_section = '''## Full-audit corrections\n\nThe post-merge audit tightened the gate without changing the Phase 2P save shape or test coefficients. Rejected rig preparation is now atomic even for legacy `-1` tackle condition; the lower of the line/rod envelope and terminal-tackle limit owns an overload; failed fight events record the chosen drag and all four final condition values before the encounter is cleared; the dedicated test covers save/reload, broken-rig rejection, replacement identity and the weakest-link case; and CI no longer depends on an unavailable `rg` binary for its source-corruption guard. Temporary branch-only source-transformer workflows/scripts were also removed from the canonical repository.\n\n'''
phase_doc.write_text(phase_text.replace(anchor, audit_section + anchor, 1))

(ROOT / "tests/phase_2p.gd").write_text(r'''extends SceneTree

const Kernel = preload("res://simulation/kernel.gd")
const Inventory = preload("res://simulation/inventory.gd")
const Fishing = preload("res://simulation/fishing.gd")
const World = preload("res://simulation/world_state.gd")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func hooked_fixture(seed: int) -> Kernel:
	var k := Kernel.new(seed)
	if not k.rig_fishing("lure").ok or not k.cast_fishing().ok:
		return k
	k.advance_game_ms(Fishing.BITE_DELAY_MS)
	k.hook_fishing()
	return k

func last_history_detail(k: Kernel) -> String:
	if k.world.history.is_empty():
		return ""
	return String(k.world.history[-1].detail)

func _init() -> void:
	var k := hooked_fixture(86420)
	if k.world.fishing.state != "hooked":
		fail("2P: hooked fixture failed")
		return
	var ids := [k.world.fishing.rod_item_id, k.world.fishing.reel_item_id, k.world.fishing.line_item_id, k.world.fishing.terminal_item_id]
	for id in ids:
		if Inventory.tackle_condition(k.world.inventory, id) != 1000:
			fail("2P: full rig condition was not materialized")
			return

	var base_record := k.world.to_record()
	base_record.fishing.fish_cue = "pull"
	base_record.fishing.line_tension = 500
	var loose := Kernel.new(1)
	var tight := Kernel.new(1)
	if not loose.restore(base_record).ok or not tight.restore(base_record).ok:
		fail("2P: drag comparison restore failed")
		return
	var loose_result := loose.fight_fishing("pressure", "loose")
	var tight_result := tight.fight_fishing("pressure", "tight")
	if not loose_result.ok or not tight_result.ok or loose.world.fishing.state != "hooked" or tight.world.fishing.state != "hooked" or int(tight.world.fishing.line_tension) <= int(loose.world.fishing.line_tension):
		fail("2P: tight drag did not create higher line tension from the same state")
		return

	var worn := Kernel.new(2)
	if not worn.restore(base_record).ok:
		fail("2P: worn-line restore failed")
		return
	var worn_line: String = worn.world.fishing.line_item_id
	worn.world.inventory.entries[worn_line].condition = 100
	var worn_result := worn.fight_fishing("pressure", "tight")
	var worn_log := last_history_detail(worn)
	if not worn_result.ok or worn_result.status != "overload" or Inventory.tackle_condition(worn.world.inventory, worn_line) != 0:
		fail("2P: worn line strength did not cause an auditable overload")
		return
	if "tight drag" not in worn_log or "rod " not in worn_log or "reel " not in worn_log or "line 0" not in worn_log or "terminal " not in worn_log:
		fail("2P: failed fight log omitted drag or final rig condition")
		return
	var broken_snapshot := worn.world.to_record()
	if worn.rig_fishing("lure").ok or worn.world.to_record() != broken_snapshot:
		fail("2P: broken line did not reject a new rig atomically")
		return

	var weakest := Kernel.new(3)
	if not weakest.restore(base_record).ok:
		fail("2P: weakest-link restore failed")
		return
	var weak_line: String = weakest.world.fishing.line_item_id
	var weak_terminal: String = weakest.world.fishing.terminal_item_id
	weakest.world.inventory.entries[weak_line].condition = 100
	weakest.world.inventory.entries[weak_terminal].condition = 1
	var weakest_result := weakest.fight_fishing("pressure", "tight")
	if not weakest_result.ok or weakest_result.status != "tackle_failure" or Inventory.tackle_condition(weakest.world.inventory, weak_terminal) != 0 or Inventory.tackle_condition(weakest.world.inventory, weak_line) <= 0:
		fail("2P: lowest terminal limit did not own a simultaneous overload")
		return

	var rejected := Kernel.new(4)
	for id in rejected.world.inventory.entries:
		if rejected.world.inventory.entries[id].kind in Inventory.TRACKED_TACKLE:
			rejected.world.inventory.entries[id].condition = -1
	if not World.validate(rejected.world.to_record()).is_empty():
		fail("2P: legacy-sentinel fixture is invalid")
		return
	var rejected_snapshot := rejected.world.to_record()
	if rejected.rig_fishing("bait", "").ok or rejected.world.to_record() != rejected_snapshot:
		fail("2P: rejected bait rig materialized legacy tackle condition")
		return

	var normal := hooked_fixture(86421)
	var cue: String = normal.world.fishing.fish_cue
	var action := "give_line" if cue == "surge" else ("pressure" if cue == "pull" else "reel")
	var rod_id: String = normal.world.fishing.rod_item_id
	var reel_id: String = normal.world.fishing.reel_item_id
	var line_id: String = normal.world.fishing.line_item_id
	var term_id: String = normal.world.fishing.terminal_item_id
	var result := normal.fight_fishing(action, "balanced")
	if not result.ok:
		fail("2P: normal fight action failed: " + result.message)
		return
	var expected_conditions := {}
	for id in [rod_id, reel_id, line_id, term_id]:
		var condition := Inventory.tackle_condition(normal.world.inventory, id)
		if condition >= 1000:
			fail("2P: fight did not wear every linked rig component")
			return
		expected_conditions[id] = condition
	var reloaded := Kernel.new(5)
	var json_record: Dictionary = JSON.parse_string(JSON.stringify(normal.world.to_record()))
	if not reloaded.restore(json_record).ok:
		fail("2P: worn-rig save/reload failed")
		return
	for id in expected_conditions:
		if Inventory.tackle_condition(reloaded.world.inventory, id) != int(expected_conditions[id]):
			fail("2P: exact rig condition changed across save/reload")
			return

	if normal.world.fishing.state != "idle":
		normal.cancel_fishing()
	var moved := normal.move_plan("elevated_camp")
	if not moved.ok:
		fail("2P: could not reach camp")
		return
	var before := Inventory.tackle_condition(normal.world.inventory, rod_id)
	var serviced := normal.service_tackle(rod_id)
	if not serviced.ok or not normal.world.inventory.entries.has(rod_id) or Inventory.tackle_condition(normal.world.inventory, rod_id) <= before:
		fail("2P: rod service did not preserve identity and restore condition")
		return
	var replacement_old := reel_id
	var replaced := normal.replace_tackle(replacement_old)
	var replacement_new := Inventory.carried_id(normal.world.inventory, "test_reel")
	if not replaced.ok or normal.world.inventory.entries.has(replacement_old) or replacement_new == replacement_old or replacement_new.is_empty() or Inventory.tackle_condition(normal.world.inventory, replacement_new) != 1000:
		fail("2P: replacement did not create a new full-condition physical identity")
		return
	var final_reload := Kernel.new(6)
	if not final_reload.restore(JSON.parse_string(JSON.stringify(normal.world.to_record()))).ok or Inventory.carried_id(final_reload.world.inventory, "test_reel") != replacement_new:
		fail("2P: replacement identity did not persist through save/reload")
		return
	var errors := World.validate(final_reload.world.to_record())
	if not errors.is_empty():
		fail("2P: final world validation failed: " + " ".join(errors))
		return
	print("Phase 2P full-audit rig causality invariants: passed.")
	quit(0)
''')

print("Phase 2P full-audit corrections applied.")
