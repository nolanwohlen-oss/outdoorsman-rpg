from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def edit(path: str, replacements: list[tuple[str, str]]) -> None:
    p = ROOT / path
    text = p.read_text()
    for old, new in replacements:
        if old not in text:
            raise SystemExit(f"Phase 2P patch anchor missing in {path}: {old[:80]!r}")
        if text.count(old) != 1:
            raise SystemExit(f"Phase 2P patch anchor is not unique in {path}: {old[:80]!r}")
        text = text.replace(old, new, 1)
    p.write_text(text)

edit("simulation/inventory.gd", [
    ('const TRACKED_TACKLE := ["test_reel", "test_line"]', 'const TRACKED_TACKLE := ["test_rod", "test_spoon", "test_hook", "test_reel", "test_line"]'),
    ('_insert(record, kind, 1, container, "", 0, "", 1000 if kind in TRACKED_TACKLE else -1)', '_insert(record, kind, 1, container, "", 0, "", 1000 if kind in TRACKED_TACKLE else -1)'),
    ('static func apply_tackle_wear(record: Dictionary, line_id: String, reel_id: String, line_wear: int, reel_wear: int, break_line: bool = false) -> Dictionary:\n', '''static func line_load_limit(record: Dictionary, id: String) -> int:\n\tvar condition := tackle_condition(record, id)\n\tif condition < 0:\n\t\treturn 0\n\treturn 550 + int(condition * 350 / 1000)\n\nstatic func terminal_load_limit(record: Dictionary, id: String) -> int:\n\tvar condition := tackle_condition(record, id)\n\tif condition < 0:\n\t\treturn 0\n\treturn 500 + int(condition * 300 / 1000)\n\nstatic func apply_tackle_wear(record: Dictionary, line_id: String, reel_id: String, line_wear: int, reel_wear: int, break_line: bool = false) -> Dictionary:\n'''),
    ('static func service_tackle(record: Dictionary, id: String) -> Dictionary:\n', '''static func apply_rig_wear(record: Dictionary, rod_id: String, reel_id: String, line_id: String, terminal_id: String, rod_wear: int, reel_wear: int, line_wear: int, terminal_wear: int, break_line: bool = false, break_terminal: bool = false) -> Dictionary:\n\tfor id in [rod_id, reel_id, line_id, terminal_id]:\n\t\tvar init := initialize_tackle(record, id)\n\t\tif not init.ok:\n\t\t\treturn {"ok": false, "message": "Linked rig condition cannot be updated."}\n\tif mini(mini(rod_wear, reel_wear), mini(line_wear, terminal_wear)) < 0:\n\t\treturn {"ok": false, "message": "Rig wear cannot be negative."}\n\tvar rod: Dictionary = record.entries[rod_id]\n\tvar reel: Dictionary = record.entries[reel_id]\n\tvar line: Dictionary = record.entries[line_id]\n\tvar terminal: Dictionary = record.entries[terminal_id]\n\trod.condition = maxi(0, int(rod.condition) - rod_wear)\n\treel.condition = maxi(0, int(reel.condition) - reel_wear)\n\tline.condition = 0 if break_line else maxi(0, int(line.condition) - line_wear)\n\tterminal.condition = 0 if break_terminal else maxi(0, int(terminal.condition) - terminal_wear)\n\tvar broken := ""\n\tfor pair in [["line", line], ["terminal tackle", terminal], ["rod", rod], ["reel", reel]]:\n\t\tif int(pair[1].condition) == 0:\n\t\t\tbroken = String(pair[0])\n\t\t\tbreak\n\treturn {"ok": true, "rod": int(rod.condition), "reel": int(reel.condition), "line": int(line.condition), "terminal": int(terminal.condition), "broken": broken}\n\nstatic func service_tackle(record: Dictionary, id: String) -> Dictionary:\n'''),
    ('\tvar restored := 300 if entry.kind == "test_line" else 250\n\tvar minutes := 15 if entry.kind == "test_line" else 20\n', '''\tvar service := {\n\t\t"test_line": [300, 15],\n\t\t"test_reel": [250, 20],\n\t\t"test_rod": [200, 25],\n\t\t"test_spoon": [350, 10],\n\t\t"test_hook": [350, 10],\n\t}.get(entry.kind, [0, 0])\n\tvar restored := int(service[0])\n\tvar minutes := int(service[1])\n'''),
])

