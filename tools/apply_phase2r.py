from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one anchor, found {count}: {old[:90]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_count(path: str, old: str, new: str, expected: int) -> None:
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f"{path}: expected {expected} anchors, found {count}: {old[:90]!r}")
    p.write_text(text.replace(old, new))


# ---- fishing record + hook-set physics -------------------------------------------------
replace_once("simulation/fishing.gd", "const VERSION := 6", "const VERSION := 7")
replace_once(
    "simulation/fishing.gd",
    'const STRIKE_CUES := ["tap", "pull", "run"]\nconst ENGAGEMENT_THRESHOLD := 65',
    'const STRIKE_CUES := ["tap", "pull", "run"]\nconst HOOK_FORCES := ["soft", "firm", "hard"]\nconst HOOK_PLACEMENTS := ["lip", "jaw", "corner", "mouth_interior"]\nconst HOOK_RESPONSE_WINDOW_MS := 180000\nconst ENGAGEMENT_THRESHOLD := 65',
)
replace_once(
    "simulation/fishing.gd",
    '\t\t"strike_cue": "",\n\t\t"bait_item_id": "",',
    '\t\t"strike_cue": "",\n\t\t"strike_started_ms": 0,\n\t\t"hook_placement": "",\n\t\t"hook_hold": 0,\n\t\t"hook_injury": 0,\n\t\t"bait_item_id": "",',
)
replace_once(
    "simulation/fishing.gd",
    'static func validate(record: Variant, now_ms: int, legacy: bool = false, old_v1: bool = false, old_v2: bool = false, old_v3: bool = false, old_v5: bool = false) -> PackedStringArray:\n\tvar current_v6: bool = not legacy and not old_v1 and not old_v2 and not old_v3 and not old_v5',
    'static func validate(record: Variant, now_ms: int, legacy: bool = false, old_v1: bool = false, old_v2: bool = false, old_v3: bool = false, old_v5: bool = false, old_v6: bool = false) -> PackedStringArray:\n\tvar has_presentation: bool = not legacy and not old_v1 and not old_v2 and not old_v3 and not old_v5\n\tvar current_v7: bool = has_presentation and not old_v6',
)
replace_once(
    "simulation/fishing.gd",
    '\tif current_v6:\n\t\tkeys.append_array(["presentation", "strike_cue"])',
    '\tif has_presentation:\n\t\tkeys.append_array(["presentation", "strike_cue"])\n\tif current_v7:\n\t\tkeys.append_array(["strike_started_ms", "hook_placement", "hook_hold", "hook_injury"])',
)
replace_once(
    "simulation/fishing.gd",
    '\t\tnumeric_fields.append_array(["last_handling_condition", "handling_count"])\n\tfor field in numeric_fields:',
    '\t\tnumeric_fields.append_array(["last_handling_condition", "handling_count"])\n\tif current_v7:\n\t\tnumeric_fields.append_array(["strike_started_ms", "hook_hold", "hook_injury"])\n\tfor field in numeric_fields:',
)
replace_once(
    "simulation/fishing.gd",
    'var expected_version := 1 if old_v1 else (2 if old_v2 else (3 if old_v3 else (5 if old_v5 else VERSION)))',
    'var expected_version := 1 if old_v1 else (2 if old_v2 else (3 if old_v3 else (5 if old_v5 else (6 if old_v6 else VERSION))))',
)
replace_once(
    "simulation/fishing.gd",
    'if record.state == "cast" and not current_v6 and record.target_species == "":',
    'if record.state == "cast" and not has_presentation and record.target_species == "":',
)
replace_once(
    "simulation/fishing.gd",
    '\tif current_v6:\n\t\tif not record.presentation is String or not record.strike_cue is String:',
    '\tif has_presentation:\n\t\tif not record.presentation is String or not record.strike_cue is String:',
)
replace_once(
    "simulation/fishing.gd",
    '\tif record.last_outcome.length() > 512 or (not record.zone.is_empty() and record.zone not in Map.ZONE_IDS)',
    '\tif current_v7:\n\t\tif not record.hook_placement is String or int(record.strike_started_ms) > now_ms:\n\t\t\treturn PackedStringArray(["Invalid hook-set record."])\n\t\tif record.state in ["idle", "rigged"] and (int(record.strike_started_ms) != 0 or not _hook_is_clear(record)):\n\t\t\treturn PackedStringArray(["Inactive rig retains hook-set state."])\n\t\tif record.state == "cast":\n\t\t\tif record.target_species.is_empty():\n\t\t\t\tif int(record.strike_started_ms) != 0 or not _hook_is_clear(record):\n\t\t\t\t\treturn PackedStringArray(["Waiting cast retains premature hook-set state."])\n\t\t\telse:\n\t\t\t\tif not _integer(record.strike_started_ms, 1, now_ms) or not _hook_is_clear(record):\n\t\t\t\t\treturn PackedStringArray(["Detected strike lacks a valid response start time."])\n\t\tif record.state == "hooked":\n\t\t\tif not _integer(record.strike_started_ms, 1, now_ms) or record.hook_placement not in HOOK_PLACEMENTS or not _integer(record.hook_hold, 1, 1000) or not _integer(record.hook_injury, 0, 1000):\n\t\t\t\treturn PackedStringArray(["Hooked fish lacks valid placement, hold, or injury state."])\n\tif record.last_outcome.length() > 512 or (not record.zone.is_empty() and record.zone not in Map.ZONE_IDS)',
)
replace_once(
    "simulation/fishing.gd",
    'static func engagement_result(populations: Dictionary, zone: String, mode: String, presentation: String, water: Dictionary) -> Dictionary:',
    '''static func hookset_result(cue: String, force: String, elapsed_ms: int) -> Dictionary:\n\tif cue not in STRIKE_CUES or force not in HOOK_FORCES or elapsed_ms < 0:\n\t\treturn {"ok": false, "message": "Choose a valid hook-set force for an active strike."}\n\tif elapsed_ms > HOOK_RESPONSE_WINDOW_MS:\n\t\treturn {"ok": true, "status": "missed", "timing": "expired", "message": "The strike was answered too late and the fish dropped free."}\n\tvar timing := "immediate" if elapsed_ms <= 30000 else ("settled" if elapsed_ms <= 90000 else "late")\n\tvar timing_score := 0\n\tmatch cue:\n\t\t"tap":\n\t\t\ttiming_score = 3 if timing == "immediate" else (2 if timing == "settled" else 1)\n\t\t"pull":\n\t\t\ttiming_score = 2 if timing == "immediate" else (3 if timing == "settled" else 1)\n\t\t"run":\n\t\t\ttiming_score = 1 if timing == "immediate" else (3 if timing == "settled" else 2)\n\tvar force_score := {"soft": 1, "firm": 3, "hard": 2}[force]\n\tvar score: int = timing_score + int(force_score)\n\tif score <= 2:\n\t\treturn {"ok": true, "status": "missed", "timing": timing, "message": "The hook failed to establish a secure hold."}\n\tvar placement := "mouth_interior"\n\tif score >= 6:\n\t\tplacement = "corner"\n\telif score == 5:\n\t\tplacement = "jaw"\n\telif score == 4:\n\t\tplacement = "lip"\n\tvar hold := {"corner": 940, "jaw": 880, "lip": 760, "mouth_interior": 620}[placement]\n\tvar injury := {"corner": 80, "jaw": 120, "lip": 70, "mouth_interior": 180}[placement]\n\tif force == "soft":\n\t\thold -= 80\n\telif force == "hard":\n\t\thold += 20\n\t\tinjury += 300\n\t\tif timing == "immediate":\n\t\t\tinjury += 100\n\telse:\n\t\tinjury += 60\n\tif timing == "late":\n\t\tinjury += 100\n\tvar tension_delta := -80 if force == "soft" else (120 if force == "hard" else 0)\n\treturn {\n\t\t"ok": true, "status": "hooked", "timing": timing, "placement": placement,\n\t\t"hold": clampi(int(hold), 400, 980), "injury": clampi(int(injury), 0, 1000),\n\t\t"tension_delta": tension_delta,\n\t\t"message": "%s hook set established a %s hold." % [timing.capitalize(), placement.replace("_", " ")],\n\t}\n\nstatic func hook_load_limit(record: Dictionary) -> int:\n\tif record.state != "hooked":\n\t\treturn OVERLOAD_LIMIT\n\treturn clampi(550 + int(record.hook_hold) * 300 / 1000 - int(record.hook_injury) * 100 / 1000, 450, 850)\n\nstatic func hook_slack_limit(record: Dictionary) -> int:\n\tif record.state != "hooked":\n\t\treturn SLACK_LIMIT\n\treturn clampi(SLACK_LIMIT + int((1000 - int(record.hook_hold)) / 4), SLACK_LIMIT, 300)\n\nstatic func upgrade_v6(record: Dictionary, now_ms: int) -> void:\n\trecord.version = VERSION\n\trecord.strike_started_ms = 0\n\trecord.hook_placement = ""\n\trecord.hook_hold = 0\n\trecord.hook_injury = 0\n\tif record.state == "cast" and not record.target_species.is_empty():\n\t\trecord.strike_started_ms = mini(now_ms, int(record.bite_due_ms))\n\telif record.state == "hooked":\n\t\trecord.strike_started_ms = mini(now_ms, int(record.bite_due_ms))\n\t\trecord.hook_placement = "jaw"\n\t\trecord.hook_hold = 850\n\t\trecord.hook_injury = 120\n\nstatic func engagement_result(populations: Dictionary, zone: String, mode: String, presentation: String, water: Dictionary) -> Dictionary:''',
)
replace_once(
    "simulation/fishing.gd",
    'static func resolve_round(record: Dictionary, action: String, water: Dictionary, drag: String = "balanced", overload_limit: int = OVERLOAD_LIMIT) -> Dictionary:',
    'static func resolve_round(record: Dictionary, action: String, water: Dictionary, drag: String = "balanced", overload_limit: int = OVERLOAD_LIMIT, slack_limit: int = SLACK_LIMIT) -> Dictionary:',
)
replace_once(
    "simulation/fishing.gd",
    '\toverload_limit = clampi(overload_limit, 450, OVERLOAD_LIMIT)\n\tvar stamina := int(record.fish_stamina)',
    '\toverload_limit = clampi(overload_limit, 450, OVERLOAD_LIMIT)\n\tslack_limit = clampi(slack_limit, SLACK_LIMIT, 300)\n\tvar stamina := int(record.fish_stamina)',
)
replace_once("simulation/fishing.gd", "\tif tension <= SLACK_LIMIT:\n", "\tif tension <= slack_limit:\n")
replace_once("simulation/fishing.gd", "record.line_tension = clampi(tension, SLACK_LIMIT + 1, OVERLOAD_LIMIT - 1)", "record.line_tension = clampi(tension, slack_limit + 1, OVERLOAD_LIMIT - 1)")
replace_once(
    "simulation/fishing.gd",
    '\trecord.presentation = ""\n\trecord.strike_cue = ""\n\tclear_fight(record)',
    '\trecord.presentation = ""\n\trecord.strike_cue = ""\n\trecord.strike_started_ms = 0\n\trecord.hook_placement = ""\n\trecord.hook_hold = 0\n\trecord.hook_injury = 0\n\tclear_fight(record)',
)
replace_once(
    "simulation/fishing.gd",
    'static func _fight_is_clear(record: Dictionary) -> bool:',
    'static func _hook_is_clear(record: Dictionary) -> bool:\n\treturn record.hook_placement == "" and int(record.hook_hold) == 0 and int(record.hook_injury) == 0\n\nstatic func _fight_is_clear(record: Dictionary) -> bool:',
)

