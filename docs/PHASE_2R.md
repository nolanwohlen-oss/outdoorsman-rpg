# Phase 2R — strike response and hook-set causality

Development v0.19.0. World schema 16 / fishing record v7. This slice turns the Phase 2Q strike cue into a timed, force-dependent hookup rather than an automatic transition into the fight state.

## Delivered

- A detected strike now records the exact Game Clock time at which the observable cue became available.
- Hook setting accepts explicit **soft**, **firm**, or **hard** force. Timing is not a menu grade: it is the actual elapsed Game Clock time between strike detection and the player setting the hook.
- Strike cue, response delay, and force deterministically resolve hookup quality. `tap`, `pull`, and `run` cues favor different response timing; very late responses can miss the fish entirely.
- Successful sets create explicit hook placement, hold strength, and tissue-injury state. The systems-lab placements are lip, jaw, corner, and mouth interior.
- Hook placement is now part of the active fight. Weak holds raise the effective slack-loss threshold and can become the weakest overload link before line or terminal tackle.
- Hook injury carries into landing/handling condition. A fish with greater hook injury retains a lower post-landing condition, especially on release.
- Missed hook sets close the encounter without revealing the internally engaged species. Successful hook sets reveal species as before.
- Mid-fight hook placement/hold/injury survives save/reload exactly.
- Phase 2Q schema-15 saves migrate to schema 16 at their saved Game Clock time. Existing hooked encounters receive deterministic neutral legacy hook state so an in-progress fight is preserved rather than discarded.
- Android exposes hook-force controls, strike response age, and active hook placement/hold/injury for lab verification.

## Systems-lab coefficients

The response windows, placement table, hold values, injury values, dynamic slack threshold and hook-load limit are deterministic prototype coefficients. They prove causal ownership and persistence only. They are not final fish-anatomy, hook-pattern, rod-action, line-stretch, drag, or player-skill tuning.

## Validation gate

The dedicated Phase 2R suite must pass alongside every historical simulation/persistence test, signed Android export, Linux launch and preview capture before merge. A green automated build still does not replace the physical Android checklist below.

## Android phone gate

1. Update-install the newest APK and confirm `v0.19.0` / `PHASE 2R`. Load the Phase 2Q save and confirm no closed-app Game Clock time was added.
2. Create a strike and pause immediately. Confirm the status shows the strike cue and a response age while species remains unknown.
3. Save at the strike, reload, and confirm the strike time/cue are unchanged. Set the hook with **Firm** force and confirm species is revealed plus placement, hold and injury appear.
4. Reload the same pre-hook save and use **Hard** force. Confirm the deterministic hook outcome differs and injury is not lower than the Firm result.
5. Reload the pre-hook save again, run the clock past the supported response window, then set the hook. Confirm the encounter is missed/closed and the lost-fish feedback does not reveal the species.
6. On a successfully hooked fish, save/reload and confirm placement, hold and injury persist exactly through the active fight.
7. Continue a weak-hook fixture or naturally weak placement until the hook becomes the limiting connection. Confirm the loss is reported as hook pull/tissue failure without falsely zeroing intact line or terminal tackle.
8. Land/release a fish with visible hook injury and confirm the final handling condition reflects that injury in addition to the selected landing method.

## Deliberate limits

Phase 2R does not yet model hook pattern/gauge/barb, circle-hook self-setting, bait theft, exact direction/rod-angle input, line stretch, anatomical geometry, bleeding, delayed mortality, legal foul-hook rules, player Angling skill, or full Action Resolution. Those remain later gates. Strike timing and force are direct systems-lab controls, not the final first-person input model.
