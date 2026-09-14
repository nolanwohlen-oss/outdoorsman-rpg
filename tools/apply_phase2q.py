from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Phase 2Q anchor count for {path}: {count}; expected 1\n{old[:180]!r}")
    p.write_text(text.replace(old, new, 1))


# World schema + migration.
replace_once(
    "simulation/world_state.gd",
    'const Fishing = preload("res://simulation/fishing.gd")\nconst SCHEMA_VERSION := 14',
    'const Fishing = preload("res://simulation/fishing.gd")\nconst Skills = preload("res://simulation/skills.gd")\nconst SCHEMA_VERSION := 15',
)
replace_once(
    "simulation/world_state.gd",
    'const LOG_KINDS := ["world_started", "observe", "move", "wait_started", "wait_finished", "wait_stopped", "scheduled", "sunrise", "sunset", "midnight", "marker", "wait_interrupt", "random_draw", "fishing_rigged", "fishing_cast", "fish_hooked", "fish_fight", "fish_lost", "fish_landed"]',
    'const LOG_KINDS := ["world_started", "observe", "move", "wait_started", "wait_finished", "wait_stopped", "scheduled", "sunrise", "sunset", "midnight", "marker", "wait_interrupt", "random_draw", "fishing_rigged", "fishing_cast", "fish_hooked", "fish_fight", "fish_lost", "fish_landed", "skill_xp"]',
)
replace_once(
    "simulation/world_state.gd",
    'var fishing: Dictionary = {}\nvar rng_state: int = 1',
    'var fishing: Dictionary = {}\nvar skills: Dictionary = {}\nvar rng_state: int = 1',
)
replace_once(
    "simulation/world_state.gd",
    '\t\t"fishing": fishing.duplicate(true),\n\t\t"random_stream": {"algorithm": "park_miller_16807_v1", "state": rng_state},',
    '\t\t"fishing": fishing.duplicate(true),\n\t\t"skills": skills.duplicate(true),\n\t\t"random_stream": {"algorithm": "park_miller_16807_v1", "state": rng_state},',
)
replace_once(
    "simulation/world_state.gd",
    '\tif version >= 6:\n\t\tkeys.append("fishing")\n',
    '\tif version >= 6:\n\t\tkeys.append("fishing")\n\tif version >= 15:\n\t\tkeys.append("skills")\n',
)
replace_once(
    "simulation/world_state.gd",
    '\tif version >= 6:\n\t\terrors.append_array(Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6, version in [7, 8, 9, 10], version == 11, version in [12, 13]))\n\tif version >= 14 and errors.is_empty():',
    '\tif version >= 6:\n\t\terrors.append_array(Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6, version in [7, 8, 9, 10], version == 11, version in [12, 13]))\n\tif version >= 15:\n\t\terrors.append_array(Skills.validate(record.skills))\n\tif version >= 14 and errors.is_empty():',
)
replace_once(
    "simulation/world_state.gd",
    '\tif is_integer(schema, 1, 13):',
    '\tif is_integer(schema, 1, 14):',
)
replace_once(
    "simulation/world_state.gd",
    '\t\tvar errors := validate(migrated)\n',
    '\t\tif int(schema) < 15:\n\t\t\tmigrated.skills = Skills.create()\n\t\tvar errors := validate(migrated)\n',
)
replace_once(
    "simulation/world_state.gd",
    '\tresult.fishing = Fishing.normalized(record.fishing)\n\tresult.rng_state = int(record.random_stream.state)',
    '\tresult.fishing = Fishing.normalized(record.fishing)\n\tresult.skills = Skills.normalized(record.skills)\n\tresult.rng_state = int(record.random_stream.state)',
)