# ---- world schema/migration -------------------------------------------------------------
replace_once("simulation/world_state.gd", "const SCHEMA_VERSION := 15", "const SCHEMA_VERSION := 16")
replace_once(
    "simulation/world_state.gd",
    '"fishing_present", "fish_strike", "fish_hooked", "fish_fight", "fish_lost", "fish_landed"]',
    '"fishing_present", "fish_strike", "hookset_missed", "fish_hooked", "fish_fight", "fish_lost", "fish_landed"]',
)
replace_once(
    "simulation/world_state.gd",
    'Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6, version in [7, 8, 9, 10], version == 11, version in [12, 13], version == 14)',
    'Fishing.validate(record.fishing, int(record.clock.game_time_ms), version == 6, version in [7, 8, 9, 10], version == 11, version in [12, 13], version == 14, version == 15)',
)
replace_once(
    "simulation/world_state.gd",
    '\tif is_integer(schema, 14, 14):',
    '''\tif is_integer(schema, 15, 15):\n\t\tvar phase_2q_errors := _validate(record, 15)\n\t\tif not phase_2q_errors.is_empty():\n\t\t\treturn {"ok": false, "message": "Cannot migrate Phase 2Q save: " + " ".join(phase_2q_errors), "code": "invalid"}\n\t\tvar phase_2q_migrated: Dictionary = record.duplicate(true)\n\t\tphase_2q_migrated.schema_version = SCHEMA_VERSION\n\t\tFishing.upgrade_v6(phase_2q_migrated.fishing, int(phase_2q_migrated.clock.game_time_ms))\n\t\tvar phase_2q_current_errors := validate(phase_2q_migrated)\n\t\tif not phase_2q_current_errors.is_empty():\n\t\t\treturn {"ok": false, "message": "Cannot migrate Phase 2Q save: " + " ".join(phase_2q_current_errors), "code": "invalid"}\n\t\treturn {"ok": true, "record": phase_2q_migrated, "migrated": true, "message": "Phase 2Q save upgraded to timed hook-set causality at the saved game time. Clock paused. No offline time added."}\n\tif is_integer(schema, 14, 14):''',
)
replace_count("simulation/world_state.gd", "\t\tmigrated.fishing.version = Fishing.VERSION\n", "\t\tmigrated.fishing.version = 6\n", 2)
replace_count(
    "simulation/world_state.gd",
    '\t\telse:\n\t\t\tmigrated.fishing.presentation = ""\n\t\t\tmigrated.fishing.strike_cue = ""\n',
    '\t\telse:\n\t\t\tmigrated.fishing.presentation = ""\n\t\t\tmigrated.fishing.strike_cue = ""\n\t\tFishing.upgrade_v6(migrated.fishing, int(migrated.clock.game_time_ms))\n',
    2,
)

