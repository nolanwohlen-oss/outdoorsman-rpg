# Phase 2Q — Angling skill and XP foundation

Development v0.18.0. Phase 2Q introduces the first persistent player-skill record and routes existing fishing completion events into the canonical Angling and Fisheries subskills from Master Skill Sheet v12.

## Delivered

- World schema 15 adds a versioned `skills` record. XP is authoritative and stored only in subskills; base-skill level is derived from the arithmetic average of the four subskill levels.
- The four canonical Angling subskills are Fish Location and Water Reading; Casting and Presentation; Tackle Rigging and Bait Handling; and Hooking, Fighting, Landing and Release.
- All new characters begin at Level 1 with 0 cumulative XP in every Angling subskill.
- Canonical XP anchors are preserved exactly: L1 0; L10 577; L25 3,921; L50 50,666; L75 605,210; L92 3,258,626; L99 6,517,215.
- Because the master framework explicitly defers exact thresholds between anchors, 2Q uses a deterministic log-interpolated systems-lab table between anchors. The table is strictly monotonic, caps at Level 99, and is not final balance data.
- Stable prototype completion IDs route base XP only in this gate. Challenge, outcome, quality and novelty multipliers remain 1.00x until Action Resolution is integrated more deeply.
- `fishing_rig_functional`: 5 XP to Tackle Rigging and Bait Handling, credited only when a physical rig is first actually used. Repeated cancel/reassemble of the same unchanged physical rig signature does not create duplicate XP.
- `fishing_cast_purposeful`: 1 XP to Casting and Presentation only when the deployed cast reaches a real bite and the hookset action confirms the completed presentation. Empty/cancelled casts earn no cast XP.
- `fishing_hookset`: 3 prototype XP to Hooking, Fighting, Landing and Release on a successful hookset.
- `fishing_fight_control`: 1 prototype XP to Hooking, Fighting, Landing and Release for a correctly executed visible-cue fight choice. Deliberately wrong control input earns no fight-control XP.
- `fishing_land_ordinary`: 10 XP to Hooking, Fighting, Landing and Release for one completed landing/release or landing/retain event. Retain/release does not duplicate the award.
- Fish Location and Water Reading receives no XP yet because the current Observe button exposes data without requiring a meaningful player interpretation task. Passive inspection is not converted into manufactured progression.
- Every XP award is written to the world event history with the stable source action, subskill, award, cumulative XP, and level transition. Game Clock time comes from the event record timestamp.
- Schema 14 and older saves migrate to schema 15 with a fresh zero-XP skills record at the exact saved game time. No retroactive or offline XP is invented.
- Skill XP, derived levels and the bounded rig anti-exploit signatures survive save/load exactly.

## Deliberate limits

Phase 2Q establishes progression accounting; it does not yet make skill level affect fishing resolution. `S_eff`, attributes, Challenge Rating, outcome/quality/novelty multipliers, perks, milestone effects, background starting XP, and the final Level 2–98 threshold table remain later work. The hookset and fight-control base values are prototype calibration values. The master-framework example values of 1 XP for a purposeful cast, 5 XP for a functional rig and 10 XP for an ordinary small-fish landing are retained.

The same physical-rig signature can earn rigging XP once in this systems-lab slice. Replacing a physical component changes the signature and can create a new qualifying rig completion. A later physical assembly/knots model can replace this conservative anti-loop guard with richer qualifying-completion rules.

## Android phone gate

1. Install the newest APK as an update and confirm `v0.18.0` and `PHASE 2Q`.
2. Open Layers and confirm Angling and Fisheries shows four Level-1 subskills, 0 XP on a fresh world, the next threshold and the derived base average.
3. Prepare a spoon rig. Confirm no XP appears merely from preparation. Cast it and confirm Tackle Rigging and Bait Handling receives 5 XP when that physical rig is first used.
4. Cancel before a bite, prepare/cast the same unchanged rig again and confirm the rigging total does not gain another 5 XP.
5. Let a real bite mature and set the hook. Confirm Casting and Presentation gains 1 XP and Hooking/Fighting/Landing/Release gains the hookset award.
6. Make one correct visible-cue fight choice and confirm the fight subskill gains exactly 1 more XP. Repeat from a saved pre-choice state with an intentionally wrong cue response and confirm no fight-control XP is added.
7. Complete a landing with hand or net and confirm exactly 10 landing XP is added once. Save/reload and confirm every XP total and displayed level is identical.
8. Use Observe, travel and a safe wait and confirm Fish Location/Water Reading and the other skills do not increase from passive time/menu inspection.

Phase 2Q is not closed until this phone checklist passes after the automated build gate.