# Kernel integration.
replace_once(
    "simulation/kernel.gd",
    'const Fishing = preload("res://simulation/fishing.gd")\nconst MINUTE_MS := 60000',
    'const Fishing = preload("res://simulation/fishing.gd")\nconst Skills = preload("res://simulation/skills.gd")\nconst MINUTE_MS := 60000',
)
replace_once(
    "simulation/kernel.gd",
    '\tworld.fishing = Fishing.create()\n\tfor kind in ["sunrise", "sunset", "midnight"]:',
    '\tworld.fishing = Fishing.create()\n\tworld.skills = Skills.create()\n\tfor kind in ["sunrise", "sunset", "midnight"]:',
)
replace_once(
    "simulation/kernel.gd",
    '''func _log(kind: String, detail: String) -> void:\n\tworld.history.append({"id": world.next_log_id, "time_ms": world.game_time_ms, "kind": kind, "detail": detail})\n\tworld.next_log_id += 1\n\tif world.history.size() > World.MAX_HISTORY:\n\t\tworld.history.pop_front()\n\nfunc _queue''',
    '''func _log(kind: String, detail: String) -> void:\n\tworld.history.append({"id": world.next_log_id, "time_ms": world.game_time_ms, "kind": kind, "detail": detail})\n\tworld.next_log_id += 1\n\tif world.history.size() > World.MAX_HISTORY:\n\t\tworld.history.pop_front()\n\nfunc _award_skill(action_id: String) -> Dictionary:\n\tvar award: Dictionary = Skills.award(world.skills, action_id)\n\tif not award.ok:\n\t\treturn award\n\tif int(award.xp_awarded) > 0:\n\t\tvar level_detail := ""\n\t\tif int(award.new_level) != int(award.old_level):\n\t\t\tlevel_detail = " · level %d→%d" % [award.old_level, award.new_level]\n\t\t_log("skill_xp", "%s +%d XP · %d cumulative%s · source %s." % [award.label, award.xp_awarded, award.cumulative_xp, level_detail, action_id])\n\treturn award\n\nfunc _queue''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tworld.fishing.state = "cast"\n\tworld.fishing.target_species = weighted_choices[posmod(world.seed + world.game_time_ms, weighted_choices.size())]\n\tworld.fishing.bite_due_ms = world.game_time_ms + Fishing.BITE_DELAY_MS\n\t_log("fishing_cast", "%s cast into %s; test bite window opens in 2 game minutes." % [world.fishing.rig_mode.capitalize(), world.player_zone])\n''',
    '''\tworld.fishing.state = "cast"\n\tworld.fishing.target_species = weighted_choices[posmod(world.seed + world.game_time_ms, weighted_choices.size())]\n\tworld.fishing.bite_due_ms = world.game_time_ms + Fishing.BITE_DELAY_MS\n\tvar rig_signature := "%s|%s|%s|%s|%s" % [world.fishing.rod_item_id, world.fishing.reel_item_id, world.fishing.line_item_id, world.fishing.terminal_item_id, world.fishing.rig_mode]\n\tif Skills.rig_signature_is_new(world.skills, rig_signature):\n\t\tSkills.remember_rig_signature(world.skills, rig_signature)\n\t\t_award_skill("fishing_rig_functional")\n\t_log("fishing_cast", "%s cast into %s; test bite window opens in 2 game minutes." % [world.fishing.rig_mode.capitalize(), world.player_zone])\n''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tFishing.start_fight(world.fishing, world.environment.water_by_zone[world.player_zone])\n\t_log("fish_hooked", "Hook set on %s; first cue: %s." % [world.fishing.target_species, world.fishing.fish_cue])\n\treturn {"ok": true, "message": "Fish hooked: %s. Read the %s cue." % [world.fishing.target_species, world.fishing.fish_cue]}\n''',
    '''\tFishing.start_fight(world.fishing, world.environment.water_by_zone[world.player_zone])\n\t_log("fish_hooked", "Hook set on %s; first cue: %s." % [world.fishing.target_species, world.fishing.fish_cue])\n\t_award_skill("fishing_cast_purposeful")\n\t_award_skill("fishing_hookset")\n\treturn {"ok": true, "message": "Fish hooked: %s. Read the %s cue." % [world.fishing.target_species, world.fishing.fish_cue]}\n''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tvar terminal_limit: int = Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar overload_limit: int = mini(line_limit, terminal_limit)\n\tvar overload_component := "terminal tackle" if terminal_limit < line_limit else "line"\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, overload_limit)\n''',
    '''\tvar terminal_limit: int = Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar overload_limit: int = mini(line_limit, terminal_limit)\n\tvar overload_component := "terminal tackle" if terminal_limit < line_limit else "line"\n\tvar cue_before := String(candidate.world.fishing.fish_cue)\n\tvar expected_action: String = {"surge": "give_line", "pull": "pressure", "slack": "reel", "tired": "reel"}.get(cue_before, "")\n\tvar correct_control := action == expected_action\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, overload_limit)\n''',
)
replace_once(
    "simulation/kernel.gd",
    '''\telse:\n\t\tvar ready := Fishing.landing_ready(candidate.world.fishing)\n\t\tvar detail := "%s / %s drag against %s; stamina %d, tension %d, distance %d cm; rod %d, reel %d, line %d, terminal %d / 1000%s." % [action.replace("_", " ").capitalize(), drag, species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.rod, wear.reel, wear.line, wear.terminal, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]\n\t\tcandidate._log("fish_fight", detail)\n\t\tresult.message = detail\n\tvar errors := World.validate(candidate.world.to_record())\n''',
    '''\telse:\n\t\tvar ready := Fishing.landing_ready(candidate.world.fishing)\n\t\tvar detail := "%s / %s drag against %s; stamina %d, tension %d, distance %d cm; rod %d, reel %d, line %d, terminal %d / 1000%s." % [action.replace("_", " ").capitalize(), drag, species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.rod, wear.reel, wear.line, wear.terminal, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]\n\t\tcandidate._log("fish_fight", detail)\n\t\tresult.message = detail\n\tif correct_control:\n\t\tcandidate._award_skill("fishing_fight_control")\n\tvar errors := World.validate(candidate.world.to_record())\n''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tFishing.clear_active(candidate.world.fishing)\n\tcandidate._log("fish_landed", candidate.world.fishing.last_outcome.capitalize() + ".")\n\tvar errors := World.validate(candidate.world.to_record())\n''',
    '''\tFishing.clear_active(candidate.world.fishing)\n\tcandidate._log("fish_landed", candidate.world.fishing.last_outcome.capitalize() + ".")\n\tcandidate._award_skill("fishing_land_ordinary")\n\tvar errors := World.validate(candidate.world.to_record())\n''',
)