# ---- kernel action causality ------------------------------------------------------------
replace_once(
    "simulation/kernel.gd",
    '\tworld.fishing.target_species = String(engagement.species)\n\tworld.fishing.strike_cue = String(engagement.cue)\n\t_log("fish_strike",',
    '\tworld.fishing.target_species = String(engagement.species)\n\tworld.fishing.strike_cue = String(engagement.cue)\n\tworld.fishing.strike_started_ms = world.game_time_ms\n\t_log("fish_strike",',
)
old_hook = '''func hook_fishing() -> Dictionary:\n\tif world.fishing.zone != world.player_zone:\n\t\treturn _failure("Return to the encounter zone or cancel fishing.")\n\tif world.fishing.state != "cast":\n\t\treturn _failure("Nothing is waiting on the line.")\n\tif world.game_time_ms < int(world.fishing.bite_due_ms):\n\t\treturn _failure("No strike window yet; keep working the presentation.")\n\tif world.fishing.target_species.is_empty():\n\t\tvar strike := check_fishing()\n\t\tif not strike.ok or strike.get("status", "") != "strike":\n\t\t\treturn strike\n\tvar link_errors := Fishing.validate_inventory_links(world.fishing, world.inventory)\n\tif not link_errors.is_empty():\n\t\treturn _failure(link_errors[0])\n\tworld.fishing.state = "hooked"\n\tworld.fishing.last_catch_weight_g = 250 + posmod(world.seed + world.game_time_ms + world.player_zone.length() * 31, 1750)\n\tFishing.start_fight(world.fishing, world.environment.water_by_zone[world.player_zone])\n\t_log("fish_hooked", "Hook set on %s after %s presentation / %s strike; first fight cue: %s." % [world.fishing.target_species, world.fishing.presentation, world.fishing.strike_cue, world.fishing.fish_cue])\n\treturn {"ok": true, "message": "Fish hooked: %s. Read the %s fight cue." % [world.fishing.target_species, world.fishing.fish_cue]}\n'''
new_hook = '''func hook_fishing(force: String = "firm") -> Dictionary:\n\tif world.fishing.zone != world.player_zone:\n\t\treturn _failure("Return to the encounter zone or cancel fishing.")\n\tif world.fishing.state != "cast":\n\t\treturn _failure("Nothing is waiting on the line.")\n\tif force not in Fishing.HOOK_FORCES:\n\t\treturn _failure("Choose soft, firm, or hard hook-set force.")\n\tif world.game_time_ms < int(world.fishing.bite_due_ms):\n\t\treturn _failure("No strike window yet; keep working the presentation.")\n\tif world.fishing.target_species.is_empty():\n\t\tvar strike := check_fishing()\n\t\tif not strike.ok or strike.get("status", "") != "strike":\n\t\t\treturn strike\n\tif int(world.fishing.strike_started_ms) <= 0:\n\t\treturn _failure("The strike has no valid response time; cancel the encounter rather than guessing.")\n\tvar link_errors := Fishing.validate_inventory_links(world.fishing, world.inventory)\n\tif not link_errors.is_empty():\n\t\treturn _failure(link_errors[0])\n\tvar elapsed_ms := world.game_time_ms - int(world.fishing.strike_started_ms)\n\tvar set_result := Fishing.hookset_result(world.fishing.strike_cue, force, elapsed_ms)\n\tif not set_result.ok:\n\t\treturn set_result\n\tif set_result.status != "hooked":\n\t\tvar miss_detail := "%s strike answered with %s force after %.1f game seconds: %s" % [world.fishing.strike_cue.capitalize(), force, float(elapsed_ms) / 1000.0, set_result.message]\n\t\tworld.fishing.lost_count += 1\n\t\tworld.fishing.last_outcome = "Strike missed: %s" % set_result.message\n\t\tFishing.clear_active(world.fishing)\n\t\t_log("hookset_missed", miss_detail)\n\t\treturn {"ok": true, "status": "missed", "message": world.fishing.last_outcome}\n\tworld.fishing.state = "hooked"\n\tworld.fishing.last_catch_weight_g = 250 + posmod(world.seed + world.game_time_ms + world.player_zone.length() * 31, 1750)\n\tworld.fishing.hook_placement = String(set_result.placement)\n\tworld.fishing.hook_hold = int(set_result.hold)\n\tworld.fishing.hook_injury = int(set_result.injury)\n\tFishing.start_fight(world.fishing, world.environment.water_by_zone[world.player_zone])\n\tworld.fishing.line_tension = clampi(int(world.fishing.line_tension) + int(set_result.tension_delta), Fishing.SLACK_LIMIT + 1, Fishing.OVERLOAD_LIMIT - 1)\n\t_log("fish_hooked", "Hook set on %s after %s presentation / %s strike; %s timing, %s force, %s placement, hold %d/1000, injury %d/1000; first fight cue: %s." % [world.fishing.target_species, world.fishing.presentation, world.fishing.strike_cue, set_result.timing, force, String(set_result.placement).replace("_", " "), world.fishing.hook_hold, world.fishing.hook_injury, world.fishing.fish_cue])\n\treturn {"ok": true, "status": "hooked", "message": "Fish hooked: %s. %s placement · hold %d/1000 · injury %d/1000." % [world.fishing.target_species, String(world.fishing.hook_placement).replace("_", " ").capitalize(), world.fishing.hook_hold, world.fishing.hook_injury]}\n'''
replace_once("simulation/kernel.gd", old_hook, new_hook)
replace_once(
    "simulation/kernel.gd",
    '''\tvar terminal_limit: int = Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar overload_limit: int = mini(line_limit, terminal_limit)\n\tvar overload_component := "terminal tackle" if terminal_limit < line_limit else "line"\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, overload_limit)''',
    '''\tvar terminal_limit: int = Inventory.terminal_load_limit(candidate.world.inventory, terminal_id)\n\tvar hook_limit: int = Fishing.hook_load_limit(candidate.world.fishing)\n\tvar hook_slack_limit: int = Fishing.hook_slack_limit(candidate.world.fishing)\n\tvar overload_limit: int = line_limit\n\tvar overload_component := "line"\n\tif terminal_limit < overload_limit:\n\t\toverload_limit = terminal_limit\n\t\toverload_component = "terminal tackle"\n\tif hook_limit < overload_limit:\n\t\toverload_limit = hook_limit\n\t\toverload_component = "hook hold"\n\tvar result := Fishing.resolve_round(candidate.world.fishing, action, water, drag, overload_limit, hook_slack_limit)''',
)
replace_once(
    "simulation/kernel.gd",
    '''\telif result.status == "overload":\n\t\tif overload_terminal:\n\t\t\tresult.status = "tackle_failure"\n\t\tresult.message = "The %s failed under excessive load; the fish escaped." % overload_component\n\tvar species: String = candidate.world.fishing.target_species''',
    '''\telif result.status == "overload":\n\t\tif overload_terminal:\n\t\t\tresult.status = "tackle_failure"\n\t\t\tresult.message = "The terminal tackle failed under excessive load; the fish escaped."\n\t\telif overload_component == "hook hold":\n\t\t\tresult.status = "hook_pull"\n\t\t\tresult.message = "The %s hook hold tore free under load; the fish escaped." % String(candidate.world.fishing.hook_placement).replace("_", " ")\n\t\telse:\n\t\t\tresult.message = "The line failed under excessive load; the fish escaped."\n\tif result.status == "slack" and int(candidate.world.fishing.line_tension) > Fishing.SLACK_LIMIT:\n\t\tresult.status = "hook_pull"\n\t\tresult.message = "The %s hook hold pulled free as tension fell; the fish escaped." % String(candidate.world.fishing.hook_placement).replace("_", " ")\n\tvar species: String = candidate.world.fishing.target_species''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tif result.status != "continue":\n\t\tvar failure_detail := "%s / %s drag against %s failed (%s); stamina %d, tension %d, distance %d cm; rod %d, reel %d, line %d, terminal %d / 1000." % [action.replace("_", " ").capitalize(), drag, species, result.message, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.rod, wear.reel, wear.line, wear.terminal]''',
    '''\tif result.status != "continue":\n\t\tvar failure_detail := "%s / %s drag against %s failed (%s); stamina %d, tension %d, distance %d cm; hook %s hold %d injury %d; rod %d, reel %d, line %d, terminal %d / 1000." % [action.replace("_", " ").capitalize(), drag, species, result.message, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, String(candidate.world.fishing.hook_placement).replace("_", " "), candidate.world.fishing.hook_hold, candidate.world.fishing.hook_injury, wear.rod, wear.reel, wear.line, wear.terminal]''',
)
replace_once(
    "simulation/kernel.gd",
    '''\t\tvar detail := "%s / %s drag against %s; stamina %d, tension %d, distance %d cm; rod %d, reel %d, line %d, terminal %d / 1000%s." % [action.replace("_", " ").capitalize(), drag, species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, wear.rod, wear.reel, wear.line, wear.terminal, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]''',
    '''\t\tvar detail := "%s / %s drag against %s; stamina %d, tension %d, distance %d cm; hook %s hold %d injury %d; rod %d, reel %d, line %d, terminal %d / 1000%s." % [action.replace("_", " ").capitalize(), drag, species, candidate.world.fishing.fish_stamina, candidate.world.fishing.line_tension, candidate.world.fishing.fish_distance_cm, String(candidate.world.fishing.hook_placement).replace("_", " "), candidate.world.fishing.hook_hold, candidate.world.fishing.hook_injury, wear.rod, wear.reel, wear.line, wear.terminal, "; ready to land" if ready else "; next cue " + candidate.world.fishing.fish_cue]''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tvar weight: int = int(candidate.world.fishing.last_catch_weight_g)\n\tvar handling_condition := int(profile.retain_condition if retain else profile.release_condition)''',
    '''\tvar weight: int = int(candidate.world.fishing.last_catch_weight_g)\n\tvar hook_placement: String = candidate.world.fishing.hook_placement\n\tvar hook_injury: int = int(candidate.world.fishing.hook_injury)\n\tvar base_handling_condition := int(profile.retain_condition if retain else profile.release_condition)\n\tvar injury_penalty := int(hook_injury / (4 if retain else 2))\n\tvar handling_condition := maxi(0, base_handling_condition - injury_penalty)''',
)
replace_once(
    "simulation/kernel.gd",
    '''\tcandidate.world.fishing.last_outcome = ("retained " if retain else "released ") + "%s (%dg, %s handling, condition %d/1000)" % [species, weight, method, handling_condition]''',
    '''\tcandidate.world.fishing.last_outcome = ("retained " if retain else "released ") + "%s (%dg, %s handling, condition %d/1000; hook %s, injury %d/1000)" % [species, weight, method, handling_condition, hook_placement.replace("_", " "), hook_injury]''',
)

