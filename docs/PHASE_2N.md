# Phase 2N — landing methods and catch condition

World schema 14, fishing version 5, development v0.15.0.

Phase 2N makes the end of a successful fish fight an explicit handling decision. It is still a deterministic systems-lab layer: method profiles are test values, not a claim of final fishing physics.

## Delivered

- Three visible methods: hand, net, and gaff.
- Hand takes 1 game minute and records condition 820/1000 when retained or 700/1000 when released.
- Net takes 2 game minutes and records condition 960/1000 retained or 940/1000 released.
- Gaff takes 1 game minute, records 1000/1000, and is retain-only.
- Retained fish store the resulting condition on the physical `whole_fish` item.
- Released fish preserve the handling method and release condition in the fishing record and audit log.
- Handling count and last outcome survive save/load; schema 13 and earlier saves migrate with a blank handling history.
- Landing remains atomic: invalid method, illegal gaff release, capacity failure, or validation failure spends no time and changes nothing.

## Phone gate

1. Install the newest successful APK as an update and load the existing world. The footer should show `v0.15.0`.
2. Catch a fish and follow the visible cues until `READY TO LAND`.
3. Confirm all six method/outcome buttons appear. Test hand release, then net retention; the clock should advance 1 and 2 game minutes respectively.
4. Open Layers and select the retained fish. Its condition should match the selected method (960 for net).
5. Start another ready fish and confirm gaff release is rejected without advancing time; gaff retain succeeds.
6. Save, reload, and confirm the last handling method, condition, counters, and retained fish remain exact.

## Deliberate limits

No tackle wear, replacement economy, legal-size rules, 3D presentation, or monetization is included. Those remain later gates after this state contract is tested on Android.