# UI exposure and version metadata.
replace_once(
    "scripts/main.gd",
    'const Fishing = preload("res://simulation/fishing.gd")\nconst TEXT :=',
    'const Fishing = preload("res://simulation/fishing.gd")\nconst Skills = preload("res://simulation/skills.gd")\nconst TEXT :=',
)
replace_once(
    "scripts/main.gd",
    'var condition_label: Label\nvar inventory_label: Label',
    'var condition_label: Label\nvar skills_label: Label\nvar inventory_label: Label',
)
replace_once(
    "scripts/main.gd",
    'layout.add_child(_label("SYSTEMS LAB  /  PHASE 2P", 20, ACCENT))',
    'layout.add_child(_label("SYSTEMS LAB  /  PHASE 2Q", 20, ACCENT))',
)
replace_once(
    "scripts/main.gd",
    '''\tvar build := "v0.17.0 · local build"\n\tif FileAccess.file_exists("res://config/build_info.json"):\n\t\tvar info = JSON.parse_string(FileAccess.get_file_as_string("res://config/build_info.json"))\n\t\tif info is Dictionary:\n\t\t\tbuild = "v%s · build %s · %s" % [str(info.get("version", "0.17.0")), str(info.get("number", "local")).trim_suffix(".0"), info.get("commit", "unknown")]\n''',
    '''\tvar build := "v0.18.0 · local build"\n\tif FileAccess.file_exists("res://config/build_info.json"):\n\t\tvar info = JSON.parse_string(FileAccess.get_file_as_string("res://config/build_info.json"))\n\t\tif info is Dictionary:\n\t\t\tbuild = "v%s · build %s · %s" % [str(info.get("version", "0.18.0")), str(info.get("number", "local")).trim_suffix(".0"), info.get("commit", "unknown")]\n''',
)
replace_once(
    "scripts/main.gd",
    '''func _build_layers(column: VBoxContainer) -> void:\n\tcolumn.add_child(_label("Player condition", 28, ACCENT))\n\tcondition_label = _label("", 23)\n\tcolumn.add_child(condition_label)\n\tcolumn.add_child(_label("Inventory and camp storage", 28, ACCENT))\n''',
    '''func _build_layers(column: VBoxContainer) -> void:\n\tcolumn.add_child(_label("Player condition", 28, ACCENT))\n\tcondition_label = _label("", 23)\n\tcolumn.add_child(condition_label)\n\tcolumn.add_child(_label("Angling and Fisheries", 28, ACCENT))\n\tskills_label = _label("", 21)\n\tcolumn.add_child(skills_label)\n\tcolumn.add_child(_label("Phase 2Q awards Base XP only from completed qualifying actions. Intermediate level thresholds are provisional test interpolation between the canonical anchors. Passive inspection and elapsed time do not create skill XP.", 19, MUTED))\n\tcolumn.add_child(_label("Inventory and camp storage", 28, ACCENT))\n''',
)
replace_once(
    "scripts/main.gd",
    '\tcolumn.add_child(_label("Active prototypes: clock, travel, weather/water, population ledger, condition, fishing, physical item records, pack/cache storage and saves. These are simplified test layers.", 23))',
    '\tcolumn.add_child(_label("Active prototypes: clock, travel, weather/water, population ledger, condition, fishing, Angling XP, physical item records, pack/cache storage and saves. These are simplified test layers.", 23))',
)
replace_once(
    "scripts/main.gd",
    '''\tif condition_label != null:\n\t\tvar c: Dictionary = kernel.world.condition\n\t\tcondition_label.text = "Hydration %d/1000 · Energy %d/1000\\nExposure %d/1000 · Sleep debt %d/1000\\nHealth %d/1000 · Updated %s" % [c.hydration, c.energy, c.exposure, c.sleep_debt, c.health, Kernel.time_text(int(c.updated_at_ms))]\n\t\tinventory_label.text = "Pack %d / 15000 g\\nCamp cache %d / 50000 g\\nPack ration energy %d kcal" % [Inventory.total_weight_g(kernel.world.inventory), Inventory.total_weight_g(kernel.world.inventory, "camp"), Inventory.quantity(kernel.world.inventory, "food_kcal")]\n\t\t_refresh_inventory()\n''',
    '''\tif condition_label != null:\n\t\tvar c: Dictionary = kernel.world.condition\n\t\tcondition_label.text = "Hydration %d/1000 · Energy %d/1000\\nExposure %d/1000 · Sleep debt %d/1000\\nHealth %d/1000 · Updated %s" % [c.hydration, c.energy, c.exposure, c.sleep_debt, c.health, Kernel.time_text(int(c.updated_at_ms))]\n\t\tvar skill_lines := PackedStringArray(["Derived Angling base: L%d · internal %.2f" % [Skills.displayed_base_level(kernel.world.skills), Skills.base_average(kernel.world.skills)]])\n\t\tfor id in Skills.SUBSKILLS:\n\t\t\tvar progress: Dictionary = Skills.progress(kernel.world.skills, id)\n\t\t\tskill_lines.append("%s\\nL%d · %d XP · next %d · %d remaining" % [progress.label, progress.level, progress.xp, progress.next_xp, progress.remaining])\n\t\tskills_label.text = "\\n".join(skill_lines)\n\t\tinventory_label.text = "Pack %d / 15000 g\\nCamp cache %d / 50000 g\\nPack ration energy %d kcal" % [Inventory.total_weight_g(kernel.world.inventory), Inventory.total_weight_g(kernel.world.inventory, "camp"), Inventory.quantity(kernel.world.inventory, "food_kcal")]\n\t\t_refresh_inventory()\n''',
)