# ---- Android systems-lab UI -------------------------------------------------------------
replace_once("scripts/main.gd", 'SYSTEMS LAB  /  PHASE 2Q', 'SYSTEMS LAB  /  PHASE 2R')
replace_count("scripts/main.gd", '0.18.0', '0.19.0', 2)
replace_once(
    "scripts/main.gd",
    '\t_button(column, "Read presentation / check strike", _fish_check)\n\t_button(column, "Set hook", _fish_hook)\n',
    '\t_button(column, "Read presentation / check strike", _fish_check)\n\tcolumn.add_child(_label("Hook timing uses actual Game Clock age after the strike cue. Tap favors an immediate response; pull/run generally favor a short load. Choose force explicitly.", 19, MUTED))\n\trow = _row(column)\n\t_button(row, "Soft set", _fish_hook.bind("soft"))\n\t_button(row, "Firm set", _fish_hook.bind("firm"))\n\t_button(row, "Hard set", _fish_hook.bind("hard"))\n',
)
replace_once(
    "scripts/main.gd",
    '''\t\tif f.state == "hooked":\n\t\t\tfishing_status.text = "HOOKED: %s · %d g\\nPresentation: %s · Strike: %s\\nFight cue: %s · Selected drag: %s\\nFish stamina: %d · Line tension: %d / 1000\\nDistance: %.1f m · Fight choices: %d\\n%s\\nRetained %d · Released %d · Lost %d\\nLast handling: %s · condition %d/1000" % [String(f.target_species).replace("_", " ").capitalize(), f.last_catch_weight_g, String(f.presentation).capitalize(), String(f.strike_cue).to_upper(), String(f.fish_cue).to_upper(), selected_drag.capitalize(), f.fish_stamina, f.line_tension, float(f.fish_distance_cm) / 100.0, f.fight_round, "READY TO LAND" if ready else "Keep fighting", f.retained_count, f.released_count, f.lost_count, f.last_handling_method if not f.last_handling_method.is_empty() else "none", f.last_handling_condition]''',
    '''\t\tif f.state == "hooked":\n\t\t\tfishing_status.text = "HOOKED: %s · %d g\\nPresentation: %s · Strike: %s\\nHook: %s · hold %d/1000 · injury %d/1000\\nFight cue: %s · Selected drag: %s\\nFish stamina: %d · Line tension: %d / 1000\\nDistance: %.1f m · Fight choices: %d\\n%s\\nRetained %d · Released %d · Lost %d\\nLast handling: %s · condition %d/1000" % [String(f.target_species).replace("_", " ").capitalize(), f.last_catch_weight_g, String(f.presentation).capitalize(), String(f.strike_cue).to_upper(), String(f.hook_placement).replace("_", " ").capitalize(), f.hook_hold, f.hook_injury, String(f.fish_cue).to_upper(), selected_drag.capitalize(), f.fish_stamina, f.line_tension, float(f.fish_distance_cm) / 100.0, f.fight_round, "READY TO LAND" if ready else "Keep fighting", f.retained_count, f.released_count, f.lost_count, f.last_handling_method if not f.last_handling_method.is_empty() else "none", f.last_handling_condition]''',
)
replace_once(
    "scripts/main.gd",
    '''\t\t\tvar strike_text := (String(f.strike_cue).to_upper() + " cue") if f.state == "cast" and not f.strike_cue.is_empty() else ("waiting" if f.state == "cast" else "none")\n\t\t\tfishing_status.text = "State: %s · Rig: %s\\nPresentation: %s · Strike: %s\\nSpecies: unknown until hooked\\nNext check: %s\\nRetained %d · Released %d · Lost %d" % [f.state, f.rig_mode, presentation_text, strike_text, Kernel.time_text(int(f.bite_due_ms)) if f.state == "cast" else "not waiting", f.retained_count, f.released_count, f.lost_count]''',
    '''\t\t\tvar strike_text := (String(f.strike_cue).to_upper() + " cue") if f.state == "cast" and not f.strike_cue.is_empty() else ("waiting" if f.state == "cast" else "none")\n\t\t\tvar response_text := "not active"\n\t\t\tif f.state == "cast" and int(f.strike_started_ms) > 0:\n\t\t\t\tresponse_text = "%.1f game sec" % (float(kernel.world.game_time_ms - int(f.strike_started_ms)) / 1000.0)\n\t\t\tfishing_status.text = "State: %s · Rig: %s\\nPresentation: %s · Strike: %s\\nHook response age: %s\\nSpecies: unknown until hooked\\nNext check: %s\\nRetained %d · Released %d · Lost %d" % [f.state, f.rig_mode, presentation_text, strike_text, response_text, Kernel.time_text(int(f.bite_due_ms)) if f.state == "cast" else "not waiting", f.retained_count, f.released_count, f.lost_count]''',
)
replace_once(
    "scripts/main.gd",
    'func _fish_hook() -> void:\n\tif _can_act():\n\t\t_after_action(kernel.hook_fishing())',
    'func _fish_hook(force: String = "firm") -> void:\n\tif _can_act():\n\t\t_after_action(kernel.hook_fishing(force))',
)

