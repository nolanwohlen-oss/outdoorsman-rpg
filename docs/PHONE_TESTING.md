# Phone testing — Phase 2C (v0.4.0)

## Install the update

1. In your phone browser, sign into GitHub and open the repository's **Actions → Build test app**.
2. Open the newest successful run on `main` for the Phase 2C commit.
3. Under **Artifacts**, download **outdoorsman-android-debug**. Extract the ZIP and open `outdoorsman-test.apk` in Files.
4. Install it as an update, then launch **Outdoorsman Systems Lab**. The header must say **PHASE 2C** and the footer **v0.4.0** with the new build number.

A fresh world starts at sandy shore, Day 1, 06:00, paused. An existing Phase 2A/2B save must instead keep its saved time, location, access, scheduler and history. It adds the new environment at that game time, initially with zero runoff, and reports the upgrade. It must not grant offline time. **Check this before starting a new test world.**

## New Phase 2C checks: conditions, routes and continuity

The **Env** tab is the Environment panel. It scrolls; the zone selector and water measurements are below the regional weather. Selecting a water zone only inspects it; your actual location stays in the header.

For repeatable times, start a new world with seed **13092026** using the bottom of Clock and leave Run off. New world replaces autosave but preserves your manual slot. Do not overwrite a manual save you want to keep.

1. Open **Env**. At 06:00, tide is Low and conditions are Fair. Inspect Open water, Marsh edge and Elevated camp: depth/salinity should differ between water zones; camp says water is not applicable.
2. Go to camp using Clock (**06:02**), then tap **60 min six times** (**12:02**). Open Env. Its last update should be **12:00**, with High tide and warmer water. Values only update every five game minutes.
3. Open Map and travel to **Sandy shore** (**12:04**). Select **Shallow flat**, scroll to the travel control: it must be disabled with a crossing-depth explanation. Selecting/inspecting must not change the clock.
4. Return to camp, then use hourly waits to reach roughly **17:00–19:00** on Day 1. Env should show the front, rain and stronger wind. In Map, inspect **Tidal channel**: its route list should mark the open-water skiff link blocked by wind. You do not have to travel offshore to inspect it.
5. From camp, keep advancing by hours. The front clears, rain stops, runoff remains for a while and then drains. The skiff and wading links eventually reopen when their limits allow. Exact reopening depends on tide, current and runoff together.
6. During rain, **Save**, screenshot Env's weather and a selected water zone, then wait an hour. **Load**, select that same zone again: time, runoff, weather and water values must match the saved view. The saved fingerprint must match too.
7. Close/reopen: the same saved state returns paused. Leaving the app closed must not move the tide or weather forward.

Send the build number and screenshots of **Env**, the **blocked route**, and the **saved/loaded fingerprint**. The instrument readings and route limits are synthetic test data, not real-world forecasts or safety guidance.

If you remain in a water zone while conditions worsen, an exit can temporarily close. Run clock works everywhere; accelerated waits remain camp-only. Perform the fast environmental test from camp to avoid waiting offshore in real time.

## Regression test: six-zone map travel

For these exact times, use a **fresh 06:00 world** and leave Run off. In **Map**, inspect each zone; the panel must show terrain, exposure, habitat tags, potential species and routes. Potential species are labels only, not active fish. Later in the day, environmental closures are intentional.

1. At **Sandy shore**, select **Open water**. The action must be disabled and say that no direct route exists.
2. Select **Marsh edge** → **Travel by foot · 4 min**. The clock becomes **06:04**.
3. Select **Tidal channel** → **Travel by wade · 5 min**. The clock becomes **06:09**.
4. Select **Open water** → **Travel by boat · 12 min**. The clock becomes **06:21**.
5. Travel back to **Tidal channel**, **Marsh edge**, and **Sandy shore**. Each return uses the same stated route and time.
6. From shore, take **Shallow flat** → **Tidal channel** → **Open water** to verify the second branch. Every zone must be reachable; there is no direct shore-to-open-water jump.

Report any wrong duration, unexpected movement, enabled blocked button, or missing route/habitat text.

## Second test: move, wait, save, close, load

Leave Run off for this test so the expected times are exact. The Clock panel scrolls to reveal Save/Load and the scheduler/seed controls.

1. Return to **Sandy shore**, then tap **Go to camp · 2 min**. Location becomes **Elevated camp** and time advances two game minutes.
2. Tap **15 min**. Time advances exactly fifteen game minutes and remains paused.
3. Tap **Save**. Note the time and the `State` fingerprint below Save/Load; a screenshot is sufficient.
4. Tap **60 min**. Time advances exactly one hour.
5. Tap **Load**. Time returns to the value from step 2, location stays camp, and the loaded fingerprint matches the saved fingerprint.
6. Open **Log**. It restores the saved move/wait history; the extra hour's events disappear.
7. Press Home, close the app from recent apps, and reopen. It restores the saved camp state, paused. Tap **Load** to compare the manual snapshot again.

Report any changed time, location, fingerprint, missing events, or save error.

## Third test: foreground, lock, resume

1. Tap **Run clock**. About ten real seconds should advance one game minute; sixty real seconds should advance six game minutes.
2. Tap **Pause clock**. Time must freeze.
3. Tap Run, then press Home or lock the phone. Wait at least twenty real seconds and return.
4. The app must say **PAUSED** and show no background progress. Tap Run to resume.

A long foreground frame can also pause the test clock with a message. Record it if it happens during ordinary play.

## Fourth test: interrupted wait and a day boundary

1. At camp with the clock paused, scroll down and tap **Interrupt next wait in 10 min**.
2. Tap **15 min**. It should stop after exactly ten game minutes, with the interruption and stopped wait in the Log.
3. Repeated **60 min** waits should cross sunset at 18:00, midnight into Day 2, and sunrise at 06:00. Each boundary should appear once in the Log.
4. Save and reopen on Day 2. Day, time, position, and events must remain consistent.

The waiting rule is only a camp fixture. Weather/water now advance through waits; physiological hazards, real rest/sleep and player needs are later layers.

## New-world checks

At the bottom of Clock, enter a seed and tap **New world**, then confirm. It resets to 06:00 at shore and replaces autosave. Your manual save remains available until you tap Save again. The same seed and same paused actions should produce matching saved state fingerprints.

If a saved world is corrupt, the app reports recovery from the previous valid backup, which can be older. If it cannot recover or the version is unsupported, it reports the failure and preserves the files. Do not reset a valuable save while investigating a defect.

## Reporting / build troubleshooting

Send the build number from the footer, which step failed, the expected/actual result, and a screenshot. These phone tests finish the device gate; desktop automation cannot verify physical phone behavior.

If there is no artifact, wait for the run to finish. Red runs have a failed step/log; send the run link. Artifacts expire after 30 days; **Run workflow** on `main` generates another build.

The workflow currently caches the development signing key. Normal successive builds should update in place. If Android reports a signature mismatch, stop and report it: uninstalling deletes local saves. A durable private signing-key setup is still needed before longer-term save playtesting. No release signing or monetization is included.