# Build and test wiring.
replace_once(
    "tools/prepare_build.py",
    'metadata.write_text(json.dumps({"number": number, "commit": commit, "version": "0.17.0", "phase": "2P"}) + "\\n")',
    'metadata.write_text(json.dumps({"number": number, "commit": commit, "version": "0.18.0", "phase": "2Q"}) + "\\n")',
)
replace_once(
    "tools/prepare_build.py",
    'text = re.sub(r\'^version/name="[^\"]*"$\', f\'version/name="0.17.0-dev.{number}"\', text, flags=re.MULTILINE)',
    'text = re.sub(r\'^version/name="[^\"]*"$\', f\'version/name="0.18.0-dev.{number}"\', text, flags=re.MULTILINE)',
)
replace_once(
    "tools/prepare_build.py",
    'print(f"Prepared Phase 2P build {number} ({commit})")',
    'print(f"Prepared Phase 2Q build {number} ({commit})")',
)
replace_once(
    "tools/check.sh",
    '''timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2p.gd 2>&1 | tee "$project_root/build/phase-2p.log"\nprobe_dir=''',
    '''timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2p.gd 2>&1 | tee "$project_root/build/phase-2p.log"\ntimeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2q.gd 2>&1 | tee "$project_root/build/phase-2q.log"\nprobe_dir=''',
)
replace_once(
    "tools/check.sh",
    '"$project_root/build/phase-2o.log" "$project_root/build/phase-2p.log" "$project_root/build/save-write.log" "$project_root/build/save-read.log"',
    '"$project_root/build/phase-2o.log" "$project_root/build/phase-2p.log" "$project_root/build/phase-2q.log" "$project_root/build/save-write.log" "$project_root/build/save-read.log"',
)

