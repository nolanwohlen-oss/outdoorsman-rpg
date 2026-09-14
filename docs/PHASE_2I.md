# Phase 2I — physical inventory foundation

World schema 9, inventory version 3, development v0.10.0.

## Delivered

- Stable monotonically allocated item IDs. Supply stacks and individual whole fish are distinct records.
- Each record stores definition, quantity, physical mass, container, owner, condition and provenance fields.
- New retained fish store species, catch time, zone and actual encounter weight. Fish quantity is one, regardless of mass. Retention still removes one local population member and never adds ration energy.
- Carried pack: 15,000 g. Fixed elevated-camp cache: 50,000 g. Whole-record transfers require the player to be at camp; capacity failures leave all state unchanged. Camp mass does not count as carried mass.
- Layers panel allows item selection, inspection and transfers in both directions. Each catch remains individually selectable.
- Schemas 1–8 migrate after validation. Legacy resources retain their quantities; historical pooled fish become a clearly unidentified legacy stack. Missing historical condition is -1 (unknown), not invented freshness.
- Ration energy and mass are distinct: the test ration definition uses 4 kcal/g, rounded upward to whole grams. Starter load is 4,200 g. This is a tunable test definition, not a physiological model.

## Phone acceptance test

1. Update the APK without uninstalling. Load an existing save: water, ration calories, wood and any pooled fish should be preserved. Old fish should be labeled legacy fish.
2. Catch and retain two fish. In Layers, select each by ID. Check species, mass, time, origin and quantity 1. Ration calories must not increase.
3. Try storing away from camp: expect rejection and no changed weight.
4. Return to camp. Store one fish, verify reduced pack weight and increased cache weight, then take it back. Its ID and provenance must not change.
5. Store supplies as well. Save, close, reopen and load. Container contents and item IDs must remain unchanged.
6. Fill the pack through catches. A rejected catch must remain releasable; an overweight withdrawal must leave the cache unchanged.

## Boundaries

This is the first physical-inventory delivery, not the entire master inventory framework. Containers are fixed testbed infrastructure, not yet movable item instances; their mass/volume/shape and nesting are not modeled. Transfers move complete records instantly as lab controls; timed handling, splitting/merging, consumption, discard and processing belong to subsequent action work. Supply quantities retain the legacy units (mL, kcal and units); mass is separately validated. Fish condition starts at 1000 but does not decay yet. Rods, equipment slots, spoilage and fish processing are not implemented. The fishing encounter still supplies a simplified weight; inventory preserves it without claiming biological realism.

Tests cover identity, JSON round trips, old-save migration, provenance validation, carry/storage isolation, rejected transfers and retention without partial mutation. Android device acceptance remains necessary after CI export.
