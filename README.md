# Outdoorsman RPG

An Android outdoor survival RPG, beginning with a small laboratory for its simulation systems.

**Current milestone: Phase 2A — clock and persistence foundation (v0.2.0).** The app runs a deterministic 6:1 clock with calendar boundaries, scheduled events, shore–camp travel, safe waiting, and versioned local saves. It restores the saved world while paused. Weather, water, fish populations, inventory, and survival needs remain planned.

The Phase 2A delivery spans the minimum data contracts, clock, and early persistence from the longer implementation roadmap. See [the data contracts and scope](docs/PHASE_2A.md).

## Test on your phone

1. Open [Build test app](https://github.com/nolanwohlen-oss/outdoorsman-rpg/actions/workflows/build.yml) in your phone browser while signed into GitHub.
2. Open the newest successful run for `main`.
3. Scroll to **Artifacts** and download **outdoorsman-android-debug**.
4. Extract the downloaded ZIP in your phone's Files app and open `outdoorsman-test.apk`. Allow that app to install this APK if Android asks.
5. Launch **Outdoorsman Systems Lab**. Use **Clock** to travel to camp, wait, save, and load. Follow the [Phase 2A phone checklist](docs/PHONE_TESTING.md).

This is a development APK, not a Google Play release. No Windows PC, Google Play developer account, advertising account, or payment setup is needed for this milestone. See [phone testing](docs/PHONE_TESTING.md) for the checklist and build troubleshooting.

## Open locally

Use **Godot 4.7.2 standard edition**, with GDScript and the Compatibility renderer. Import `project.godot` and press F6 on `scenes/main.tscn`, or F5 to run the project.

On Linux, install the pinned editor with `bash tools/install_godot.sh`, then run:

```sh
.tools/godot/godot --headless --path . --editor --import
.tools/godot/godot --headless --path . --script tests/run.gd
.tools/godot/godot --path .
```

The GitHub workflow also exports and launches a Linux desktop build. Windows users can run the same source in the Godot editor; there is not yet a Windows executable artifact.

## Project structure

| Path | Purpose |
| --- | --- |
| `scenes/`, `scripts/` | Touch interface and placeholder map |
| `data/testbed.json` | Six zone definitions and five species names; no ecological tuning yet |
| `simulation/` | Authoritative world record, clock/actions/scheduler, lifecycle gate, save store |
| `tests/` | Deterministic behavior, save recovery, lifecycle, UI, and cross-process replay |
| `tools/` | Pinned engine installation and build preparation |
| `.github/workflows/build.yml` | Automated tests and Android/Linux exports |
| `docs/IMPLEMENTATION_ORDER.md` | Milestones and completion gates |
| `DESIGN_GATE.md` | Approved design decisions |

The simulation owns world state; the interface displays it and submits commands. Clock input uses foreground monotonic intervals at 6:1. Startup, load, and resume never use the device date or elapsed offline time. All loads/resumes begin paused.

Run all local gates with `bash tools/check.sh`. It also saves a complete day in one Godot process, then loads and continues that same world in a second process. Tests use isolated directories under `build/` and do not open player saves.

**Monetization is deferred until final release.** No ads, premium currency, purchases, subscriptions, or paid progression belong in any pre-release build.

## Build references

- [Godot 4.7.2 official release](https://godotengine.org/download/archive/4.7.2-stable/)
- [Android export requirements](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Headless command-line exports](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html#exporting)