edit("simulation/fishing.gd", [
    ('const FIGHT_ACTIONS := ["give_line", "pressure", "reel"]\n', 'const FIGHT_ACTIONS := ["give_line", "pressure", "reel"]\nconst DRAG_SETTINGS := ["loose", "balanced", "tight"]\n'),
    ('static func resolve_round(record: Dictionary, action: String, water: Dictionary) -> Dictionary:\n\tif record.state != "hooked" or action not in FIGHT_ACTIONS:\n\t\treturn {"ok": false, "message": "Choose a valid action for a hooked fish."}\n', '''static func resolve_round(record: Dictionary, action: String, water: Dictionary, drag: String = "balanced", overload_limit: int = OVERLOAD_LIMIT) -> Dictionary:\n\tif record.state != "hooked" or action not in FIGHT_ACTIONS or drag not in DRAG_SETTINGS:\n\t\treturn {"ok": false, "message": "Choose a valid action and drag setting for a hooked fish."}\n\toverload_limit = clampi(overload_limit, 450, OVERLOAD_LIMIT)\n'''),
    ('\trecord.fish_stamina = maxi(1, stamina)\n\trecord.line_tension = tension\n\trecord.fish_distance_cm = maxi(1, distance)\n', '''\tmatch drag:\n\t\t"loose":\n\t\t\ttension -= 120\n\t\t\tdistance += 80\n\t\t\tstamina += 35\n\t\t"tight":\n\t\t\ttension += 120\n\t\t\tdistance -= 80\n\t\t\tstamina -= 35\n\trecord.fish_stamina = maxi(1, stamina)\n\trecord.line_tension = tension\n\trecord.fish_distance_cm = maxi(1, distance)\n'''),
    ('\tif tension >= OVERLOAD_LIMIT:\n', '\tif tension >= overload_limit:\n'),
])

edit("simulation/kernel.gd", [
    ('\tInventory.initialize_tackle(world.inventory, line_id)\n\tInventory.initialize_tackle(world.inventory, reel_id)\n\tif Inventory.tackle_condition(world.inventory, line_id) <= 0 or Inventory.tackle_condition(world.inventory, reel_id) <= 0:\n\t\treturn _failure("Service or replace broken line/reel at camp before rigging.")\n', '''\tfor id in [rod_id, reel_id, line_id, terminal_id]:\n\t\tInventory.initialize_tackle(world.inventory, id)\n\t\tif Inventory.tackle_condition(world.inventory, id) <= 0:\n\t\t\treturn _failure("Service or replace broken rig equipment at camp before rigging.")\n'''),
    ('func fight_fishing(action: String) -> Dictionary:\n', 'func fight_fishing(action: String, drag: String = "balanced") -> Dictionary:\n'),
    ('\tif action not in Fishing.FIGHT_ACTIONS:\n\t\treturn _failure("Choose give line, hold pressure, or reel in.")\n', '''\tif action not in Fishing.FIGHT_ACTIONS:\n\t\treturn _failure("Choose give line, hold pressure, or reel in.")\n\tif drag not in Fishing.DRAG_SETTINGS:\n\t\treturn _failure("Choose loose, balanced, or tight drag.")\n'''),
    ('\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water)\n\tif not result.ok:\n\t\treturn result\n\tvar line_id: String = candidate.world.fishing.line_item_id\n\tvar reel_id: String = candidate.world.fishing.reel_item_id\n\tvar power_load := clampi(int(Fishing.fight_power(candidate.world.fishing, water) / 250), 0, 8)\n\tvar line_wear := 6 + clampi(int(abs(int(candidate.world.fishing.line_tension) - 500) / 50), 0, 12) + power_load\n\tvar reel_wear := 3 + power_load + (8 if action == "reel" else (4 if action == "pressure" else 2))\n\tvar wear := Inventory.apply_tackle_wear(candidate.world.inventory, line_id, reel_id, line_wear, reel_wear, result.status == "overload")\n', '''\tvar rod_id: String = candidate.world.fishing.rod_item_id\n\tvar reel_id: String = candidate.world.fishing.reel_item_id\n\tvar line_id: String = candidate.world.fishing.line_item_id\n\tvar terminal_id: String = candidate.world.fishing.terminal_item_id\n\tvar rod_condition := Inventory.tackle_condition(candidate.world.inventory, rod_id)\n\tvar line_limit := Inventory.line_load_limit(candidate.world.inventory, line_id) - int((1000 - rod_condition) / 4)\n\tline_limit = clampi(line_limit, 450, Fishing.OVERLOAD_LIMIT)\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, line_limit)\n\tif not result.ok:\n\t\treturn result\n\tvar power_load := clampi(int(Fishing.fight_power(candidate.world.fishing, water) / 250), 0, 8)\n\tvar tension_load := clampi(int(abs(int(candidate.world.fishing.line_tension) - 500) / 50), 0, 12)\n\tvar line_wear := 6 + tension_load + power_load\n\tvar reel_wear := 3 + power_load + (8 if action == "reel" else (4 if action == "pressure" else 2))\n\tvar rod_wear := 2 + power_load + (5 if action == "pressure" else 2)\n\tvar terminal_wear := 2 + power_load + tension_load\n\tvar terminal_limit := Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar terminal_break := result.status == "continue" and int(candidate.world.fishing.line_tension) >= terminal_limit\n\tvar wear := Inventory.apply_rig_wear(candidate.world.inventory, rod_id, reel_id, line_id, terminal_id, rod_wear, reel_wear, line_wear, terminal_wear, result.status == "overload", terminal_break)\n'''),
    ('\t\tvar detail := "%s against %s; stamina %d, tension %d, distance %d cm; line %d/1000, reel %d/1000%s." % [action.replace("_", " ").capitalize(), species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.line, wear.reel, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]\n', '''\t\tvar detail := "%s / %s drag against %s; stamina %d, tension %d, distance %d cm; rod %d, reel %d, line %d, terminal %d / 1000%s." % [action.replace("_", " ").capitalize(), drag, species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.rod, wear.reel, wear.line, wear.terminal, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]\n'''),
])