# ---- build/test metadata + roadmap ------------------------------------------------------
replace_once("tools/prepare_build.py", '"version": "0.18.0", "phase": "2Q"', '"version": "0.19.0", "phase": "2R"')
replace_once("tools/prepare_build.py", 'version/name="0.18.0-dev.{number}"', 'version/name="0.19.0-dev.{number}"')
replace_once("tools/prepare_build.py", 'Prepared Phase 2Q build', 'Prepared Phase 2R build')
replace_once(
    "tools/check.sh",
    'timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2q.gd 2>&1 | tee "$project_root/build/phase-2q.log"\n',
    'timeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2q.gd 2>&1 | tee "$project_root/build/phase-2q.log"\ntimeout 30 "$godot_bin" --headless --path "$project_root" --script tests/phase_2r.gd 2>&1 | tee "$project_root/build/phase-2r.log"\n',
)
replace_once(
    "tools/check.sh",
    '"$project_root/build/phase-2q.log" "$project_root/build/save-write.log"',
    '"$project_root/build/phase-2q.log" "$project_root/build/phase-2r.log" "$project_root/build/save-write.log"',
)
replace_once(
    "docs/IMPLEMENTATION_ORDER.md",
    'Lettered slices 2C–2Q now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, deeper full-rig causality, and the first causal presentation/strike layer.',
    'Lettered slices 2C–2R now cover deterministic environmental records, five-species population accounting, coarse player condition, the fishing state machine, physical item identity and storage, explicit fish processing, persistent tackle links, the timed fish-fight/landing loop, explicit landing/post-catch condition, deeper full-rig causality, causal presentation/strike state, and timed hook-set causality.',
)
replace_once(
    "docs/IMPLEMENTATION_ORDER.md",
    'Phase 2Q removes species selection from casting and makes engagement depend on actual local ecology, water, rig mode and a persisted presentation choice. A strike cue may become observable after the test delay while species identity stays hidden until the hook is set; no-fish water can now accept a cast and correctly produce no strike. Schema 15 migrates Phase 2P saves without advancing closed-game time. Phase 2Q must pass automation and its physical Android checklist before Phase 2R depends on it. The next proposed fishing slice is strike-response/hook-set causality: timing/force and hook placement feeding retention, injury and the existing fight state.',
    'Phase 2R turns an observable Phase 2Q strike into a timed physical response: the Game Clock records strike age, soft/firm/hard force resolves deterministic hook placement, hold and injury, and that hook state becomes a third causal connection during the existing fight. Weak holds can pull free before intact tackle, and hook injury reduces post-landing condition. Schema 16 migrates Phase 2Q saves without advancing closed-game time and preserves active fights with neutral legacy hook state. Phase 2R must pass automation and its physical Android checklist before the next lettered slice depends on it. The next proposed slice is the Angling skill/XP foundation so trained competence can begin consuming these now-causal fishing actions without replacing player execution.',
)

# Historical tests construct legacy records from the current record. Strip fields that
# did not exist in fishing v1-v6 so strict production migration stays honest.
for test_path in (ROOT / "tests").glob("*.gd"):
    text = test_path.read_text()
    pattern = re.compile(r'^(\t*)([A-Za-z_][A-Za-z0-9_]*)\.fishing\.version = ([1-6])$', re.MULTILINE)
    def add_erasures(match: re.Match) -> str:
        indent, var, ver = match.groups()
        suffix = "".join(f'\n{indent}{var}.fishing.erase("{field}")' for field in ["strike_started_ms", "hook_placement", "hook_hold", "hook_injury"])
        return match.group(0) + suffix
    updated = pattern.sub(add_erasures, text)
    test_path.write_text(updated)

print("Phase 2R source transformation applied.")