replace_once(
    "docs/IMPLEMENTATION_ORDER.md",
    '''Lettered slices 2C–2P now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, and deeper full-rig causality. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.\n\nPhase 2P adds persistent rod/reel/line/terminal condition, deterministic full-rig wear, condition-dependent load limits, explicit loose/balanced/tight drag choices, weakest-link failure ownership, auditable failed rounds, broken-tackle rejection, and camp service/replacement. Its full code audit must pass automation and its Android checklist must pass on the physical phone before Phase 2Q depends on it. The next lettered slice is intentionally not declared complete or locked in by this roadmap until that gate closes. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.\n''',
    '''Lettered slices 2C–2Q now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, deeper full-rig causality, and the first persistent Angling progression record. Each phase document records its own limits and phone gate. These are connected systems-lab fixtures, not completed versions of master phases 5–8.\n\nPhase 2Q adds versioned Angling subskills, canonical anchor-preserving cumulative XP, completion-event Base XP routing, anti-farming qualification guards, level derivation and schema-14 migration without retroactive progress. It must pass automation and its Android checklist before another system depends on it. The next proposed slice is character competence entering Action Resolution: prototype attributes plus the relevant Angling subskill feeding selected fishing resolutions without replacing player input. That future slice remains provisional until 2Q closes. Camping, survival fidelity, individual wildlife behavior, the dedicated map and 3D presentation remain later gates. Passing automation does not substitute for physical Android testing or mean the complete initial survival loop is playable.\n''',
)

# Existing regression fixtures construct old-schema records from the current world.
# Remove the new skills field before changing those fixture schema versions.
p = ROOT / "tests/run.gd"
lines = p.read_text().splitlines()
out = []
pattern = re.compile(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)\.schema_version = (?:[1-9]|1[0-4])$')
for line in lines:
    match = pattern.match(line)
    if match:
        previous = out[-1].strip() if out else ""
        erase = f'{match.group(2)}.erase("skills")'
        if previous != erase:
            out.append(f'{match.group(1)}{erase}')
    out.append(line)
p.write_text("\n".join(out) + "\n")
