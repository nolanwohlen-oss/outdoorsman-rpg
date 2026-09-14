# Phase 2P full audit — 2026-09-14

## Scope

This audit compares the merged Phase 2P implementation against the master framework, `IMPLEMENTATION_ORDER.md`, the Phase 2P phone gate, current save/migration rules, event-log auditability, inventory identity, UI exposure, automated regression coverage, CI behavior and repository hygiene.

## Findings corrected

1. **Rejected rig atomicity.** Legacy `-1` tackle condition could be materialized on the authoritative inventory before an invalid bait selection rejected the action. Rig preparation now materializes legacy condition on a private inventory copy and commits it only after every prerequisite passes.
2. **Weakest-link causality.** A round above both line/rod and terminal limits could assign the failure to line because line overload was evaluated first. The lower active load threshold now owns the overload; terminal failure is reported as tackle failure and line failure remains overload.
3. **Failure audit detail.** Successful fight rounds logged drag and all four rig conditions, but failed rounds did not. Every failed round now records action, drag, species, stamina, tension, distance and final rod/reel/line/terminal condition before the active encounter is cleared.
4. **Impossible current-save state.** Current-schema validation could accept an active fishing encounter whose linked tackle was already `0/1000`. Active rig links now reject any broken required component.
5. **Regression coverage.** The dedicated Phase 2P test now covers drag divergence from the same state, line overload, weakest-terminal ownership when both thresholds are exceeded, failed-round audit details, atomic broken-rig rejection, atomic invalid bait preparation with legacy sentinels, wear on every linked component, exact condition save/reload, identity-preserving service, identity-changing replacement, replacement persistence and corrupted active-state rejection.
6. **UI drift.** Layers still described service/replacement as line/reel-only and did not persistently show the currently selected drag beside a hooked encounter. Labels now describe full rig components and the selected drag is visible in the fight status.
7. **Roadmap drift.** `IMPLEMENTATION_ORDER.md` still described 2O as current and 2P as future work. It now records 2P as the current code gate and explicitly keeps 2Q dependent on successful 2P audit plus physical Android testing.
8. **CI source guard.** `tools/check.sh` called `rg`, which is absent from the hosted runner; because it was inside an `if`, the guard silently skipped. The guard now uses Python and is runner-independent.
9. **Repository hygiene.** Temporary source-transformer workflows and scripts used to construct Phase 2P were accidentally merged into `main`. The audit patch removes them; no write-capable temporary transformer remains in the canonical tree.
10. **Stale tackle wording.** Inventory service/replacement errors still referred only to line/reel after support expanded to rod and terminal tackle. Messages now refer to tracked rig components.

## Save/version decision

No schema bump is required. Phase 2P adds action inputs and activates semantics on the already-versioned item `condition` field; it does not add serialized fields. Legacy `-1` remains the explicit pristine compatibility sentinel and is only materialized by a successful tackle action.

## Deliberate non-findings

The deterministic wear rates, load limits and drag offsets remain systems-lab coefficients rather than final fishing physics. Line material/diameter, knot strength, rod power/action, reel drag hardware, leader construction, hook gauge, lure weight and player skill remain deferred exactly as recorded in `PHASE_2P.md`.

## Remaining external gate

Automated validation cannot substitute for the Phase 2P physical Android checklist. Phase 2Q must not depend on 2P until the corrected v0.17.0 build passes that phone test.
