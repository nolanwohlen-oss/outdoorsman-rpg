# Phone testing — Phase 1

## Install

Use Chrome or another phone browser signed into GitHub. Open the repository's **Actions** tab, select **Build test app**, and open a successful run on `main`. Download the **outdoorsman-android-debug** artifact at the bottom of the run page. Extract the ZIP and install `outdoorsman-test.apk` from the Files app.

If necessary, permit installation from that specific browser or Files app in Android's install prompt. A Play Store listing is not part of the test workflow. Android may scan or warn about a new development build.

The app label is **Outdoorsman Systems Lab**. It is a separate prototype package, not the final release identity.

## Check this build

- Launch the app and read the version/build identifier at the bottom.
- On **Map**, tap each of the six zones. The highlight, description, and connected-zone names must change together.
- Scroll the panel to the scenario seed. Enter a number and tap **Set seed**.
- On **Layers**, read the nine planned layers and five species names.
- On **Log**, confirm the zone selections and seed setting were recorded.
- Switch away and return; lock and unlock the phone; check that the interface still responds.
- Close and relaunch. This milestone intentionally starts a fresh inspection session. No save-game system exists yet.
- Report cropped text, taps that fail, unexpected exits, or startup errors, along with your phone model and the build identifier.

This checklist verifies the shell only. It does not certify frame rate, memory, battery usage, ecological accuracy, simulation determinism, or save integrity for the later game.

## If there is no download

- Wait for a running build to finish. Artifacts are uploaded only after their export succeeds.
- If the run is red, send its run link. The failed step and log identify the build problem.
- Artifacts expire after 30 days. The workflow supports **Run workflow** on `main` to produce a new test build.

## Updating development builds

The workflow caches a development signing key to allow successive APKs to update normally. If that cache expires, a new key is generated. Android may then reject an update because the signatures differ. For this shell, uninstall the old prototype before installing the new one; this removes its local data. A durable private signing-key setup is required before save-game playtesting becomes valuable. Debug signing must never be reused for final release.

No passwords, access tokens, payment details, or production signing keys are required in project files.