edit("scripts/main.gd", [
    ('var land_buttons: Array[Button] = []\n', 'var land_buttons: Array[Button] = []\nvar selected_drag := "balanced"\n'),
    ('layout.add_child(_label("SYSTEMS LAB  /  PHASE 2O", 20, ACCENT))', 'layout.add_child(_label("SYSTEMS LAB  /  PHASE 2P", 20, ACCENT))'),
    ('\tvar build := "v0.16.0 · local build"\n', '\tvar build := "v0.17.0 · local build"\n'),
    ('str(info.get("version", "0.16.0"))', 'str(info.get("version", "0.17.0"))'),
    ('\tcolumn.add_child(_label("Fight cue test: surge → give line; pull → hold pressure; slack or tired → reel in. Each choice costs 30 game seconds. Exact values below are lab diagnostics, not the final HUD.", 19, MUTED))\n', '''\tcolumn.add_child(_label("Drag now changes tension and fish progress. Loose protects tackle but gives distance; tight gains control at higher break risk.", 19, MUTED))\n\trow = _row(column)\n\t_button(row, "Loose drag", _set_drag.bind("loose"))\n\t_button(row, "Balanced", _set_drag.bind("balanced"))\n\t_button(row, "Tight drag", _set_drag.bind("tight"))\n\tcolumn.add_child(_label("Fight cue test: surge → give line; pull → hold pressure; slack or tired → reel in. Each choice costs 30 game seconds. Exact values below are lab diagnostics, not the final HUD.", 19, MUTED))\n'''),
    ('func _fish_fight(action: String) -> void:\n\tif _can_act():\n\t\t_after_action(kernel.fight_fishing(action))\n', '''func _set_drag(value: String) -> void:\n\tif value in Fishing.DRAG_SETTINGS:\n\t\tselected_drag = value\n\t\t_status("Drag set to %s for the next fight choice." % value)\n\nfunc _fish_fight(action: String) -> void:\n\tif _can_act():\n\t\t_after_action(kernel.fight_fishing(action, selected_drag))\n'''),
])

edit("tools/prepare_build.py", [
    ('{"number": number, "commit": commit, "version": "0.16.0", "phase": "2O"}', '{"number": number, "commit": commit, "version": "0.17.0", "phase": "2P"}'),
    ('version/name="0.16.0-dev.{number}"', 'version/name="0.17.0-dev.{number}"'),
    ('Prepared Phase 2O build', 'Prepared Phase 2P build'),
])

edit("project.godot", [
    ('config/version="0.15.0"', 'config/version="0.17.0"'),
])

edit("tools/check.sh", [
    ('timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2o.gd 2>&1 | tee "$project_root/build/phase-2o.log"\n', 'timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2o.gd 2>&1 | tee "$project_root/build/phase-2o.log"\ntimeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2p.gd 2>&1 | tee "$project_root/build/phase-2p.log"\n'),
    ('"$project_root/build/phase-2o.log" "$project_root/build/save-write.log"', '"$project_root/build/phase-2o.log" "$project_root/build/phase-2p.log" "$project_root/build/save-write.log"'),
])

print("Phase 2P source transformation applied.")
