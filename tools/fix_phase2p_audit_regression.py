from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = root / "tests/run.gd"
text = p.read_text()
old = '''\tvar overload_result := overload.fight_fishing("pressure")\n\tcheck(overload_result.ok and overload_result.status == "overload" and overload.world.game_time_ms == start + Fishing.FIGHT_ACTION_MS and overload.world.fishing.state == "idle" and overload.world.fishing.lost_count == 1 and "excessive line tension" in overload.world.fishing.last_outcome, "Pressuring into a surge causes a timed, explicit overload loss.")\n\tcheck(int(overload.world.ecology.populations[overload_species][overload.world.player_zone]) == overload_population, "An overload loss leaves the hooked fish in the ecology population.")\n\tcheck(not overload.rig_fishing().ok, "An overload line break requires explicit tackle recovery before a new rig.")\n'''
new = '''\tvar overload_result := overload.fight_fishing("pressure")\n\tcheck(overload_result.ok and overload_result.status == "tackle_failure" and overload.world.game_time_ms == start + Fishing.FIGHT_ACTION_MS and overload.world.fishing.state == "idle" and overload.world.fishing.lost_count == 1 and "terminal tackle failed under excessive load" in overload.world.fishing.last_outcome, "Pressuring into a surge causes a timed, explicit weakest-link tackle loss.")\n\tcheck(int(overload.world.ecology.populations[overload_species][overload.world.player_zone]) == overload_population, "A weakest-link tackle loss leaves the hooked fish in the ecology population.")\n\tcheck(not overload.rig_fishing().ok, "A weakest-link terminal break requires explicit tackle recovery before a new rig.")\n'''
if text.count(old) != 1:
    raise SystemExit(f"Phase 2M overload regression anchor count {text.count(old)}; expected 1")
p.write_text(text.replace(old, new, 1))

p = root / "docs/PHASE_2P_AUDIT.md"
text = p.read_text()
old = "2. **Weakest-link causality.** A round above both line/rod and terminal limits could assign the failure to line because line overload was evaluated first. The lower active load threshold now owns the overload; terminal failure is reported as tackle failure and line failure remains overload.\n"
new = old.rstrip("\n") + " The historical Phase 2M surge regression was updated accordingly: with pristine test gear, terminal tackle is the lower threshold, while the dedicated worn-line case separately proves line overload.\n"
if text.count(old) != 1:
    raise SystemExit("Phase 2P audit weakest-link documentation anchor missing")
p.write_text(text.replace(old, new, 1))
print("Causal historical regression updated.")
